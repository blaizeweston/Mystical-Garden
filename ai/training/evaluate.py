"""Compares mob brains on identical training fights and diagnoses the critic.

Each brain (the game's scripted brain and any number of checkpoints) plays the same seeded episodes: the same
floors, parties, difficulties and mob groups in the same order, set up exactly as in training. Differences
between brains are then measured fight by fight, which removes most of the noise the training dashboard has.

For each checkpoint it also records the decisions of a few episodes and measures, with that checkpoint's own
critic and policy:
- explained variance: how much of the variation in what mobs went on to earn the critic predicts. Near 0 means
  the advantages PPO learns from are mostly noise.
- entropy per action head, so the dashboard's summed entropy can be read.

  python evaluate.py [--run-dir <folder>] [--checkpoints a.pt b.pt ...] [--episodes 240] [--processes <n>]
                     [--seed 7] [--no-scripted] [--record 12] [--milestones 3] [--game-temperature] [--out <folder>]

--game-temperature also plays every checkpoint as the game samples it (sharper for brighter mobs, see
ai/game_temperature_brain.gd), since training's temperature 1 understates how mobs play in the game.

With no --checkpoints it takes the run folder's newest checkpoint and up to --milestones milestones, spread
over the run. It only reads the run folder: results go to --out (default: an evaluations folder next to the
run folder). Training can keep running, though the evaluation then competes with it for the processor.
"""

from __future__ import annotations

import argparse
import io
import json
import math
import os
import subprocess
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
PROJECT = HERE.parent.parent
REWARDS_PATH = HERE / "rewards.json"
SCRIPTED = "scripted"
RANDOM = "random"
BLOCKS = 8
JOB_TIMEOUT_SECONDS = 3600


# Checkpoints -------------------------------------------------------------------------------------------------

def read_checkpoint(path: Path) -> dict | None:
    """A checkpoint's state. Its checksum sidecar is checked when present (copied files may lack one)."""
    data = S.verified_bytes(path)
    if data is None:
        if path.with_name(path.name + ".sha256").exists():
            print(f"Skipping {path.name}: its checksum does not match.")
            return None
        data = path.read_bytes()
    try:
        return torch.load(io.BytesIO(data), map_location="cpu", weights_only=True)
    except Exception as error:  # noqa: BLE001 - an unreadable file is reported and skipped
        print(f"Skipping {path.name}: {error}")
        return None


def default_checkpoints(run_dir: Path, milestones: int) -> list[Path]:
    folder = run_dir / "checkpoints"
    newest = sorted((p for p in folder.glob("ckpt_*.pt") if S.checkpoint_version(p) >= 0), key=S.checkpoint_version)
    kept = sorted((p for p in (folder / "milestones").glob("ckpt_*.pt") if S.checkpoint_version(p) >= 0), key=S.checkpoint_version)
    chosen: list[Path] = []
    if kept and milestones > 0:
        picks = np.unique(np.linspace(0, len(kept) - 1, min(milestones, len(kept))).round().astype(int))
        chosen += [kept[i] for i in picks]
    if newest:
        chosen.append(newest[-1])
    unique: dict[int, Path] = {}
    for path in chosen:
        unique.setdefault(S.checkpoint_version(path), path)
    return [unique[v] for v in sorted(unique)]


class Contestant:
    """A brain to compare: "policy" (a checkpoint), "sharpened" (a checkpoint sampled at a lower temperature),
    "scripted" (the game's brain) or "random" (every legal option equally likely, the baseline for how much
    choices matter at all)."""

    def __init__(self, label: str, policy_file: Path, state: dict | None = None, kind: str | None = None) -> None:
        self.label = label
        self.policy_file = policy_file
        self.state = state
        self.kind = kind or ("policy" if state else "scripted")
        self.scripted = self.kind == "scripted"
        self.samples = int(state.get("samples", 0)) if state else 0
        self.version = int(state.get("version", 0)) if state else 0


