"""Trains the mob policy with recurrent PPO from rollout shards written by Godot workers (ai/training_worker.gd).

Usually started and stopped by start_training.ps1 and stop_training.ps1. It can be stopped at any time:
- A STOP file in the run folder, Ctrl+C or closing its console makes it save a checkpoint and exit.
- A crash or power loss loses at most the minutes since the last checkpoint. Every file is written atomically
  and checkpoints are checksummed; on start the newest good checkpoint is loaded.

Each update reads at least batch_rows decisions, computes advantages per mob life (GAE, with a centralised
critic that sees the whole encounter), trains on windows of `sequence` decisions starting from the recorded
recurrent memory, then exports the new policy for the workers through policy/manifest.json.

  python train.py [--run-dir <folder>] [--max-updates <n>] [--set key=value ...]
"""

from __future__ import annotations

import argparse
import copy
import ctypes
import json
import os
import signal
import sys
import time
from pathlib import Path

import numpy as np
import torch

import rollouts as R
import safe_files as S
from mob_net import MobCritic, MobPolicy, export_weights
from mob_schema import HEAD_NAMES, MobSchema

HERE = Path(__file__).resolve().parent
SETTINGS_PATH = HERE / "training.json"
REWARDS_PATH = HERE / "rewards.json"
WAIT_SECONDS = 2.0
## The learning rate moves by this factor when the KL strays from its target, from LR_FLOOR up to the trainer
## setting max_learning_rate (DEFAULT_LR_CAP when it is not set).
LR_STEP = 1.25
LR_FLOOR = 1e-5
DEFAULT_LR_CAP = 1e-3
## A longer gap between loop passes means the computer slept; it does not count as training time.
MAX_TICK_SECONDS = 600.0


def load_settings() -> dict:
    return S.load_training_settings(SETTINGS_PATH.parent)


def default_run_dir(settings: dict) -> Path:
    configured = settings.get("run_dir") or ""
    return Path(configured) if configured else Path.home() / "Documents" / "Godot" / "mob-training" / "run"


def pid_alive(pid: int) -> bool:
    """True while a process with this id runs. Never signals it (os.kill(pid, 0) sends Ctrl+C on Windows)."""
    if pid <= 0:
        return False
    if os.name != "nt":
        try:
            os.kill(pid, 0)
        except OSError:
            return False
        return True
    kernel = ctypes.windll.kernel32
    handle = kernel.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
    if not handle:
        return False
    code = ctypes.c_ulong()
    kernel.GetExitCodeProcess(handle, ctypes.byref(code))
    kernel.CloseHandle(handle)
    return code.value == 259  # STILL_ACTIVE


def keep_awake(enabled: bool) -> None:
    """Asks Windows not to sleep while this process trains. The request ends with the process."""
    if os.name == "nt":
        flags = 0x80000000 | (0x00000001 if enabled else 0)  # ES_CONTINUOUS | ES_SYSTEM_REQUIRED
        ctypes.windll.kernel32.SetThreadExecutionState(flags)


def masked_terms(logits: torch.Tensor, masks: torch.Tensor, actions: torch.Tensor, slices: list[tuple[int, int]],
                 heads: list[torch.Tensor] | None = None) -> tuple[torch.Tensor, torch.Tensor]:
    """Summed log-probability of the chosen options and summed entropy, each head limited to its legal options,
    exactly as ai/training_brain.gd sampled them. A head with one legal option adds nothing. When heads is a list,
    each head's own entropy is appended to it, in head order."""
    log_prob = torch.zeros(logits.shape[:-1], device=logits.device)
    entropy = torch.zeros(logits.shape[:-1], device=logits.device)
    for head, (offset, size) in enumerate(slices):
        legal = masks[..., offset:offset + size]
        logp = torch.log_softmax(logits[..., offset:offset + size].masked_fill(~legal, -1e9), dim=-1)
        log_prob = log_prob + logp.gather(-1, actions[..., head:head + 1]).squeeze(-1)
        own = -(logp.exp() * logp).masked_fill(~legal, 0.0).sum(-1)
        entropy = entropy + own
        if heads is not None:
            heads.append(own)
    return log_prob, entropy


