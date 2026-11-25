"""The learnability probe: can the trainer learn a choice whose payoff is certain and immediate?

A short throwaway run, in its own folder, starts from a copy of a checkpoint with one planted reward: a decision
that sends message symbol --symbol on channel A earns --reward, kept whole. Messages change nothing in a fight
by themselves, so the payoff is clean and needs no credit assignment across the fight. The probe watches the
share of channel A choices that pick the symbol (logged by the trainer as message_a_choices) and reports how many
updates it took to pass half and --target.

If a planted, noise-free reward takes far longer than a few dozen updates to win out, the learning pipeline
(advantages, normalisation, learning rate, entropy bonus) is what limits training, not the game. If it is quick,
the plateau is about how hard the real signal is to read.

  python learnability_probe.py [--run-dir <main run>] [--checkpoint <file.pt>] [--symbol 3] [--reward 0.02]
                               [--minutes 40] [--workers <n>] [--target 0.9]

The main run must be stopped first (the probe needs the processor and the GPU); its folder is only read. The
probe runs in <main run's parent>/probes/<time>/ and writes result.json there. Stop it early with Ctrl+C: its
training is stopped either way.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

import evaluate as E
import safe_files as S
from mob_schema import MobSchema
from train import default_run_dir, load_settings

HERE = Path(__file__).resolve().parent
POLL_SECONDS = 20


def training_running(run_dir: Path) -> bool:
    beat = run_dir / "trainer.json"
    if not beat.exists():
        return False
    state = (S.read_json(beat) or {}).get("state")
    return state in ("training", "waiting") and time.time() - beat.stat().st_mtime < 120


def powershell(script: str, *arguments: str) -> int:
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(HERE / script), *arguments]
    return subprocess.call(command)


def read_metrics(path: Path) -> list[dict]:
    if not path.exists():
        return []
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            rows.append(json.loads(line))
        except ValueError:
            continue
    return rows


def main() -> int:
    settings = load_settings()
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--run-dir", type=Path, default=default_run_dir(settings))
    parser.add_argument("--checkpoint", type=Path, default=None, help="default: the main run's newest checkpoint")
    parser.add_argument("--symbol", type=int, default=3)
    parser.add_argument("--reward", type=float, default=0.02)
    parser.add_argument("--minutes", type=float, default=40.0)
    parser.add_argument("--workers", type=int, default=0)
    parser.add_argument("--target", type=float, default=0.9)
    args = parser.parse_args()
    schema = MobSchema()
    symbols = schema.head_sizes["message_a"]
    if not 0 < args.symbol < symbols:
        raise SystemExit(f"--symbol must be between 1 and {symbols - 1} (0 is the silent symbol).")
    if training_running(args.run_dir):
        raise SystemExit(f"Training is running in {args.run_dir}. Stop it first (stop_training.ps1); the probe needs the computer.")
    checkpoint = args.checkpoint
    if checkpoint is None:
        found = E.default_checkpoints(args.run_dir, 0)
        checkpoint = found[-1] if found else None
    if checkpoint is None or not checkpoint.exists():
        raise SystemExit("No checkpoint to start from. Pass --checkpoint.")
    state = E.read_checkpoint(checkpoint)
    if state is None or state.get("schema_hash") != schema.hash_hex:
        raise SystemExit(f"{checkpoint.name} was not made for this schema. Convert it first.")
    probe = args.run_dir.parent / "probes" / time.strftime("%Y%m%d-%H%M%S")
    (probe / "checkpoints").mkdir(parents=True)
    shutil.copy2(checkpoint, probe / "checkpoints" / checkpoint.name)
    sidecar = checkpoint.with_name(checkpoint.name + ".sha256")
    if sidecar.exists():
        shutil.copy2(sidecar, probe / "checkpoints" / sidecar.name)
    S.atomic_write_json(probe / "episode_overrides.json", {"probe_symbol": args.symbol, "probe_reward": args.reward})
    print(f"Probe in {probe}: symbol {args.symbol} on channel A earns {args.reward}, from {checkpoint.name}.")
    workers = ["-Workers", str(args.workers)] if args.workers > 0 else []
    if powershell("start_training.ps1", "-RunDir", str(probe), *workers) != 0:
        raise SystemExit("The probe's training did not start.")
    metrics = probe / "logs" / "metrics.jsonl"
    began = time.monotonic()
    shares: list[tuple[int, float]] = []
    reached: dict[str, int | None] = {"half": None, "target": None}
    try:
        while time.monotonic() - began < args.minutes * 60.0:
            time.sleep(POLL_SECONDS)
            rows = read_metrics(metrics)
            shares = [(i + 1, float(r["message_a_choices"][args.symbol])) for i, r in enumerate(rows) if r.get("message_a_choices")]
            if not shares:
                continue
            update, share = shares[-1]
            for name, level in (("half", 0.5), ("target", args.target)):
                if reached[name] is None and share >= level:
                    reached[name] = update
            print(f"  update {update}: symbol {args.symbol} chosen {share:.1%} of the time")
            if reached["target"] is not None:
                break
    except KeyboardInterrupt:
        print("Stopping the probe early.")
    finally:
        powershell("stop_training.ps1", "-RunDir", str(probe))
    result = {"checkpoint": str(checkpoint), "symbol": args.symbol, "reward": args.reward, "target": args.target,
              "updates": len(shares), "start_share": shares[0][1] if shares else None, "end_share": shares[-1][1] if shares else None,
              "updates_to_half": reached["half"], "updates_to_target": reached["target"],
              "minutes": round((time.monotonic() - began) / 60.0, 1), "shares": shares}
    S.atomic_write_json(probe / "result.json", result)
    print(json.dumps({k: v for k, v in result.items() if k != "shares"}, indent=1))
    print(f"Saved {probe / 'result.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