def prepare(paths: list[Path], schema: MobSchema, out: Path) -> list[Contestant]:
    """Exports each checkpoint's policy for Godot. A checkpoint whose network does not fit this schema (made
    before the roam behaviour, say) is skipped with a note; one made under an earlier hash of the same schema
    (files with other line endings) loads as is."""
    folder = out / "policies"
    folder.mkdir(parents=True, exist_ok=True)
    contestants = []
    for path in paths:
        state = read_checkpoint(path)
        if state is None:
            continue
        policy = MobPolicy(schema)
        try:
            policy.load_state_dict(state["policy"])
            MobCritic(schema).load_state_dict(state["critic"])
        except (KeyError, RuntimeError) as error:
            print(f"Skipping {path.name}: its network does not fit this schema ({str(error).splitlines()[0]}). "
                  "Convert it with convert_checkpoint.py first.")
            continue
        if state.get("schema_hash") != schema.hash_hex:
            print(f"Note: {path.name} names another schema hash, but its network fits this schema.")
        version = int(state.get("version", S.checkpoint_version(path)))
        file = folder / f"policy_{version:07d}.bin"
        export_weights(policy, file)
        label = f"v{version} ({int(state.get('samples', 0)) / 1e6:.0f}M)"
        contestants.append(Contestant(label, file, state))
    return contestants


def random_brain(schema: MobSchema, out: Path) -> Contestant:
    """A policy whose every logit is zero, so each head picks uniformly among its legal options."""
    policy = MobPolicy(schema)
    with torch.no_grad():
        policy.heads.weight.zero_()
        policy.heads.bias.zero_()
    file = out / "policies" / "policy_random.bin"
    file.parent.mkdir(parents=True, exist_ok=True)
    export_weights(policy, file)
    return Contestant(RANDOM, file, kind="random")


def sharpen_policy(policy_state: dict, schema: MobSchema, temperature: float) -> MobPolicy:
    """The policy with its output layer divided by temperature, so every logit is divided by it."""
    policy = MobPolicy(schema)
    policy.load_state_dict(policy_state)
    with torch.no_grad():
        policy.heads.weight.div_(temperature)
        policy.heads.bias.div_(temperature)
    return policy


def sharpened(contestant: Contestant, temperature: float, schema: MobSchema, out: Path) -> Contestant:
    """The checkpoint's policy with its logits divided by temperature: below 1 it commits harder to the options
    it already prefers. Exported as its own policy, so Godot samples it exactly as in training."""
    file = out / "policies" / f"policy_{contestant.version:07d}_t{temperature:g}.bin"
    export_weights(sharpen_policy(contestant.state["policy"], schema, temperature), file)
    return Contestant(f"{contestant.label} T{temperature:g}", file, contestant.state, kind="sharpened")


def game_tempered(contestant: Contestant) -> Contestant:
    """The checkpoint played as the game samples it: behaviour, targets and commitment sharper for brighter mobs."""
    return Contestant(f"{contestant.label} game", contestant.policy_file, contestant.state, kind="game")


def squad_mix(samples: int, settings: dict) -> float:
    mob = json.loads(REWARDS_PATH.read_text(encoding="utf-8"))["mob"]
    start, end = float(mob.get("squad_mix_start", 0.2)), float(mob.get("squad_mix_end", 0.2))
    share = min(1.0, samples / max(1.0, float(settings["trainer"]["squad_mix_samples"])))
    return start + (end - start) * share


# Running the episodes ----------------------------------------------------------------------------------------