def entropy_weights(cfg: dict) -> tuple[float, float]:
    """The entropy bonuses for the fighting choices (behaviour, targets, manoeuvre) and for the message choices.
    entropy_weight is the older single setting, used for either when its split setting is absent."""
    single = float(cfg.get("entropy_weight", 0.0))
    return float(cfg.get("entropy_weight_fight", single)), float(cfg.get("entropy_weight_messages", single))


class Trainer:
    def __init__(self, run_dir: Path, settings: dict, overrides: dict, log=print) -> None:
        self.run_dir = run_dir
        self.log = log
        self.cfg = {**settings["trainer"], **overrides}
        self.schema = MobSchema()
        wanted = str(self.cfg.get("device", "cuda"))
        self.device = torch.device(wanted if wanted != "cuda" or torch.cuda.is_available() else "cpu")
        self.folders = {name: run_dir / name for name in ("policy", "shards", "checkpoints", "logs")}
        for folder in self.folders.values():
            folder.mkdir(parents=True, exist_ok=True)
        (self.folders["checkpoints"] / "milestones").mkdir(exist_ok=True)
        mob = json.loads(REWARDS_PATH.read_text(encoding="utf-8"))["mob"]
        self.squad_mix_range = (float(mob.get("squad_mix_start", 0.2)), float(mob.get("squad_mix_end", 0.2)))
        offsets, cursor = [], 0
        for name in HEAD_NAMES:
            offsets.append((cursor, self.schema.head_sizes[name]))
            cursor += self.schema.head_sizes[name]
        self.slices = offsets
        torch.manual_seed(int(self.cfg["seed"]))
        self.policy = MobPolicy(self.schema).to(self.device)
        self.critic = MobCritic(self.schema).to(self.device)
        self.optimizer = torch.optim.Adam(list(self.policy.parameters()) + list(self.critic.parameters()),
                                          lr=float(self.cfg["learning_rate"]), eps=1e-5)
        self.learning_rate = float(self.cfg["learning_rate"])
        self.version = 0
        # The oldest policy version whose weights equal the current ones (a resume re-exports the same weights).
        self.weights_from = 0
        self.samples = 0
        self.updates = 0
        self.seconds = 0.0
        self.milestone_seconds = 0.0
        self.stop_requested = False
        self.pending: dict[Path, R.Rollout] = {}
        self.rejected = 0
        self.stale = 0
        self._resume()

    # Checkpoints -------------------------------------------------------------------------------------------

    def _resume(self) -> None:
        manifest = S.read_json(self.folders["policy"] / "manifest.json") or {}
        loaded = S.load_checkpoint(self.folders["checkpoints"], self.log)
        if loaded is None:
            self.log("No checkpoint found: starting a new policy.")
        else:
            state, path = loaded
            if state.get("schema_hash") != self.schema.hash_hex:
                raise SystemExit(f"Checkpoint {path.name} was made for a different schema. Use a new run folder.")
            self.policy.load_state_dict(state["policy"])
            self.critic.load_state_dict(state["critic"])
            if "optimizer" in state:
                self.optimizer.load_state_dict(state["optimizer"])
            else:
                self.log("This checkpoint was converted to a new schema: starting a fresh optimizer.")
            self.version = int(state["version"])
            self.samples = int(state["samples"])
            self.updates = int(state["updates"])
            self.seconds = float(state["seconds"])
            self.milestone_seconds = float(state.get("milestone_seconds", 0.0))
            self.learning_rate = float(state.get("learning_rate", self.learning_rate))
            self._set_learning_rate(self.learning_rate)
            torch.set_rng_state(state["torch_rng"])
            self.log(f"Resumed from {path.name}: policy {self.version}, {self.samples:,} decisions trained.")
        # Policy versions only grow, so workers always take up the resumed policy, even after a fallback.
        self.weights_from = self.version if loaded is not None else int(manifest.get("version", 0)) + 1
        self.version = max(self.version, int(manifest.get("version", 0))) + 1
        self.export_policy()

    def state(self) -> dict:
        return {"policy": self.policy.state_dict(), "critic": self.critic.state_dict(), "optimizer": self.optimizer.state_dict(),
                "version": self.version, "samples": self.samples, "updates": self.updates, "seconds": self.seconds,
                "milestone_seconds": self.milestone_seconds, "learning_rate": self.learning_rate, "torch_rng": torch.get_rng_state(), "schema_hash": self.schema.hash_hex}

    def checkpoint(self) -> None:
        path = S.save_checkpoint(self.folders["checkpoints"], self.state(), self.version, int(self.cfg["keep_checkpoints"]))
        self.log(f"Saved checkpoint {path.name}.")
        if self.seconds - self.milestone_seconds >= float(self.cfg["milestone_hours"]) * 3600.0:
            self.milestone_seconds = self.seconds
            milestones = self.folders["checkpoints"] / "milestones"
            S.save_checkpoint(milestones, self.state(), self.version, 0)
            policy = self.folders["policy"] / f"policy_{self.version:07d}.bin"
            S.atomic_write_bytes(milestones / policy.name, policy.read_bytes())
            self.log(f"Kept milestone {self.version} for later opponents and comparisons.")

    def _set_learning_rate(self, value: float) -> None:
        cap = float(self.cfg.get("max_learning_rate", DEFAULT_LR_CAP))
        self.learning_rate = min(cap, max(LR_FLOOR, value))
        for group in self.optimizer.param_groups:
            group["lr"] = self.learning_rate

    def adapt_learning_rate(self, kl: float) -> None:
        """Holds the policy's change per update near target_kl: a larger step when updates barely change the
        policy, a smaller one when they change it too much."""
        target = float(self.cfg.get("target_kl", 0.0))
        if target <= 0.0:
            return
        if kl > target * 1.5:
            self._set_learning_rate(self.learning_rate / LR_STEP)
        elif kl < target / 1.5:
            self._set_learning_rate(self.learning_rate * LR_STEP)

    def squad_mix(self) -> float:
        start, end = self.squad_mix_range
        share = min(1.0, self.samples / max(1.0, float(self.cfg["squad_mix_samples"])))
        return start + (end - start) * share

    def export_policy(self) -> None:
        folder = self.folders["policy"]
        path = folder / f"policy_{self.version:07d}.bin"
        temporary = path.with_name(path.name + ".tmp")
        export_weights(copy.deepcopy(self.policy).cpu(), temporary)
        data = temporary.read_bytes()
        S.atomic_write_bytes(path, data)
        temporary.unlink(missing_ok=True)
        S.atomic_write_json(folder / "manifest.json", {"version": self.version, "file": path.name, "sha256": S.sha256_hex(data),
                                                       "squad_mix": round(self.squad_mix(), 4), "schema_hash": self.schema.hash_hex})
        keep = int(self.cfg["keep_policies"])
        for old in sorted(folder.glob("policy_*.bin"))[:-keep]:
            old.unlink(missing_ok=True)

    # Rollouts ----------------------------------------------------------------------------------------------

    def collect(self) -> tuple[R.Rollout, list[Path]] | None:
        """At least batch_rows fresh decisions from waiting shards, oldest first, or None while too few wait."""
        oldest_allowed = self.version - int(self.cfg["max_policy_lag"])
        for path in sorted(self.folders["shards"].glob("*.shard"), key=lambda p: p.stat().st_mtime):
            if path in self.pending:
                continue
            try:
                self.pending[path] = R.read_shard(path, self.schema)
            except (R.ShardError, OSError, ValueError) as error:
                self.log(f"Rejected shard {path.name}: {error}")
                self.rejected += 1
                path.unlink(missing_ok=True)
        for path, rollout in list(self.pending.items()):
            if rollout.rows and int(rollout.policy_version[0]) < oldest_allowed:
                self.stale += 1
                del self.pending[path]
                path.unlink(missing_ok=True)
        total = sum(r.rows for r in self.pending.values())
        if total < int(self.cfg["batch_rows"]):
            return None
        chosen, rows = [], 0
        for path, rollout in self.pending.items():
            chosen.append(path)
            rows += rollout.rows
            if rows >= int(self.cfg["batch_rows"]):
                break
        return R.concatenate([self.pending[p] for p in chosen]), chosen

    # PPO ---------------------------------------------------------------------------------------------------

    def unroll(self, obs: torch.Tensor, index: torch.Tensor, hidden: torch.Tensor) -> torch.Tensor:
        steps = []
        for step in range(index.shape[1]):
            logits, hidden = self.policy(obs[index[:, step]], hidden)
            steps.append(logits)
        return torch.stack(steps, dim=1)

    def update(self, batch: R.Rollout) -> dict:
        cfg, device = self.cfg, self.device
        tensor = lambda array, dtype=None: torch.as_tensor(np.ascontiguousarray(array), dtype=dtype, device=device)  # noqa: E731
        obs = tensor(batch.obs)
        global_state = tensor(batch.global_state)
        memory = tensor(batch.memory)
        masks = tensor(batch.masks).bool()
        actions = tensor(batch.actions, torch.int64)
        old_log_prob = tensor(batch.log_prob)
        with torch.no_grad():
            values = torch.cat([self.critic(obs[i:i + 16384], global_state[i:i + 16384]) for i in range(0, batch.rows, 16384)])
        value_rows = values.cpu().numpy()
        advantage, returns = R.advantages(batch.reward, value_rows, batch.end, float(cfg["gamma"]), float(cfg["lambda"]))
        # How much of the spread in the critic's targets its predictions explain, before this update trains it.
        # Near 0 means the advantages PPO learns from are mostly noise.
        spread = float(np.var(returns))
        explained = 1.0 - float(np.var(returns - value_rows)) / spread if spread > 0.0 else 0.0
        advantage = (advantage - advantage.mean()) / (advantage.std() + 1e-8)
        advantage_t, returns_t = tensor(advantage), tensor(returns)
        windows, _first = R.sequences(batch.life, int(cfg["sequence"]))
        window_t = tensor(windows)
        valid = window_t >= 0
        index = window_t.clamp(min=0)
        start_memory = memory[index[:, 0]]
        stats = {"replay_gap": self._replay_gap(batch, obs, masks, actions, old_log_prob, index, valid, start_memory)}
        totals = {"policy_loss": 0.0, "value_loss": 0.0, "entropy": 0.0, "entropy_messages": 0.0, "entropy_fight": 0.0,
                  "approx_kl": 0.0, "clip_fraction": 0.0}
        message_heads = [i for i, name in enumerate(HEAD_NAMES) if name.startswith("message")]
        # A decision is free when at least one fighting choice (behaviour, targets, manoeuvre) has more than one legal
        # option. A committed mob (winding up or inside a hold) has none, and its fighting choices cannot change, so
        # KL, clipping and fighting entropy are measured on free decisions only: averaged over every decision they
        # would read low by the committed share, and the learning rate would rise past what the free choices take.
        free_all = torch.zeros(masks.shape[0], dtype=torch.bool, device=device)
        for head, (offset, size) in enumerate(self.slices):
            if head not in message_heads:
                free_all |= masks[:, offset:offset + size].sum(-1) > 1
        stats["free_share"] = round(float(free_all.float().mean().item()), 4)
        fight_weight, message_weight = entropy_weights(cfg)
        steps = 0
        # KL is reported from the final pass: by then the policy has moved as far as this update moves it. An
        # average over every step would include the first, which barely move it, and read about half as high.
        final_kl, final_steps = 0.0, 0
        size = int(cfg["minibatch_sequences"])
        clip, value_clip = float(cfg["clip"]), float(cfg["value_clip"])
        epochs = int(cfg["epochs"])
        for epoch in range(epochs):
            order = torch.randperm(windows.shape[0], device=device)
            for start in range(0, windows.shape[0], size):
                chosen = order[start:start + size]
                rows = index[chosen]
                keep = valid[chosen]
                logits = self.unroll(obs, rows, start_memory[chosen])
                heads: list[torch.Tensor] = []
                log_prob, entropy = masked_terms(logits, masks[rows], actions[rows], self.slices, heads)
                log_ratio = (log_prob - old_log_prob[rows])[keep]
                ratio = log_ratio.exp()
                gain = advantage_t[rows][keep]
                policy_loss = -torch.min(ratio * gain, ratio.clamp(1 - clip, 1 + clip) * gain).mean()
                flat = rows[keep]
                value = self.critic(obs[flat], global_state[flat])
                old_value = values[flat]
                clipped = old_value + (value - old_value).clamp(-value_clip, value_clip)
                value_loss = 0.5 * torch.max((value - returns_t[flat]) ** 2, (clipped - returns_t[flat]) ** 2).mean()
                entropy_mean = entropy[keep].mean()
                message_mean = sum(heads[i] for i in message_heads)[keep].mean()
                fight_mean = entropy_mean - message_mean
                loss = policy_loss + float(cfg["value_weight"]) * value_loss - fight_weight * fight_mean - message_weight * message_mean
                self.optimizer.zero_grad(set_to_none=True)
                loss.backward()
                torch.nn.utils.clip_grad_norm_(list(self.policy.parameters()) + list(self.critic.parameters()), float(cfg["max_grad_norm"]))
                self.optimizer.step()
                with torch.no_grad():
                    totals["policy_loss"] += policy_loss.item()
                    totals["value_loss"] += value_loss.item()
                    totals["entropy"] += entropy_mean.item()
                    totals["entropy_messages"] += message_mean.item()
                    free = free_all[rows][keep]
                    if free.any():
                        fight_rows = (entropy - sum(heads[i] for i in message_heads))[keep]
                        totals["entropy_fight"] += fight_rows[free].mean().item()
                        kl = ((ratio - 1) - log_ratio)[free].mean().item()
                        totals["clip_fraction"] += ((ratio - 1).abs() > clip)[free].float().mean().item()
                    else:
                        kl = 0.0
                    totals["approx_kl"] += kl
                    if epoch == epochs - 1:
                        final_kl += kl
                        final_steps += 1
                steps += 1
        stats.update({key: round(value / max(1, steps), 5) for key, value in totals.items()})
        stats["mean_kl"] = stats["approx_kl"]
        stats["approx_kl"] = round(final_kl / max(1, final_steps), 5)
        stats["value_mean"] = round(values.mean().item(), 4)
        stats["explained_variance"] = round(explained, 4)
        return stats

    def _replay_gap(self, batch, obs, masks, actions, old_log_prob, index, valid, start_memory) -> float:
        """How far this policy's log-probabilities are from those the workers recorded, on decisions made with this
        exact policy. Near zero proves Godot and PyTorch sample the same distribution."""
        current = torch.as_tensor(batch.policy_version >= self.weights_from, device=self.device)
        with_current = (current[index] & valid).all(dim=1).nonzero().squeeze(1)[:64]
        if with_current.numel() == 0:
            return -1.0
        with torch.no_grad():
            rows = index[with_current]
            logits = self.unroll(obs, rows, start_memory[with_current])
            log_prob, _entropy = masked_terms(logits, masks[rows], actions[rows], self.slices)
            return round((log_prob - old_log_prob[rows]).abs().mean().item(), 6)

    # Loop --------------------------------------------------------------------------------------------------

    def heartbeat(self, state: str) -> None:
        S.atomic_write_json(self.run_dir / "trainer.json", {
            "pid": os.getpid(), "state": state, "version": self.version, "samples": self.samples, "updates": self.updates,
            "hours": round(self.seconds / 3600.0, 3), "waiting_rows": sum(r.rows for r in self.pending.values()),
            "device": str(self.device), "time": time.strftime("%Y-%m-%d %H:%M:%S")})

    def stopping(self) -> bool:
        return self.stop_requested or (self.run_dir / "STOP").exists()

    def _count_time(self) -> None:
        """Adds the wall time since the last call to the training time, waiting included."""
        now = time.monotonic()
        self.seconds += min(MAX_TICK_SECONDS, now - self._clock)
        self._clock = now

    def run(self, max_updates: int | None) -> None:
        last_checkpoint = time.monotonic()
        self._clock = time.monotonic()
        done = 0
        self.heartbeat("waiting")
        while not self.stopping() and (max_updates is None or done < max_updates):
            self._count_time()
            began = time.monotonic()
            gathered = self.collect()
            if gathered is None:
                self.heartbeat("waiting")
                time.sleep(WAIT_SECONDS)
                continue
            batch, paths = gathered
            stats = self.update(batch)
            for path in paths:
                self.pending.pop(path, None)
                path.unlink(missing_ok=True)
            self.samples += batch.rows
            self.updates += 1
            self.version += 1
            self.weights_from = self.version
            self.export_policy()
            elapsed = time.monotonic() - began
            self.report(batch, stats, elapsed)
            self.adapt_learning_rate(float(stats["approx_kl"]))
            done += 1
            if time.monotonic() - last_checkpoint >= float(self.cfg["checkpoint_minutes"]) * 60.0:
                self.checkpoint()
                last_checkpoint = time.monotonic()
            self.heartbeat("training")
        self._count_time()
        self.checkpoint()
        self.heartbeat("stopped")

    def report(self, batch: R.Rollout, stats: dict, elapsed: float) -> None:
        episodes = batch.episodes
        outcomes = {name: sum(e.get("outcome") == name for e in episodes) for name in ("wipe", "cleared", "timeout")}
        explore = [e for e in episodes if e.get("mode") == "explore"]
        found = [e["first_sight"] for e in explore if e.get("first_sight", -1) >= 0]
        life_returns = np.bincount(batch.life - batch.life.min(), weights=batch.reward)
        line = {"time": time.strftime("%Y-%m-%d %H:%M:%S"), "version": self.version, "updates": self.updates, "samples": self.samples,
                "rows": batch.rows, "seconds": round(elapsed, 2), "episodes": len(episodes), "outcomes": outcomes,
                "wipe_rate": round(outcomes["wipe"] / max(1, len(episodes)), 4),
                "explore_found_rate": round(len(found) / max(1, len(explore)), 4) if explore else None,
                "explore_first_sight_s": round(float(np.mean(found)), 2) if found else None,
                "damage_to_party": round(float(np.mean([e.get("damage_to_party", 0) for e in episodes])), 2) if episodes else 0,
                "life_return": round(float(life_returns.mean()), 4), "squad_mix": round(self.squad_mix(), 4),
                "learning_rate": self.learning_rate,
                "rejected_shards": self.rejected, "stale_shards": self.stale, **stats}
        S.append_line(self.folders["logs"] / "metrics.jsonl", json.dumps(line))
        self.log(f"Update {self.updates} (policy {self.version}): {batch.rows} decisions, wipes {line['wipe_rate']:.0%}, "
                 f"life return {line['life_return']:.3f}, entropy {stats['entropy']:.3f}, kl {stats['approx_kl']:.4f}, "
                 f"replay gap {stats['replay_gap']}")


