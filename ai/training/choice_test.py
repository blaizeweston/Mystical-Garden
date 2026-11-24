"""The choice test: does a mob's choice change what it earns, and do the policy and the critic know which choice pays?

For each moment (one free decision of one mob that knows where the party is, in one seeded training fight),
ai/choice_test.gd replays the fight once per legal behaviour and continuation seed, forcing that behaviour, and
records what the mob went on to earn. Behaviours share continuation seeds, so they are compared on the same luck.
From that this measures, with the checkpoint's own policy and critic:

- How much the choice matters: the spread of what the options earn on average (signal) against the spread of
  what one option earns from one fight to the next (luck). PPO learns from one sampled future per decision, so if
  luck dwarfs the signal the trainer cannot tell good choices from bad ones, whatever its settings.
- Whether the policy already prefers the options that pay (it may have learned all there is to learn).
- Whether the critic's advantage, the number PPO actually learns from, ranks the options as the real outcomes do.
- Per behaviour: what it really earns against the policy's average choice, and what the critic thinks it earns.

  python choice_test.py [--checkpoint <ckpt.pt>] [--moments 200] [--continuations 4] [--rows 64]
                        [--processes <n>] [--seed 3] [--out <folder>] [--keep-shards]

With no --checkpoint it takes the run folder's newest checkpoint (copy it first if training may prune it). It
only reads the run folder; results go to --out (default: an evaluations folder next to the run folder). Running it
again with the same --out finishes the moments not yet done.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
import torch

import evaluate as E
import rollouts as R
import safe_files as S
from mob_net import MobCritic, MobPolicy
from mob_schema import MobSchema

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parent.parent
JOB_TIMEOUT_SECONDS = 3600


# One moment ---------------------------------------------------------------------------------------------------

def discounted(rewards: list[float], gamma: float) -> float:
    total = 0.0
    for reward in reversed(rewards):
        total = reward + gamma * total
    return total


def critic_advantage(rewards: list[float], values: np.ndarray, gamma: float, lam: float) -> float:
    """The advantage PPO would give the first decision (GAE) from the kept decisions. When the life ended within
    them, its last decision is terminal; otherwise the sum stops one decision early, bootstrapped by the critic."""
    kept = len(values)
    if kept == 0:
        return float("nan")
    whole = kept >= len(rewards)
    total, weight = 0.0, 1.0
    for i in range(kept):
        if i + 1 < kept:
            delta = rewards[i] + gamma * values[i + 1] - values[i]
        elif whole:
            delta = rewards[i] - values[i]
        else:
            break
        total += weight * delta
        weight *= gamma * lam
    return total


def analyse_moment(moment: dict, shard: Path | None, policy: MobPolicy, critic: MobCritic, schema: MobSchema,
                   gamma: float, lam: float, behaviour_slice: tuple[int, int]) -> dict:
    """Per option: true discounted return per continuation, the critic's advantage, the squad's reward after the
    moment, wipes and party damage; plus the policy's probabilities and the critic's value at the moment."""
    if not moment.get("moment"):
        return {"skipped": "no free aware decision in this fight"}
    branches = moment["branches"]
    good = [b for b in branches if b["forced"] and b["legal"] and b["same_state"] and b["life"] >= 0]
    result = {"fight_seed": moment["fight_seed"], "mode": moment["scout"]["mode"], "mobs": moment["scout"]["mobs"],
              "seconds_in": moment["moment"]["seconds"], "branches": len(branches), "bad_replays": sum(not b["same_state"] for b in branches),
              "not_forced": sum(not (b["forced"] and b["legal"]) for b in branches)}
    if not good or shard is None or not shard.exists():
        result["skipped"] = "no usable branches"
        return result
    rollout = R.read_shard(shard, schema)
    obs = torch.as_tensor(np.array(rollout.obs))
    global_state = torch.as_tensor(np.array(rollout.global_state))
    with torch.no_grad():
        values = critic(obs, global_state).numpy()
    life_rows = {life: np.flatnonzero(rollout.life == life) for life in range(int(rollout.life.max()) + 1 if rollout.rows else 0)}
    options: dict[int, dict] = {}
    for b in good:
        rows = life_rows.get(b["life"])
        if rows is None or len(rows) == 0:
            continue
        entry = options.setdefault(int(b["option"]), {"returns": {}, "advantages": {}, "squad": {}, "wipe": {}, "damage": {}})
        c = int(b["continuation"])
        entry["returns"][c] = discounted(b["rewards"], gamma)
        entry["advantages"][c] = float(critic_advantage(b["rewards"], values[rows], gamma, lam))
        entry["squad"][c] = float(b["report"]["squad_after"])
        entry["wipe"][c] = float(b["report"]["outcome"] == "wipe")
        entry["damage"][c] = float(b["report"]["party_damage_after"])
        if "row" not in result:
            result["row"] = int(rows[0])
    if "row" not in result:
        result["skipped"] = "no recorded decisions"
        return result
    row = result.pop("row")
    start, size = behaviour_slice
    with torch.no_grad():
        logits, _hidden = policy(obs[row:row + 1], torch.as_tensor(np.array(rollout.memory[row:row + 1])))
    legal = torch.as_tensor(rollout.masks[row, start:start + size].astype(bool))
    probabilities = torch.softmax(logits[0, start:start + size].masked_fill(~legal, -1e9), dim=0).numpy()
    result["value"] = float(values[row])
    result["options"] = {str(k): {"probability": float(probabilities[k]), **{key: [v[c] for c in sorted(v)] for key, v in entry.items()}}
                         for k, entry in sorted(options.items())}
    return result


# Running the moments ------------------------------------------------------------------------------------------

def run_moments(policy_file: Path, settings: dict, args, out: Path, schema: MobSchema, policy: MobPolicy,
                critic: MobCritic, mix: float) -> None:
    godot = settings.get("godot", "")
    if not godot or not Path(godot).exists():
        raise SystemExit(f"Godot was not found at '{godot}'. Set \"godot\" in training.local.json.")
    cfg = settings["trainer"]
    gamma, lam = float(cfg["gamma"]), float(cfg["lambda"])
    behaviour = next((offset, size) for name, offset, size in E.head_slices(schema) if name == "behaviour")
    for name in ("moments", "shards", "results", "logs"):
        (out / name).mkdir(parents=True, exist_ok=True)
    jobs = []
    for index in range(args.moments):
        name = f"m{index:04d}"
        if (out / "results" / f"{name}.json").exists():
            continue
        seed = args.seed * 100003 + index
        command = [godot, "--headless", "--path", str(PROJECT), "--script", "res://ai/choice_test.gd", "--",
                   "--policy", str(policy_file), "--fight-seed", str(seed), "--continuations", str(args.continuations),
                   "--rows", str(args.rows), "--out", str(out / "moments" / f"{name}.json"), "--shards", str(out / "shards" / name),
                   "--squad-mix", f"{mix:.4f}"]
        jobs.append((name, command))
    total = len(jobs)
    if total == 0:
        return
    print(f"Playing {total} moments, {args.continuations} continuations per legal behaviour, {args.processes} at a time.")
    running: list[tuple[str, subprocess.Popen, float, object]] = []
    done = failed = 0
    began = time.monotonic()
    while jobs or running:
        while jobs and len(running) < args.processes:
            name, command = jobs.pop(0)
            log = (out / "logs" / f"{name}.log").open("w", encoding="utf-8")
            running.append((name, subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, cwd=str(PROJECT)), time.monotonic(), log))
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
            moment_file = out / "moments" / f"{name}.json"
            if code != 0 or not moment_file.exists():
                failed += 1
                print(f"  {name} failed (exit {code}); see logs/{name}.log")
                continue
            moment = json.loads(moment_file.read_text(encoding="utf-8"))
            shard = out / "shards" / name / "moment.shard"
            result = analyse_moment(moment, shard, policy, critic, schema, gamma, lam, behaviour)
            S.atomic_write_json(out / "results" / f"{name}.json", result)
            if not args.keep_shards:
                shutil.rmtree(out / "shards" / name, ignore_errors=True)
            elapsed = time.monotonic() - began
            if done % 10 == 0 or done == total:
                print(f"  {done}/{total} moments, {elapsed / 60:.1f} min" + (f", about {elapsed / done * (total - done) / 60:.1f} min left" if done < total else ""))
    if failed:
        print(f"{failed} moment(s) failed. Run again with the same --out to retry them.")


# Analysis -----------------------------------------------------------------------------------------------------

def nan_mean(values) -> float:
    values = [v for v in values if v is not None and np.isfinite(v)]
    return float(np.mean(values)) if values else float("nan")


def standard_error(values) -> float:
    values = [v for v in values if v is not None and np.isfinite(v)]
    return float(np.std(values, ddof=1) / math.sqrt(len(values))) if len(values) > 1 else float("nan")


def correlation(a, b) -> float:
    a, b = np.asarray(a, dtype=float), np.asarray(b, dtype=float)
    if len(a) < 3 or a.std() < 1e-12 or b.std() < 1e-12:
        return float("nan")
    return float(np.corrcoef(a, b)[0, 1])


def moment_stats(result: dict) -> dict | None:
    """What one moment says. Needs two or more options, each with the same two or more continuations."""
    options = result.get("options") or {}
    keys = sorted(options, key=int)
    if len(keys) < 2:
        return None
    count = min(len(options[k]["returns"]) for k in keys)
    if count < 2:
        return None
    g = np.array([options[k]["returns"][:count] for k in keys])
    a = np.array([options[k]["advantages"][:count] for k in keys])
    squad = np.array([options[k]["squad"][:count] for k in keys])
    wipe = np.array([options[k]["wipe"][:count] for k in keys])
    p = np.array([options[k]["probability"] for k in keys])
    p = p / p.sum() if p.sum() > 0 else np.full(len(keys), 1.0 / len(keys))
    means, a_means, squad_means = g.mean(1), a.mean(1), squad.mean(1)
    luck = float(g.var(1, ddof=1).mean())
    policy_mean = float(p @ means)
    signal_uniform = max(0.0, float(means.var(ddof=1)) - luck / count)
    signal_policy = max(0.0, float(p @ (means - policy_mean) ** 2) - luck / count)
    # Winner's curse: choose the best option on half the continuations, judge it on the other half.
    half = count // 2
    regrets, agree = [], []
    for pick, judge in ((slice(0, half), slice(half, count)), (slice(half, count), slice(0, half))):
        if half == 0:
            break
        chosen = int(np.argmax(g[:, pick].mean(1)))
        judged = g[:, judge].mean(1)
        regrets.append(float(judged[chosen] - p @ judged))
    stats = {
        "options": len(keys), "continuations": count, "luck_var": luck, "signal_var": signal_uniform, "signal_var_policy": signal_policy,
        "gap_best_worst": float(means.max() - means.min()), "regret": float(np.mean(regrets)) if regrets else float("nan"),
        "policy_top_is_best": float(int(np.argmax(p)) == int(np.argmax(means))), "chance_top_is_best": 1.0 / len(keys),
        "policy_corr": correlation(p, means), "critic_corr": correlation(a_means, means), "squad_corr": correlation(squad_means, means),
        "value": float(result["value"]), "policy_return": policy_mean,
        "wipe_spread": float(wipe.mean(1).max() - wipe.mean(1).min()),
        "squad_luck_var": float(squad.var(1, ddof=1).mean()), "squad_signal_var": max(0.0, float(squad_means.var(ddof=1)) - float(squad.var(1, ddof=1).mean()) / count),
        "edges": {},
    }
    a_policy, squad_policy = float(p @ a_means), float(p @ squad_means)
    for index, k in enumerate(keys):
        stats["edges"][int(k)] = {"true": float(means[index] - policy_mean), "critic": float(a_means[index] - a_policy),
                                  "squad": float(squad_means[index] - squad_policy), "probability": float(p[index]),
                                  "best": float(index == int(np.argmax(means)))}
    return stats


def summarise(results: list[dict], names: list[str]) -> dict:
    stats = [s for s in (moment_stats(r) for r in results) if s]
    luck = sum(s["luck_var"] for s in stats)
    signal = sum(s["signal_var"] for s in stats)
    signal_policy = sum(s["signal_var_policy"] for s in stats)
    squad_luck = sum(s["squad_luck_var"] for s in stats)
    squad_signal = sum(s["squad_signal_var"] for s in stats)
    summary = {
        "moments": len(results), "used": len(stats),
        "skipped": sum(1 for r in results if r.get("skipped")),
        "bad_replays": sum(int(r.get("bad_replays", 0)) for r in results),
        "branches": sum(int(r.get("branches", 0)) for r in results),
        "choice_share": signal / (signal + luck) if signal + luck > 0 else float("nan"),
        "choice_share_policy": signal_policy / (signal_policy + luck) if signal_policy + luck > 0 else float("nan"),
        "squad_choice_share": squad_signal / (squad_signal + squad_luck) if squad_signal + squad_luck > 0 else float("nan"),
        "signal_std": math.sqrt(signal / len(stats)) if stats else float("nan"),
        "luck_std": math.sqrt(luck / len(stats)) if stats else float("nan"),
        "gap_best_worst": nan_mean(s["gap_best_worst"] for s in stats),
        "regret": nan_mean(s["regret"] for s in stats), "regret_error": standard_error([s["regret"] for s in stats]),
        "policy_top_is_best": nan_mean(s["policy_top_is_best"] for s in stats),
        "chance_top_is_best": nan_mean(s["chance_top_is_best"] for s in stats),
        "policy_corr": nan_mean(s["policy_corr"] for s in stats),
        "critic_corr": nan_mean(s["critic_corr"] for s in stats),
        "squad_corr": nan_mean(s["squad_corr"] for s in stats),
        "value_bias": nan_mean(s["value"] - s["policy_return"] for s in stats),
        "value_corr": correlation([s["value"] for s in stats], [s["policy_return"] for s in stats]),
        "wipe_spread": nan_mean(s["wipe_spread"] for s in stats),
        "options": nan_mean(s["options"] for s in stats),
    }
    behaviours = {}
    for option in sorted({k for s in stats for k in s["edges"]}):
        edges = [s["edges"][option] for s in stats if option in s["edges"]]
        behaviours[names[option] if option < len(names) else str(option)] = {
            "moments": len(edges), "probability": nan_mean(e["probability"] for e in edges),
            "true_edge": nan_mean(e["true"] for e in edges), "true_error": standard_error([e["true"] for e in edges]),
            "critic_edge": nan_mean(e["critic"] for e in edges), "squad_edge": nan_mean(e["squad"] for e in edges),
            "best_share": nan_mean(e["best"] for e in edges)}
    summary["behaviours"] = behaviours
    return summary


def report(summary: dict, label: str, args) -> str:
    s = summary
    f = lambda v, d=3: "-" if v is None or not np.isfinite(v) else f"{v:+.{d}f}"
    pct = lambda v: "-" if v is None or not np.isfinite(v) else f"{100 * v:.1f}%"
    lines = [f"# Choice test: {label}", "",
             f"{s['used']} moments used of {s['moments']} ({s['skipped']} skipped), {s['branches']} replayed fights, "
             f"{args.continuations} continuations per legal behaviour, on average {s['options']:.1f} legal behaviours. "
             f"Replays that did not reach the scouted state: {s['bad_replays']} (should be 0). Returns are the mob's own "
             "discounted return from the moment (the trainer's gamma per decision), in mob reward units.", "",
             "## Does the choice matter?", "",
             "Choice share: of the spread in what a mob earns after one decision, the part that comes from which behaviour it "
             "chose rather than how the rest of the fight went. PPO sees one sampled future per decision, so a small share "
             "means its advantages are mostly luck.", ""]
    lines += E.table(["Measure", "Value"], [
        ["Choice share, options equally weighted", pct(s["choice_share"])],
        ["Choice share, options weighted by the policy", pct(s["choice_share_policy"])],
        ["Spread from the choice (std)", f(s["signal_std"]).lstrip("+")],
        ["Spread from luck (std)", f(s["luck_std"]).lstrip("+")],
        ["Best minus worst option, on average", f(s["gap_best_worst"])],
        ["Squad reward after the moment: choice share", pct(s["squad_choice_share"])],
        ["Best minus worst option's wipe rate", pct(s["wipe_spread"])],
    ]) + ["", "## Does the policy know which choice pays?", ""]
    lines += E.table(["Measure", "Value"], [
        ["Return lost against the best option (judged on held-out continuations)", f"{f(s['regret'])} ± {f(s['regret_error'])}"],
        ["Policy's favourite is the best option", f"{pct(s['policy_top_is_best'])} (chance: {pct(s['chance_top_is_best'])})"],
        ["Correlation of policy probability with true return", f(s["policy_corr"], 2)],
    ]) + ["", "## Does the critic know?", "",
          "Critic correlation: per moment, how well the advantage PPO computes for each option (from the critic, as in "
          "training) ranks the options by what they truly earned. Near 1 is a good teacher; near 0 teaches noise.", ""]
    lines += E.table(["Measure", "Value"], [
        ["Critic advantage vs true return, correlation across options", f(s["critic_corr"], 2)],
        ["Critic value minus the policy's true return at the moment", f(s["value_bias"])],
        ["Critic value vs true return across moments, correlation", f(s["value_corr"], 2)],
        ["Own return vs squad reward across options, correlation", f(s["squad_corr"], 2)],
    ]) + ["", "## Per behaviour", "",
          "Edge: what choosing the behaviour earns compared with the policy's average choice at the same moment (true: from "
          "the replays; critic: the critic's advantage; squad: every mob's reward after the moment). Best: share of its "
          "moments where it was the best option.", ""]
    rows = []
    for name, b in sorted(s["behaviours"].items(), key=lambda kv: -kv[1]["moments"]):
        rows.append([name, str(b["moments"]), pct(b["probability"]), f"{f(b['true_edge'])} ± {f(b['true_error'])}",
                     f(b["critic_edge"]), f(b["squad_edge"]), pct(b["best_share"])])
    lines += E.table(["Behaviour", "Moments", "Policy picks", "True edge", "Critic edge", "Squad edge", "Best"], rows)
    return "\n".join(lines) + "\n"


# Main ---------------------------------------------------------------------------------------------------------

def main() -> int:
    settings = S.load_training_settings(HERE)
    configured = settings.get("run_dir") or ""
    default_run = Path(configured) if configured else Path.home() / "Documents" / "Godot" / "mob-training" / "run"
    parser = argparse.ArgumentParser(description="Measure whether mob choices change what they earn, and whether the policy and critic know.")
    parser.add_argument("--run-dir", type=Path, default=default_run)
    parser.add_argument("--checkpoint", type=Path, default=None)
    parser.add_argument("--moments", type=int, default=200)
    parser.add_argument("--continuations", type=int, default=4)
    parser.add_argument("--rows", type=int, default=64, help="decisions per branch kept for the critic")
    parser.add_argument("--processes", type=int, default=0)
    parser.add_argument("--seed", type=int, default=3)
    parser.add_argument("--keep-shards", action="store_true")
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args()
    if args.moments < 1 or args.continuations < 2 or args.rows < 2:
        raise SystemExit("--moments must be at least 1, --continuations and --rows at least 2.")
    if args.processes < 1:
        threads = os.cpu_count() or 4
        beat_file = args.run_dir / "trainer.json"
        heartbeat = S.read_json(beat_file) or {}
        training = beat_file.exists() and heartbeat.get("state") in ("training", "waiting") and time.time() - beat_file.stat().st_mtime < 120
        args.processes = max(1, threads // 4 if training else threads - 2)
        if training:
            print(f"Training is running on this computer: using {args.processes} processes so it keeps most of the processor.")
    paths = [args.checkpoint] if args.checkpoint else E.default_checkpoints(args.run_dir, 0)[-1:]
    if not paths:
        raise SystemExit(f"No checkpoints found in {args.run_dir / 'checkpoints'}. Pass --checkpoint.")
    out = args.out or (args.run_dir.parent / "evaluations" / time.strftime("choice_%Y%m%d-%H%M%S"))
    out.mkdir(parents=True, exist_ok=True)
    schema = MobSchema()
    contestants = E.prepare(paths, schema, out)
    if not contestants:
        raise SystemExit("The checkpoint could not be used.")
    contestant = contestants[0]
    policy, critic = MobPolicy(schema), MobCritic(schema)
    policy.load_state_dict(contestant.state["policy"])
    critic.load_state_dict(contestant.state["critic"])
    policy.eval()
    critic.eval()
    mix = E.squad_mix(contestant.samples, settings)
    print(f"Checkpoint: {contestant.label}. Results: {out}")
    run_moments(contestant.policy_file, settings, args, out, schema, policy, critic, mix)
    results = [json.loads(p.read_text(encoding="utf-8")) for p in sorted((out / "results").glob("m*.json"))]
    names = [entry["name"] for entry in json.loads((PROJECT / "mob_sim" / "mob_contract.json").read_text(encoding="utf-8"))["behaviours"]]
    summary = summarise(results, names)
    text = report(summary, contestant.label, args)
    S.atomic_write_bytes(out / "report.md", text.encode("utf-8"))
    S.atomic_write_json(out / "summary.json", summary)
    print()
    print(text)
    print(f"Saved {out / 'report.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
