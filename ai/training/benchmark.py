"""The fixed benchmark: the same seeded fights every time, so a change is judged on brains, not on luck.

Every brain plays the same BENCHMARK_EPISODES fights from BENCHMARK_SEED, set up exactly as in training (floors,
parties, difficulty, light, mob groups), through evaluate.py's paired runs:
- the game's scripted brain, the bar every checkpoint is measured against fight by fight;
- the newest checkpoint (or --checkpoint), at temperature 1 as in training and as the game samples it
  (sharper for brighter mobs), since the game's way is how players meet it;
- every anchor checkpoint in <benchmark>/anchors (earlier brains kept for comparison, converted to this schema).

It reports wipes, party health removed and fights that run out of time, overall and by kind of fight: dark or lit,
party size, mobs per player, and party skill. "Contested" fights (2-5 mobs per player) lead the summary, since
lopsided fights are decided by the setup whatever the brain does. These are measurements only: nothing here
feeds a reward.

  python benchmark.py [--run-dir <folder>] [--checkpoint <file.pt>] [--episodes 600] [--processes <n>]
                      [--label <text>] [--no-anchors] [--out <folder>]

Results go to <benchmark>/<time>/ (report.md, summary.json), and one line per run is appended to
<benchmark>/history.jsonl with the brain's per-fight edge over the scripted brain. <benchmark>/best.json names the
best brain benchmarked so far (most party health removed in contested fights). <benchmark> is a folder named
benchmark next to the run folder. Only the run folder's checkpoints are read; training can keep running, though it
then shares the processor. The trainer runs it with --no-anchors at every milestone (trainer setting
benchmark_milestones); <benchmark>/running.json keeps two from running at once.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time
from pathlib import Path
from types import SimpleNamespace

import numpy as np

import evaluate as E
import safe_files as S
from mob_schema import MobSchema
from train import default_run_dir, load_settings, pid_alive

BENCHMARK_SEED = 20261125
BENCHMARK_EPISODES = 600
LIT_THRESHOLD = 0.25

# Headline measures: (key from evaluate.episode_metrics, label, kind).
MEASURES = [("wipe", "Party wiped", "pct"), ("party_hp_lost", "Party health removed", "pct"),
            ("timeout", "Time ran out", "pct"), ("cleared", "Mobs all killed", "pct")]

# Kinds of fight, each a list of (name, test on an episode report).
STRATA = {
    "Light": [("dark", lambda e: float(e.get("light", 1.0)) < LIT_THRESHOLD),
              ("lit", lambda e: float(e.get("light", 1.0)) >= LIT_THRESHOLD)],
    "Party size": [(f"{n} player{'s' if n > 1 else ''}", (lambda n: lambda e: int(e["party"]) == n)(n)) for n in (1, 2, 3, 4)],
    "Mobs per player": [("under 2", lambda e: _ratio(e) < 2.0), ("2-5 (contested)", lambda e: 2.0 <= _ratio(e) <= 5.0),
                        ("over 5", lambda e: _ratio(e) > 5.0)],
    "Party skill": [("low (under 0.4)", lambda e: float(e["difficulty"]) < 0.4),
                    ("middle", lambda e: 0.4 <= float(e["difficulty"]) <= 0.6),
                    ("high (over 0.6)", lambda e: float(e["difficulty"]) > 0.6)],
}


def _ratio(e: dict) -> float:
    return int(e["mobs"]) / max(1, int(e["party"]))


def contested(e: dict) -> bool:
    return 2.0 <= _ratio(e) <= 5.0


def measure(rows: list[dict]) -> dict:
    metrics = [E.episode_metrics(e) for e in rows]
    return {key: (float(np.mean([m[key] for m in metrics])) if metrics else float("nan")) for key, _label, _kind in MEASURES} | {"fights": len(rows)}


def paired_subset(rows: list[dict], baseline: list[dict], keep) -> dict:
    """Mean per-fight difference from the baseline on the same fights within a subset, with two standard errors."""
    base = {(e["seed"], e["index"]): E.episode_metrics(e) for e in baseline}
    differences = {key: [] for key, _label, _kind in MEASURES}
    for e in rows:
        other = base.get((e["seed"], e["index"]))
        if other is None or not keep(e):
            continue
        mine = E.episode_metrics(e)
        for key in differences:
            differences[key].append(mine[key] - other[key])
    result = {}
    for key, values in differences.items():
        if len(values) > 1:
            array = np.array(values)
            result[key] = (float(array.mean()), float(2.0 * array.std(ddof=1) / math.sqrt(len(array))))
    return result


def anchors(folder: Path) -> list[Path]:
    return sorted(folder.glob("*.pt")) if folder.exists() else []


def newest_checkpoint(run_dir: Path) -> Path | None:
    found = E.default_checkpoints(run_dir, 0)
    return found[-1] if found else None


def build_report(labels: list[str], results: dict, args, version: int) -> tuple[str, dict]:
    baseline = E.SCRIPTED
    others = [label for label in labels if label != baseline]
    lines = ["# Mob brain benchmark", "",
             f"{args.episodes} fixed fights (seed {BENCHMARK_SEED}), the same for every brain, set up as in training. "
             f"Differences are per fight against the **scripted** brain on the same fights, with two standard errors; "
             "a difference smaller than its error is within noise. \"game\" plays a brain as the game samples it.", ""]
    summary = {"version": version, "episodes": args.episodes, "seed": BENCHMARK_SEED, "brains": labels, "overall": {},
               "contested": {}, "strata": {}}
    for title, keep in (("Contested fights (2-5 mobs per player)", contested), ("All fights", lambda e: True)):
        lines += [f"## {title}", ""]
        rows = []
        for label in labels:
            subset = [e for e in results[label] if keep(e)]
            values = measure(subset)
            cells = [label, str(values["fights"])] + [E.fmt(values[key], kind) for key, _l, kind in MEASURES]
            if label != baseline:
                pair = paired_subset(results[label], results[baseline], keep)
                cells += [E.fmt_difference(pair.get("wipe"), "pct"), E.fmt_difference(pair.get("party_hp_lost"), "pct")]
            else:
                cells += ["-", "-"]
            rows.append(cells)
            target = summary["contested" if keep is contested else "overall"]
            target[label] = values | ({"vs_scripted": paired_subset(results[label], results[baseline], keep)} if label != baseline else {})
        lines += E.table(["Brain", "Fights"] + [label for _k, label, _kind in MEASURES] + ["Wipes vs scripted", "Health removed vs scripted"], rows) + [""]
    lines += ["## By kind of fight", "", "Party health removed per fight, and its difference from the scripted brain on the same fights.", ""]
    for stratum, groups in STRATA.items():
        rows = []
        summary["strata"][stratum] = {}
        for name, keep in groups:
            base_rows = [e for e in results[baseline] if keep(e)]
            if not base_rows:
                continue
            cells = [name, str(len(base_rows)), E.fmt(measure(base_rows)["party_hp_lost"], "pct")]
            summary["strata"][stratum][name] = {"fights": len(base_rows), "scripted": measure(base_rows)}
            for label in others:
                pair = paired_subset(results[label], results[baseline], keep)
                cells.append(E.fmt_difference(pair.get("party_hp_lost"), "pct"))
                summary["strata"][stratum][name][label] = measure([e for e in results[label] if keep(e)]) | {"vs_scripted": pair}
            rows.append(cells)
        lines += [f"### {stratum}", ""] + E.table([stratum, "Fights", "Scripted"] + others, rows) + [""]
    return "\n".join(lines) + "\n", summary


def main() -> int:
    settings = load_settings()
    default_run = default_run_dir(settings)
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--run-dir", type=Path, default=default_run)
    parser.add_argument("--checkpoint", type=Path, default=None, help="the brain to benchmark (default: the run's newest checkpoint)")
    parser.add_argument("--episodes", type=int, default=BENCHMARK_EPISODES)
    parser.add_argument("--processes", type=int, default=0, help="Godot processes at once (default: most threads, or a quarter while training runs)")
    parser.add_argument("--label", default="", help="a note stored with this run in history.jsonl")
    parser.add_argument("--no-anchors", action="store_true", help="only the scripted brain and this one (the milestone runs)")
    parser.add_argument("--out", type=Path, default=None)
    args = parser.parse_args()
    if args.episodes < 1:
        raise SystemExit("--episodes must be at least 1.")
    folder = args.run_dir.parent / "benchmark"
    folder.mkdir(parents=True, exist_ok=True)
    if benchmark_running(folder):
        raise SystemExit(f"Another benchmark is running ({folder / 'running.json'}).")
    S.atomic_write_json(folder / "running.json", {"pid": os.getpid(), "time": time.strftime("%Y-%m-%d %H:%M:%S")})
    try:
        return run(args, settings, folder)
    finally:
        (folder / "running.json").unlink(missing_ok=True)


def benchmark_running(folder: Path) -> bool:
    """Whether a benchmark (another process) holds the folder's running.json."""
    holder = S.read_json(folder / "running.json") or {}
    pid = int(holder.get("pid", 0))
    return pid > 0 and pid != os.getpid() and pid_alive(pid)