def parse_overrides(values: list[str]) -> dict:
    overrides = {}
    for item in values:
        key, _, raw = item.partition("=")
        try:
            overrides[key] = json.loads(raw)
        except ValueError:
            overrides[key] = raw
    return overrides


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--run-dir", type=Path)
    parser.add_argument("--max-updates", type=int)
    parser.add_argument("--set", action="append", default=[], metavar="KEY=VALUE", help="override a trainer setting")
    args = parser.parse_args()
    settings = load_settings()
    run_dir = args.run_dir or default_run_dir(settings)
    run_dir.mkdir(parents=True, exist_ok=True)
    log = lambda text: print(time.strftime("%H:%M:%S "), text, flush=True)  # noqa: E731
    lock = run_dir / "trainer.lock"
    holder = S.read_json(lock) or {}
    if pid_alive(int(holder.get("pid", 0))) and int(holder.get("pid", 0)) != os.getpid():
        log(f"Another trainer (process {holder['pid']}) is using {run_dir}.")
        return 1
    S.atomic_write_json(lock, {"pid": os.getpid()})
    for folder in ("policy", "checkpoints", "checkpoints/milestones"):
        S.remove_temporaries(run_dir / folder)
    trainer = Trainer(run_dir, settings, parse_overrides(args.set), log)

    def request_stop(_signum, _frame) -> None:
        trainer.stop_requested = True
        log("Stopping after the current step.")

    signal.signal(signal.SIGINT, request_stop)
    if hasattr(signal, "SIGBREAK"):
        signal.signal(signal.SIGBREAK, request_stop)
    keep_awake(bool(trainer.cfg.get("keep_awake", True)))
    log(f"Training in {run_dir} on {trainer.device}; policy {trainer.version}.")
    try:
        trainer.run(args.max_updates)
    finally:
        keep_awake(False)
        lock.unlink(missing_ok=True)
    log("Stopped. Progress is saved; start again to resume.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