def run_jobs(contestants: list[Contestant], settings: dict, args, out: Path) -> None:
    godot = settings.get("godot", "")
    if not godot or not Path(godot).exists():
        raise SystemExit(f"Godot was not found at '{godot}'. Set \"godot\" in training.local.json.")
    mix = squad_mix(max((c.samples for c in contestants), default=0), settings)
    per_block = [args.episodes // BLOCKS + (1 if b < args.episodes % BLOCKS else 0) for b in range(BLOCKS)]
    (out / "results").mkdir(parents=True, exist_ok=True)
    (out / "logs").mkdir(parents=True, exist_ok=True)
    jobs = []
    for index, contestant in enumerate(contestants):
        for block, count in enumerate(per_block):
            if count == 0:
                continue
            name = f"c{index:02d}_b{block}"
            result = out / "results" / f"{name}.jsonl"
            if result.exists():
                continue
            command = [godot, "--headless", "--path", str(PROJECT), "--script", "res://ai/evaluate_policies.gd", "--",
                       "--policy", str(contestant.policy_file), "--seed", str(args.seed * 1000 + block), "--episodes", str(count),
                       "--out", str(result), "--squad-mix", f"{mix:.4f}"]
            if contestant.scripted:
                command.append("--scripted")
            elif contestant.kind == "game":
                command.append("--game-temperature")
            elif contestant.kind == "policy" and block == 0 and args.record > 0:
                command += ["--record", str(min(args.record, count)), "--shards", str(out / "shards" / f"c{index:02d}")]
            jobs.append((name, command))
    total = len(jobs)
    if total == 0:
        return
    print(f"Playing {args.episodes} episodes with each of {len(contestants)} brains: {total} jobs, {args.processes} at a time.")
    running: list[tuple[str, subprocess.Popen, float, object]] = []
    done = failed = 0
    began = time.monotonic()
    while jobs or running:
        while jobs and len(running) < args.processes:
            name, command = jobs.pop(0)
            log = (out / "logs" / f"{name}.log").open("w", encoding="utf-8")
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, cwd=str(PROJECT))
            running.append((name, process, time.monotonic(), log))
        time.sleep(0.5)
        for entry in list(running):
            name, process, started, log = entry
            code = process.poll()
            if code is None and time.monotonic() - started > JOB_TIMEOUT_SECONDS:
                process.kill()
                code = -1
            if code is None:
                continue
            log.close()
            running.remove(entry)
            done += 1
            if code != 0:
                failed += 1
                print(f"  {name} failed (exit {code}); see logs/{name}.log")
            elapsed = time.monotonic() - began
            print(f"  {done}/{total} jobs done, {elapsed / 60:.1f} min" + (f", about {elapsed / done * (total - done) / 60:.1f} min left" if done < total else ""))
    if failed:
        raise SystemExit(f"{failed} job(s) failed. Fix the cause and run again with the same --out to finish the rest.")


