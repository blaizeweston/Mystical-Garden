"""Run a visible, repeatable developer rendering workload in new disposable storage."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--cases", default="garden,combat,world")
    parser.add_argument("--size", default="1100x720", choices=["1100x720", "1920x1080", "2560x1440"])
    parser.add_argument("--seconds", type=int, default=8, choices=range(3, 121), metavar="3..120")
    parser.add_argument("--stalls", action="store_true", help="Trace main-loop and draw phases for frames above 50 ms")
    parser.add_argument("--capture", action="store_true", help="Record frames at 8 Hz during timed samples")
    parser.add_argument("--quality", choices=["Low","Medium","High","Ultra","Custom"])
    parser.add_argument("--network", choices=["wild_flora_party","ce04_spirit_coop","ce03_water_coop","ce03_water_party","ce03_wood_coop","ce03_vital_coop","cr04c_mixed_party"])
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    token = uuid.uuid4().hex
    storage = project / ".godot" / "vfx08" / token
    storage.mkdir(parents=True, exist_ok=False)
    (storage / "fixture.marker").write_text(token, encoding="ascii")
    print(storage, flush=True)
    if args.network:
        from validation_execution import run_fixture
        kind = "party" if args.network.endswith("_party") else "pair"
        verdict = run_fixture(project, args.engine.resolve(), args.network, kind,
                              project / "tools/render_network_case.gd", storage / "network",
                              "vfx08-" + token[:12], rendered=True)
        for peer, outcome in verdict["peers"].items():
            for issue in outcome["issues"]:
                print(peer, issue)
        return int(not verdict["passed"])
    env = os.environ.copy()
    profile = storage
    if args.quality:
        # Long Windows profiles can fail to reopen the GL shader cache on a second launch.
        profile = Path(tempfile.mkdtemp(prefix="mg-v8-" + token[:8] + "-"))
        (profile / "fixture.marker").write_text(token, encoding="ascii")
    env["VFX08_PROFILE"] = str(profile)
    for key in ("APPDATA", "LOCALAPPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        env[key] = str(profile)
    env.update(VFX08_ROOT=str(storage), VFX08_CASES=args.cases, VFX08_SECONDS=str(args.seconds),
               VFX08_CAPTURE=str(int(args.capture)), VFX08_STALLS=str(int(args.stalls)))
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=project, text=True).strip()
    command = [str(args.engine.resolve()), "--path", str(project), "--rendering-method", "gl_compatibility",
               "--resolution", args.size, "--log-file", str(storage / "engine.log"), "--script",
               "res://tools/render_benchmark.gd"]
    env["VFX08_QUALITY"] = args.quality or ""
    with (storage / "console.log").open("w", encoding="utf-8") as log:
        result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, cwd=project,
                                timeout=2400)
    lines = (storage / "console.log").read_text(encoding="utf-8", errors="replace").splitlines()
    samples = [json.loads(line[6:]) for line in lines if line.startswith("BENCH ")]
    if args.quality and result.returncode == 0:
        env["VFX08_VERIFY_PREF"] = "1"
        restart = command.copy()
        restart[restart.index("--log-file") + 1] = str(storage / "restart.log")
        check = subprocess.run(restart, env=env, cwd=project, capture_output=True, text=True, timeout=90)
        if check.returncode or "PREFERENCE_RELOADED " + args.quality not in check.stdout or "ERROR:" in (check.stdout + check.stderr):
            print("Preference restart check failed", check.stdout[-1500:], check.stderr[-700:])
            return 1
    errors = [line for line in lines if "ERROR:" in line or line.startswith("REJECT")]
    for line in errors[:8]:
        print(line)
    (storage / "results.json").write_text(json.dumps({"commit": commit, "resolution": args.size,
        "seconds": args.seconds, "capture": args.capture, "cases": args.cases, "quality": args.quality,
        "restart_checked": bool(args.quality), "samples": samples}, indent=2))
    return int(bool(result.returncode or errors or not samples or samples[-1].get("kind") != "complete"))


if __name__ == "__main__":
    raise SystemExit(main())
