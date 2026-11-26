"""Run a visible, repeatable developer rendering workload in new disposable storage."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--cases", default="garden,combat,world")
    parser.add_argument("--size", default="1100x720", choices=["1100x720", "1920x1080", "2560x1440"])
    parser.add_argument("--seconds", type=int, default=8, choices=range(3, 121), metavar="3..120")
    parser.add_argument("--stalls", action="store_true", help="Trace main-loop and draw phases for frames above 50 ms")
    parser.add_argument("--capture", action="store_true", help="Record frames at 8 Hz during timed samples")
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    token = uuid.uuid4().hex
    storage = project / ".godot" / "vfx08" / token
    storage.mkdir(parents=True, exist_ok=False)
    (storage / "fixture.marker").write_text(token, encoding="ascii")
    env = os.environ.copy()
    for key in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        env[key] = str(storage)
    env.update(VFX08_ROOT=str(storage), VFX08_CASES=args.cases, VFX08_SECONDS=str(args.seconds),
               VFX08_CAPTURE=str(int(args.capture)), VFX08_STALLS=str(int(args.stalls)))
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=project, text=True).strip()
    command = [str(args.engine.resolve()), "--path", str(project), "--rendering-method", "gl_compatibility",
               "--resolution", args.size, "--log-file", str(storage / "engine.log"), "--script",
               "res://tools/render_benchmark.gd"]
    print(storage, flush=True)
    with (storage / "console.log").open("w", encoding="utf-8") as log:
        result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, cwd=project,
                                timeout=2400)
    lines = (storage / "console.log").read_text(encoding="utf-8", errors="replace").splitlines()
    samples = [json.loads(line[6:]) for line in lines if line.startswith("BENCH ")]
    (storage / "results.json").write_text(json.dumps({"commit": commit, "resolution": args.size,
        "seconds": args.seconds, "capture": args.capture, "cases": args.cases, "samples": samples}, indent=2))
    errors = [line for line in lines if "ERROR:" in line or line.startswith("REJECT")]
    for line in errors[:8]:
        print(line)
    return int(bool(result.returncode or errors or not samples or samples[-1].get("kind") != "complete"))


if __name__ == "__main__":
    raise SystemExit(main())