def load_results(contestants: list[Contestant], out: Path) -> dict[str, list[dict]]:
    results = {}
    for index, contestant in enumerate(contestants):
        rows = []
        for path in sorted((out / "results").glob(f"c{index:02d}_b*.jsonl")):
            rows += [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
        results[contestant.label] = rows
    return results


# Summaries ---------------------------------------------------------------------------------------------------

def mean(values) -> float:
    values = [v for v in values if v is not None and not (isinstance(v, float) and math.isnan(v))]
    return float(np.mean(values)) if values else float("nan")


def episode_metrics(e: dict) -> dict:
    """Per-episode numbers, each comparable across party sizes."""
    hp = max(1.0, float(e.get("party_hp", 0.0)) or 1.0)
    values = e.get("reward_values", {})
    return {
        "wipe": float(e["outcome"] == "wipe"),
        "cleared": float(e["outcome"] == "cleared"),
        "timeout": float(e["outcome"] == "timeout"),
        "party_hp_lost": float(e["damage_to_party"]) / hp,
        "downs_per_player": float(e["downs"]) / max(1, int(e["party"])),
        "mobs_killed_share": float(e["mobs_killed"]) / max(1, int(e["mobs"])),
        "seconds": float(e["seconds"]),
        "reward_total": float(sum(values.values())),
        "reward_per_mob": float(sum(values.values())) / max(1, int(e["mobs"])),
    }


METRIC_LABELS = {
    "wipe": ("Party wiped", "pct"), "cleared": ("Mobs all killed", "pct"), "timeout": ("Time ran out", "pct"),
    "party_hp_lost": ("Party health lost (share of total)", "pct"), "downs_per_player": ("Players downed (share)", "pct"),
    "mobs_killed_share": ("Mobs killed (share)", "pct"), "seconds": ("Fight length (s)", "num"),
    "reward_total": ("Mob reward per fight", "num"), "reward_per_mob": ("Mob reward per mob", "num"),
}


def summarise(rows: list[dict], names: list[str]) -> dict:
    metrics = [episode_metrics(e) for e in rows]
    summary = {key: mean(m[key] for m in metrics) for key in METRIC_LABELS}
    explore = [e for e in rows if e["mode"] == "explore"]
    found = [e["first_sight"] for e in explore if e["first_sight"] >= 0]
    summary["explore_found"] = len(found) / len(explore) if explore else float("nan")
    summary["explore_first_sight"] = mean(found)
    contact = [e["first_within_3m"] for e in rows if e["first_within_3m"] >= 0]
    summary["reached_3m"] = len(contact) / len(rows) if rows else float("nan")
    summary["first_within_3m"] = mean(contact)
    time_totals: dict[str, float] = {}
    for e in rows:
        for key, value in e["time"].items():
            time_totals[key] = time_totals.get(key, 0.0) + float(value)
    mob_seconds = max(1e-9, time_totals.get("mob_seconds", 0.0))
    summary["time"] = {key: value / mob_seconds for key, value in time_totals.items() if key != "mob_seconds"}
    reward_values: dict[str, float] = {}
    for e in rows:
        for key, value in e.get("reward_values", {}).items():
            reward_values[key] = reward_values.get(key, 0.0) + float(value)
    summary["reward_values"] = {key: value / max(1, len(rows)) for key, value in sorted(reward_values.items(), key=lambda kv: -abs(kv[1]))}
    for kind in ("awake_behaviours", "idle_behaviours"):
        counts = np.zeros(len(names))
        for e in rows:
            counts[:len(e[kind])] += np.array(e[kind], dtype=float)[:len(names)]
        total = counts.sum()
        summary[kind] = {names[i]: counts[i] / total for i in range(len(names))} if total else {}
    summary["episodes"] = len(rows)
    return summary


def paired(rows: list[dict], baseline: list[dict]) -> dict:
    """Mean per-fight difference from the baseline brain on the same fights, with two standard errors."""
    base = {(e["seed"], e["index"]): episode_metrics(e) for e in baseline}
    differences: dict[str, list[float]] = {key: [] for key in METRIC_LABELS}
    for e in rows:
        other = base.get((e["seed"], e["index"]))
        if other is None:
            continue
        mine = episode_metrics(e)
        for key in METRIC_LABELS:
            differences[key].append(mine[key] - other[key])
    result = {}
    for key, values in differences.items():
        if len(values) > 1:
            array = np.array(values)
            result[key] = (float(array.mean()), float(2.0 * array.std(ddof=1) / math.sqrt(len(array))))
    return result


# Critic and entropy ------------------------------------------------------------------------------------------

def head_slices(schema: MobSchema) -> list[tuple[str, int, int]]:
    slices, cursor = [], 0
    for name in HEAD_NAMES:
        slices.append((name, cursor, schema.head_sizes[name]))
        cursor += schema.head_sizes[name]
    return slices


def diagnose(contestant: Contestant, shard_folder: Path, schema: MobSchema, settings: dict) -> dict | None:
    parts = [R.read_shard(path, schema) for path in sorted(shard_folder.glob("*.shard"))] if shard_folder.exists() else []
    parts = [p for p in parts if p.rows]
    if not parts:
        return None
    batch = R.concatenate(parts)
    cfg = settings["trainer"]
    policy, critic = MobPolicy(schema), MobCritic(schema)
    policy.load_state_dict(contestant.state["policy"])
    critic.load_state_dict(contestant.state["critic"])
    policy.eval()
    critic.eval()
    obs = torch.as_tensor(np.ascontiguousarray(batch.obs))
    global_state = torch.as_tensor(np.ascontiguousarray(batch.global_state))
    with torch.no_grad():
        values = torch.cat([critic(obs[i:i + 16384], global_state[i:i + 16384]) for i in range(0, batch.rows, 16384)]).numpy()
    gamma, lam = float(cfg["gamma"]), float(cfg["lambda"])
    _adv, gae_returns = R.advantages(batch.reward, values, batch.end, gamma, lam)
    _adv, mc_returns = R.advantages(batch.reward, values, batch.end, gamma, 1.0)

    def explained(target: np.ndarray) -> float:
        spread = float(np.var(target))
        return 1.0 - float(np.var(target - values)) / spread if spread > 0 else float("nan")

    result = {"rows": batch.rows, "lives": int(batch.life.max()) + 1,
              "explained_variance_gae": explained(gae_returns), "explained_variance_full": explained(mc_returns),
              "value_mean": float(values.mean()), "return_mean": float(mc_returns.mean()), "return_std": float(mc_returns.std()),
              "reward_per_decision_mean": float(batch.reward.mean()), "reward_per_decision_std": float(batch.reward.std()),
              "reward_nonzero_share": float((np.abs(batch.reward) > 1e-6).mean())}
    windows, _first = R.sequences(batch.life, int(cfg["sequence"]))
    memory = torch.as_tensor(np.ascontiguousarray(batch.memory))
    masks = torch.as_tensor(np.ascontiguousarray(batch.masks)).bool()
    slices = head_slices(schema)
    entropy_sum = {name: 0.0 for name, _o, _s in slices}
    choice_rows = {name: 0 for name, _o, _s in slices}
    top_probability = {name: 0.0 for name, _o, _s in slices}
    rows_seen = 0
    with torch.no_grad():
        for start in range(0, windows.shape[0], 2048):
            window = torch.as_tensor(windows[start:start + 2048])
            valid = window >= 0
            index = window.clamp(min=0)
            hidden = memory[index[:, 0]]
            for step in range(index.shape[1]):
                rows = index[:, step]
                logits, hidden = policy(obs[rows], hidden)
                keep = valid[:, step]
                if not keep.any():
                    continue
                logits, legal_rows = logits[keep], masks[rows[keep]]
                rows_seen += int(keep.sum())
                for name, offset, size in slices:
                    legal = legal_rows[:, offset:offset + size]
                    options = legal.sum(1)
                    choice = options >= 2
                    if not choice.any():
                        continue
                    logp = torch.log_softmax(logits[:, offset:offset + size].masked_fill(~legal, -1e9), dim=1)
                    probability = logp.exp().masked_fill(~legal, 0.0)
                    entropy = -(probability * logp).masked_fill(~legal, 0.0).sum(1)
                    entropy_sum[name] += float(entropy[choice].sum())
                    top_probability[name] += float(probability[choice].max(1).values.sum())
                    choice_rows[name] += int(choice.sum())
    result["heads"] = {name: {"entropy_when_choosing": entropy_sum[name] / max(1, choice_rows[name]),
                              "share_of_entropy_sum": entropy_sum[name] / max(1e-9, sum(entropy_sum.values())),
                              "entropy_per_decision": entropy_sum[name] / max(1, rows_seen),
                              "decisions_with_a_choice": choice_rows[name] / max(1, rows_seen),
                              "top_option_probability": top_probability[name] / max(1, choice_rows[name])}
                       for name, _o, _s in slices}
    result["entropy_per_decision"] = sum(entropy_sum.values()) / max(1, rows_seen)
    return result


# Report ------------------------------------------------------------------------------------------------------

def fmt(value: float, kind: str) -> str:
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return "-"
    return f"{100 * value:.1f}%" if kind == "pct" else f"{value:.2f}"


def fmt_difference(pair: tuple[float, float] | None, kind: str) -> str:
    if pair is None:
        return "-"
    value, error = pair
    scale = 100.0 if kind == "pct" else 1.0
    unit = " pts" if kind == "pct" else ""
    sure = "" if abs(value) > error else " (within noise)"
    return f"{scale * value:+.2f} ± {scale * error:.2f}{unit}{sure}"


def table(header: list[str], rows: list[list[str]]) -> list[str]:
    lines = ["| " + " | ".join(header) + " |", "|" + "|".join("---" for _ in header) + "|"]
    lines += ["| " + " | ".join(row) + " |" for row in rows]
    return lines


def report(contestants: list[Contestant], results: dict, diagnoses: dict, names: list[str], args) -> tuple[str, dict]:
    labels = [c.label for c in contestants]
    baseline = labels[0]
    summaries = {label: {"all": summarise(rows, names),
                         "engaged": summarise([e for e in rows if e["mode"] == "engaged"], names),
                         "explore": summarise([e for e in rows if e["mode"] == "explore"], names)}
                 for label, rows in results.items()}
    comparisons = {label: paired(results[label], results[baseline]) for label in labels[1:]}
    lines = [f"# Mob brain evaluation", "",
             f"{args.episodes} seeded training episodes per brain (seed {args.seed}), identical for every brain. "
             f"Brains: {', '.join(labels)}. Differences are per fight against **{baseline}** on the same fights, "
             "with two standard errors; a difference smaller than its error is within noise.", ""]
    for mode in ("all", "engaged", "explore"):
        title = {"all": "All fights", "engaged": "Engaged starts (mobs begin 9-16 m away)",
                 "explore": "Explore starts (mobs begin 25-45 m away, unaware)"}[mode]
        lines += [f"## {title}", ""]
        rows = []
        for key, (label, kind) in METRIC_LABELS.items():
            rows.append([label] + [fmt(summaries[l][mode][key], kind) for l in labels])
        for key, label, kind in (("reached_3m", "Fights where a mob got within 3 m", "pct"),
                                 ("first_within_3m", "First mob within 3 m (s)", "num"),
                                 ("explore_found", "Explore: party found", "pct"),
                                 ("explore_first_sight", "Explore: first sight (s)", "num")):
            if mode == "engaged" and key.startswith("explore"):
                continue
            rows.append([label] + [fmt(summaries[l][mode][key], kind) for l in labels])
        lines += table(["Measure"] + labels, rows) + [""]
        if mode == "all" and comparisons:
            lines += ["### Same fights, difference from " + baseline, ""]
            rows = [[label] + [fmt_difference(comparisons[l].get(key), kind) for l in labels[1:]]
                    for key, (label, kind) in METRIC_LABELS.items()]
            lines += table(["Measure"] + labels[1:], rows) + [""]
    lines += ["## How mobs spend their time (share of mob-seconds, all fights)", ""]
    keys = ["aware", "sees", "within_3m", "3_to_8m", "8_to_16m", "beyond_16m"]
    nice = {"aware": "Knows where a player is", "sees": "Sees a player", "within_3m": "Within 3 m of a player",
            "3_to_8m": "3-8 m", "8_to_16m": "8-16 m", "beyond_16m": "Beyond 16 m"}
    lines += table(["Measure"] + labels, [[nice[k]] + [fmt(summaries[l]["all"]["time"].get(k, float("nan")), "pct") for l in labels] for k in keys]) + [""]
    lines += ["## Behaviours chosen while aware of the party (share of decisions)", ""]
    rows = []
    for name in names:
        shares = [summaries[l]["all"]["awake_behaviours"].get(name, 0.0) for l in labels]
        if max(shares) >= 0.001:
            rows.append([name] + [fmt(s, "pct") for s in shares])
    lines += table(["Behaviour"] + labels, rows) + [""]
    lines += ["## Behaviours chosen before sensing anyone (share of decisions)", ""]
    rows = []
    for name in names:
        shares = [summaries[l]["all"]["idle_behaviours"].get(name, 0.0) for l in labels]
        if max(shares) >= 0.001:
            rows.append([name] + [fmt(s, "pct") for s in shares])
    lines += table(["Behaviour"] + labels, rows) + [""]
    lines += ["## Mob reward per fight by kind (all mobs together)", ""]
    kinds: list[str] = []
    for label in labels:
        kinds += [k for k in summaries[label]["all"]["reward_values"] if k not in kinds]
    lines += table(["Reward"] + labels, [[k] + [f"{summaries[l]['all']['reward_values'].get(k, 0.0):+.3f}" for l in labels] for k in kinds]) + [""]
    if diagnoses:
        lines += ["## Critic and policy diagnosis (recorded decisions of the first episodes)", "",
                  "Explained variance: 1 means the critic predicts what mobs go on to earn; 0 means it predicts nothing "
                  "beyond the average, so PPO's advantages are mostly noise. Healthy PPO runs are usually above 0.3.", ""]
        diag_labels = list(diagnoses)
        rows = [["Decisions recorded"] + [str(diagnoses[l]["rows"]) for l in diag_labels],
                ["Explained variance (training targets)"] + [f"{diagnoses[l]['explained_variance_gae']:.3f}" for l in diag_labels],
                ["Explained variance (full returns)"] + [f"{diagnoses[l]['explained_variance_full']:.3f}" for l in diag_labels],
                ["Return per decision: mean / spread"] + [f"{diagnoses[l]['return_mean']:+.3f} / {diagnoses[l]['return_std']:.3f}" for l in diag_labels],
                ["Reward per decision: mean / spread"] + [f"{diagnoses[l]['reward_per_decision_mean']:+.4f} / {diagnoses[l]['reward_per_decision_std']:.4f}" for l in diag_labels],
                ["Decisions with any reward"] + [fmt(diagnoses[l]["reward_nonzero_share"], "pct") for l in diag_labels],
                ["Summed entropy per decision"] + [f"{diagnoses[l]['entropy_per_decision']:.3f}" for l in diag_labels]]
        lines += table(["Measure"] + diag_labels, rows) + [""]
        lines += ["### Entropy by action head", "",
                  "Per head: share of the summed entropy / entropy when the head has a choice / probability of its top option.", ""]
        rows = []
        for head in HEAD_NAMES:
            cells = []
            for label in diag_labels:
                h = diagnoses[label]["heads"][head]
                cells.append(f"{100 * h['share_of_entropy_sum']:.0f}% / {h['entropy_when_choosing']:.2f} / {100 * h['top_option_probability']:.0f}%")
            rows.append([head] + cells)
        lines += table(["Head"] + diag_labels, rows) + [""]
    data = {"episodes": args.episodes, "seed": args.seed, "brains": labels, "baseline": baseline, "summaries": summaries,
            "comparisons": {l: {k: list(v) for k, v in c.items()} for l, c in comparisons.items()}, "diagnoses": diagnoses}
    return "\n".join(lines) + "\n", data


# Main --------------------------------------------------------------------------------------------------------

def main() -> int:
    settings = S.load_training_settings(HERE)
    configured = settings.get("run_dir") or ""
    default_run = Path(configured) if configured else Path.home() / "Documents" / "Godot" / "mob-training" / "run"
    parser = argparse.ArgumentParser(description="Compare mob brains on identical training fights.")
    parser.add_argument("--run-dir", type=Path, default=default_run)
    parser.add_argument("--checkpoints", type=Path, nargs="*", default=None)
    parser.add_argument("--milestones", type=int, default=3)
    parser.add_argument("--episodes", type=int, default=240)
    parser.add_argument("--processes", type=int, default=0, help="Godot processes at once (default: most threads, or a quarter while training runs here)")
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--record", type=int, default=12, help="episodes per checkpoint whose decisions the critic diagnosis uses")
    parser.add_argument("--no-scripted", action="store_true")
    parser.add_argument("--no-random", action="store_true", help="leave out the random brain (uniform over legal options)")
    parser.add_argument("--temperatures", type=float, nargs="*", default=[],
                        help="also play the newest checkpoint at these sampling temperatures (below 1 is sharper)")
    parser.add_argument("--game-temperature", action="store_true",
                        help="also play every checkpoint as the game samples it (temperature by intelligence)")
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args()
    if args.episodes < 1:
        raise SystemExit("--episodes must be at least 1.")
    if args.processes < 1:
        threads = os.cpu_count() or 4
        beat_file = args.run_dir / "trainer.json"
        heartbeat = S.read_json(beat_file) or {}
        training = heartbeat.get("state") in ("training", "waiting") and time.time() - beat_file.stat().st_mtime < 120
        args.processes = max(1, threads // 4 if training else threads - 2)
        if training:
            print(f"Training is running on this computer: using {args.processes} processes so it keeps most of the processor.")
    out = args.out or (args.run_dir.parent / "evaluations" / time.strftime("%Y%m%d-%H%M%S"))
    out.mkdir(parents=True, exist_ok=True)
    schema = MobSchema()
    paths = args.checkpoints if args.checkpoints else default_checkpoints(args.run_dir, args.milestones)
    if not paths:
        raise SystemExit(f"No checkpoints found in {args.run_dir / 'checkpoints'}. Pass --checkpoints.")
    contestants = prepare(paths, schema, out)
    if not contestants:
        raise SystemExit("None of the checkpoints could be used.")
    contestants.sort(key=lambda c: c.samples)
    newest = contestants[-1]
    if args.game_temperature:
        contestants += [game_tempered(c) for c in list(contestants)]
    for temperature in args.temperatures:
        if not 0.0 < temperature < 10.0:
            raise SystemExit("--temperatures must be between 0 and 10.")
        contestants.append(sharpened(newest, temperature, schema, out))
    if not args.no_random:
        contestants.insert(0, random_brain(schema, out))
    if not args.no_scripted:
        contestants.insert(0, Contestant(SCRIPTED, contestants[-1].policy_file))
    print("Brains: " + ", ".join(c.label for c in contestants))
    print(f"Results: {out}")
    run_jobs(contestants, settings, args, out)
    results = load_results(contestants, out)
    names = [entry["name"] for entry in json.loads((PROJECT / "mob_sim" / "mob_contract.json").read_text(encoding="utf-8"))["behaviours"]]
    diagnoses = {}
    for index, contestant in enumerate(contestants):
        if contestant.kind == "policy":
            found = diagnose(contestant, out / "shards" / f"c{index:02d}", schema, settings)
            if found:
                diagnoses[contestant.label] = found
    text, data = report(contestants, results, diagnoses, names, args)
    S.atomic_write_bytes(out / "report.md", text.encode("utf-8"))
    S.atomic_write_json(out / "summary.json", data)
    print()
    print(text)
    print(f"Saved {out / 'report.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