def edge(pair: dict) -> dict:
    return {key: {"mean": round(value[0], 4), "error": round(value[1], 4)} for key, value in pair.items()}


def run(args, settings: dict, folder: Path) -> int:
    if args.processes < 1:
        threads = os.cpu_count() or 4
        beat_file = args.run_dir / "trainer.json"
        heartbeat = S.read_json(beat_file) or {}
        training = beat_file.exists() and heartbeat.get("state") in ("training", "waiting") and time.time() - beat_file.stat().st_mtime < 120
        args.processes = max(1, threads // 4 if training else threads - 2)
    out = args.out or (folder / time.strftime("%Y%m%d-%H%M%S"))
    out.mkdir(parents=True, exist_ok=True)
    checkpoint = args.checkpoint or newest_checkpoint(args.run_dir)
    if checkpoint is None:
        raise SystemExit(f"No checkpoint found in {args.run_dir / 'checkpoints'}. Pass --checkpoint.")
    schema = MobSchema()
    chosen = E.prepare([checkpoint], schema, out)
    if not chosen:
        raise SystemExit(f"{checkpoint.name} does not fit this schema. Convert it with convert_checkpoint.py first.")
    newest = chosen[0]
    brains = chosen if args.no_anchors else chosen + [b for b in E.prepare(anchors(folder / "anchors"), schema, out) if b.version != newest.version]
    contestants = [E.Contestant(E.SCRIPTED, newest.policy_file)]
    for brain in brains:
        contestants += [brain, E.game_tempered(brain)]
    print("Brains: " + ", ".join(c.label for c in contestants))
    print(f"Results: {out}")
    jobs = SimpleNamespace(episodes=args.episodes, seed=BENCHMARK_SEED, processes=args.processes, record=0)
    E.run_jobs(contestants, settings, jobs, out)
    results = E.load_results(contestants, out)
    text, summary = build_report([c.label for c in contestants], results, args, newest.version)
    S.atomic_write_bytes(out / "report.md", text.encode("utf-8"))
    S.atomic_write_json(out / "summary.json", summary)
    headline = {label: {k: round(v, 4) for k, v in values.items() if k != "vs_scripted"} for label, values in summary["contested"].items()}
    game = E.game_tempered(newest).label
    entry = {"time": time.strftime("%Y-%m-%d %H:%M:%S"), "version": newest.version, "label": args.label, "out": str(out),
             "checkpoint": str(checkpoint), "contested": headline,
             "edge": {"contested": edge(summary["contested"][newest.label]["vs_scripted"]),
                      "contested_game": edge(summary["contested"][game]["vs_scripted"]),
                      "all": edge(summary["overall"][newest.label]["vs_scripted"])}}
    S.append_line(folder / "history.jsonl", json.dumps(entry))
    best = S.read_json(folder / "best.json") or {}
    score = entry["edge"]["contested"].get("party_hp_lost", {}).get("mean")
    if score is not None and score > float(best.get("contested_hp_edge", -1e9)):
        S.atomic_write_json(folder / "best.json", {"version": newest.version, "checkpoint": str(checkpoint), "time": entry["time"],
                                                   "contested_hp_edge": score, "label": args.label})
        print(f"Best brain so far: v{newest.version} ({100 * score:+.1f} points of party health over the scripted brain in contested fights).")
    print()
    print(text)
    print(f"Saved {out / 'report.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
