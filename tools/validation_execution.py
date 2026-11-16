"""Launch and verify a Godot fixture. Test logic owns completion; the runner owns the verdict."""
from __future__ import annotations

import argparse
from collections import Counter
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid


SCHEMA = 1
IDENTIFIER = re.compile(r"[A-Za-z0-9_-]{1,80}\Z")
PASS = re.compile(r"PASS:|Catalog validation errors: 0")
FAIL = re.compile(r"SCRIPT ERROR|Parse Error|\bFAIL(?::| )")
ENGINE_ERROR = re.compile(r"^\s*(?:USER )?ERROR:\s*(.*)$", re.MULTILINE)
# Match literals and comments first. Diagnostic fixtures can contain child script source.
GDSCRIPT = re.compile(r'''(?P<literal>"""(?:\\.|(?!""").)*"""|\'\'\'(?:\\.|(?!\'\'\').)*\'\'\'|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|#[^\n]*)|(?P<quit>(?<![\w.])quit)(?=\s*\()''', re.DOTALL)
PEERS = {"unit": ("unit",), "solo": ("solo",), "pair": ("host", "guest"),
         "party": ("host", "1", "2", "3", "overflow")}
WINDOWS_NETWORK_MUTEX = r"Global\MysticalGarden.Validation.UDP.v1"
LOCK_LIBRARY = "b0_native_lock.dll"
LOCK_RESOURCE = Path("assets/native/persistence_lock") / LOCK_LIBRARY


def stage_packaged_lock(project, pack, runtime):
    """Expose the exported companion at its res:// path for editor --main-pack."""
    source = project / LOCK_RESOURCE
    if not source.is_file():
        return
    companion = pack.with_name(LOCK_LIBRARY)
    if not companion.is_file() or companion.read_bytes() != source.read_bytes():
        raise ValueError(f"Missing or mismatched packaged persistence lock: {companion}")
    destination = runtime / LOCK_RESOURCE
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(companion, destination)


def read_json(path):
    try:
        value = Path(path).read_text(encoding="utf-8-sig")
        return json.loads(value)
    except (OSError, ValueError):
        return None


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def instrument(source):
    """Write a result only when the fixture explicitly reaches its quit call."""
    count = 0

    def wrap(match):
        nonlocal count
        if match.group("quit"):
            count += 1
            return "_validation_finish"
        return match.group()

    source = source.replace("\r\n", "\n")
    driver = GDSCRIPT.sub(wrap, source)
    if not count:
        raise ValueError("fixture has no explicit quit call")
    first_indent = re.search(r"(?m)^([ \t]+)\S", source)
    indent = "\t" if first_indent and first_indent[1].startswith("\t") else " "
    helper = r'''
func _validation_finish(code: int = 0) -> void:
	var path := OS.get_environment("MYSTICAL_VALIDATION_RESULT")
	if path.is_empty() or FileAccess.file_exists(path):
		printerr("FAIL: missing result path or duplicate fixture completion")
		quit(1)
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("FAIL: could not write fixture result")
		quit(1)
		return
	file.store_string(JSON.stringify({
		"schema": 1,
		"run_id": OS.get_environment("MYSTICAL_VALIDATION_RUN"),
		"fixture": OS.get_environment("MYSTICAL_VALIDATION_FIXTURE"),
		"peer": OS.get_environment("MYSTICAL_VALIDATION_PEER"),
		"status": "PASS" if code == 0 else "FAIL",
		"exit": code,
		"expected_engine_errors": get_meta(&"validation_expected_engine_errors", []),
	}))
	file.close()
	quit(code)
'''
    return driver.rstrip() + "\n\n" + helper.replace("\t", indent)


def peer_issues(log, result, run_id, fixture, peer, exit_code, stderr=""):
    issues = []
    if type(exit_code) is not int or exit_code != 0:
        issues.append(f"process exit {exit_code!r}")
    expected = []
    if not isinstance(result, dict):
        issues.append("missing or invalid structured result")
    else:
        identity = (result.get("run_id"), result.get("fixture"), result.get("peer"))
        if identity != (run_id, fixture, peer):
            issues.append("stale or mismatched run, fixture, or peer")
        if (type(result.get("schema")) is not int or result["schema"] != SCHEMA
                or result.get("status") != "PASS"
                or type(result.get("exit")) is not int or result["exit"] != 0):
            issues.append("failed or incomplete completion result")
        declarations = result.get("expected_engine_errors")
        if (not isinstance(declarations, list)
                or not all(isinstance(message, str) and message and "\n" not in message
                           and "\r" not in message for message in declarations)):
            issues.append("missing or invalid expected-error declarations")
        elif identity == (run_id, fixture, peer):
            expected = declarations
    if not PASS.search(log):
        issues.append("missing fixture pass marker")
    if FAIL.search(log) or FAIL.search(stderr):
        issues.append("script, parse, or fixture assertion error")
    observed = Counter(message.strip() for message in ENGINE_ERROR.findall(log + "\n" + stderr))
    required = Counter(expected)
    for message, count in (observed - required).items():
        issues.append(f"unexpected engine error ({count}): {message}")
    for message, count in (required - observed).items():
        issues.append(f"expected engine error missing ({count}): {message}")
    return issues


def terminate(process):
    if process.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        process.kill()
    process.wait()


@contextmanager
def network_fixture_lock(timeout_ms=180_000):
    """Serialize cooperating Windows validation listeners across checkouts."""
    if os.name != "nt":
        yield
        return
    import ctypes
    from ctypes import wintypes

    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateMutexW.argtypes = [wintypes.LPVOID, wintypes.BOOL, wintypes.LPCWSTR]
    kernel.CreateMutexW.restype = wintypes.HANDLE
    kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel.WaitForSingleObject.restype = wintypes.DWORD
    for name in ("ReleaseMutex", "CloseHandle"):
        function = getattr(kernel, name)
        function.argtypes = [wintypes.HANDLE]
        function.restype = wintypes.BOOL

    mutex = kernel.CreateMutexW(None, False, WINDOWS_NETWORK_MUTEX)
    if not mutex:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        result = kernel.WaitForSingleObject(mutex, timeout_ms)
        if result == 258:
            raise ValueError("Timed out waiting for the local validation network lock.")
        # An abandoned mutex transfers ownership to this thread. Any surviving
        # orphan that still owns the actual UDP port must fail the normal bind.
        if result not in (0, 128):
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            yield
        finally:
            if not kernel.ReleaseMutex(mutex):
                raise ctypes.WinError(ctypes.get_last_error())
    finally:
        kernel.CloseHandle(mutex)


def fixture_environment(project, experimental_terrain=False):
    # Keep fixture save paths within Godot's Windows path limit.
    profile = "mg-terrain-" + uuid.uuid4().hex if experimental_terrain else uuid.uuid4().hex[:12]
    data = project / ".godot/vd" / profile
    data.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    env.update(APPDATA=str(data), LOCALAPPDATA=str(data / "local"), XDG_DATA_HOME=str(data))
    Path(env["LOCALAPPDATA"]).mkdir()
    user_directory = env.get("MYSTICAL_VALIDATION_DATA_DIR", "Mystical Garden Prototype")
    if not re.fullmatch(r"Mystical Garden (?:Prototype|Playtest [0-9.]+-playtest\.[0-9]+)", user_directory):
        raise ValueError("unsupported validation user-data directory")
    (data / user_directory / "release-fixtures").mkdir(parents=True)
    if experimental_terrain:
        env["MYSTICAL_TERRAIN_PROFILE"] = str(data)
        (data / "terrain-session.marker").write_text(profile, encoding="utf-8")
    return env


def run_fixture(project, engine, fixture, kind, script, folder, run_id, pack=None, port=None):
    if not IDENTIFIER.fullmatch(run_id) or not IDENTIFIER.fullmatch(fixture):
        raise ValueError("invalid fixture name or run ID")
    folder = folder.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    affinity_fixtures = ("cr02_mode_coop", "cr02_mode_mismatch", "cr02_definitions_mismatch", "cr03_frost_coop", "cr03_frost_party", "cr04a_fire_coop", "cr04a_water_coop", "cr04a_vital_coop", "cr04a_mixed_party", "cr04b_thorn_coop", "cr04b_wood_coop", "cr04b_mixed_party", "cr04c_storm_coop", "cr04c_spirit_coop", "cr04c_void_coop", "cr04c_mixed_party", "cr05_native_grafts", "cr05_native_grafts_coop", "cr05_native_grafts_party", "ct01_warden", "ct01_warden_coop")
    terrain_coop = fixture == "experimental_terrain_coop" or fixture in affinity_fixtures
    env = None if terrain_coop else fixture_environment(project)
    default_port = 32295 if kind == "party" else 32291 if pack else 32283
    terrain_signals = folder / "signals"
    if terrain_coop:
        terrain_signals.mkdir()
    driver = folder / "fixture.gd"
    script_bytes = script.read_bytes()
    source = script_bytes.decode("utf-8-sig")
    if pack:
        source = source.replace("res://.godot/", "user://release-fixtures/")
    driver.write_text(instrument(source), encoding="utf-8", newline="\n")
    runtime = folder if pack else project
    if pack:
        stage_packaged_lock(project, pack, runtime)
    if kind == "party":
        frames = "9000"
    elif fixture == "package_startup":
        frames = "600"
    elif pack and kind == "unit":
        frames = "3600"
    else:
        frames = "4800"
    arguments = [str(engine), "--headless", "--path", str(runtime), "--script", str(driver),
                 "--max-fps", "60" if kind == "party" else "120", "--quit-after", frames]
    if pack:
        arguments.extend(["--main-pack", str(pack)])
    processes = {}
    outcomes = {}
    profile_roots = {}
    timed_out = set()
    # Some unit/solo fixtures also bind the default port or a derived offset.
    with network_fixture_lock():
        started = time.monotonic()
        try:
            for peer in PEERS[kind]:
                user_args = [peer, run_id] if kind in ("pair", "party") else ["solo"] if kind == "solo" else []
                base_env = fixture_environment(project, experimental_terrain=True) if terrain_coop else env
                child_env = dict(base_env, MYSTICAL_VALIDATION_PEER=peer,
                                 MYSTICAL_VALIDATION_RESULT=str(folder / f"{peer}.json"),
                                 MYSTICAL_VALIDATION_RUN=run_id, MYSTICAL_VALIDATION_FIXTURE=fixture,
                                 MYSTICAL_VALIDATION_PACK=str(pack) if pack else "",
                                 MYSTICAL_GARDEN_TEST_PORT=str(port or default_port))
                if terrain_coop:
                    child_env["MYSTICAL_TERRAIN_TEST_SIGNALS"] = str(terrain_signals)
                    user_args.append("--experimental-terrain")
                    if fixture in affinity_fixtures and not (fixture == "cr02_mode_mismatch" and peer == "guest"):
                        user_args.append("--combat-affinities")
                profile_roots[peer] = child_env["APPDATA"]
                with (folder / f"{peer}.log").open("wb") as log, (folder / f"{peer}.stderr.log").open("wb") as stderr:
                    processes[peer] = subprocess.Popen(
                        arguments + (["--"] + user_args if user_args else []),
                        cwd=runtime, env=child_env, stdout=log, stderr=stderr,
                        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
                if kind == "party":
                    time.sleep(.4)
                elif kind == "pair" and peer == "host":
                    time.sleep(.7)
            deadline = started + 150
            for peer, process in processes.items():
                try:
                    process.wait(timeout=max(0, deadline - time.monotonic()))
                except subprocess.TimeoutExpired:
                    timed_out.add(peer)
                    terminate(process)
        finally:
            for process in processes.values():
                terminate(process)
    for peer, process in processes.items():
        code = process.returncode
        log = (folder / f"{peer}.log").read_text(encoding="utf-8-sig", errors="replace")
        stderr = (folder / f"{peer}.stderr.log").read_text(encoding="utf-8-sig", errors="replace")
        issues = peer_issues(log, read_json(folder / f"{peer}.json"), run_id, fixture, peer, code, stderr)
        if peer in timed_out:
            issues.append("process timed out")
        outcomes[peer] = {"exit": code, "issues": issues}
    passed = all(not row["issues"] for row in outcomes.values())
    verdict = {"schema": SCHEMA, "run_id": run_id, "fixture": fixture, "kind": kind,
               "pack": str(pack) if pack else None, "passed": passed, "peers": outcomes,
               "script": str(script.resolve()), "script_sha256": hashlib.sha256(script_bytes).hexdigest(),
               "appdata": env["APPDATA"] if env else None, "port": port or default_port,
               "seconds": round(time.monotonic() - started, 3)}
    if terrain_coop:
        verdict["peer_appdata"] = profile_roots
    write_json(folder / "verdict.json", verdict)
    return verdict


def verify_fixture_run(folder, run_id, fixture, kind, script, pack=None):
    verdict = read_json(folder / "verdict.json")
    if (not isinstance(verdict, dict) or verdict.get("schema") != SCHEMA
            or verdict.get("run_id") != run_id or verdict.get("fixture") != fixture
            or verdict.get("kind") != kind or verdict.get("pack") != (str(pack) if pack else None)
            or verdict.get("script") != str(script.resolve())
            or verdict.get("script_sha256") != hashlib.sha256(script.read_bytes()).hexdigest()
            or verdict.get("passed") is not True or not isinstance(verdict.get("peers"), dict)
            or set(verdict["peers"]) != set(PEERS[kind])):
        raise ValueError(f"missing, stale, or failed execution verdict: {fixture} ({run_id})")
    files = [folder / "verdict.json"]
    for peer in PEERS[kind]:
        result_path, log_path = folder / f"{peer}.json", folder / f"{peer}.log"
        error_path = folder / f"{peer}.stderr.log"
        outcome = verdict["peers"][peer]
        if (not log_path.is_file() or not error_path.is_file()
                or not isinstance(outcome, dict) or outcome.get("issues") != []):
            raise ValueError(f"incomplete peer verdict: {fixture}/{peer}")
        issues = peer_issues(log_path.read_text(encoding="utf-8-sig", errors="replace"),
                             read_json(result_path), run_id, fixture, peer, outcome.get("exit"),
                             error_path.read_text(encoding="utf-8-sig", errors="replace"))
        if issues:
            raise ValueError(f"invalid peer verdict {fixture}/{peer}: {'; '.join(issues)}")
        files.extend([result_path, log_path, error_path])
    return files


def verify_smoke_run(folder, run_id, pack=None):
    """Check the existing network smoke's native per-peer results and logs."""
    summaries = list(folder.glob("*/summary.json"))
    if len(summaries) != 1:
        raise ValueError(f"missing or ambiguous network smoke summary ({run_id})")
    summary = read_json(summaries[0])
    if (not isinstance(summary, dict) or summary.get("schema") != 3
            or summary.get("run_id") != run_id or summary.get("fixture") != "supplied_network_smoke"
            or summary.get("role") != "All" or summary.get("clients") != 3
            or summary.get("passed") is not True or summary.get("pack") != (str(pack) if pack else "")
            or not isinstance(summary.get("peers"), list) or len(summary["peers"]) != 4):
        raise ValueError(f"missing, stale, or failed network smoke result ({run_id})")
    files = [summaries[0]]
    for role, index in (("host", 0), ("guest", 0), ("guest", 1), ("guest", 2)):
        name = f"{role}-{index}"
        rows = [row for row in summary["peers"] if isinstance(row, dict) and row.get("name") == name]
        result_file = summaries[0].parent / f"result_{role}_{index}.json"
        result = read_json(result_file)
        if (len(rows) != 1 or rows[0].get("passed") is not True or rows[0].get("exit") != 0
                or not isinstance(result, dict) or result.get("schema") != 3
                or result.get("run_id") != run_id or result.get("fixture") != "supplied_network_smoke"
                or result.get("role") != role or result.get("index") != index
                or result.get("status") != "PASS" or result.get("exit") != 0
                or not isinstance(result.get("metrics"), dict) or not result["metrics"].get("peer")):
            raise ValueError(f"incomplete network smoke peer result: {name} ({run_id})")
        files.append(result_file)
        for stream in ("stdout", "stderr", "engine"):
            path = summaries[0].parent / f"{name}.{stream}.log"
            if not path.is_file():
                raise ValueError(f"missing network smoke {stream} log for {name}")
            log = path.read_text(encoding="utf-8-sig", errors="replace")
            if ENGINE_ERROR.search(log) or FAIL.search(log) or (stream == "stdout" and "RESULT PASS" not in log):
                raise ValueError(f"invalid network smoke {stream} log for {name}")
            files.append(path)
    return files


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--fixture", required=True)
    parser.add_argument("--kind", choices=PEERS, required=True)
    parser.add_argument("--script", type=Path)
    parser.add_argument("--pack", type=Path)
    parser.add_argument("--log-root", type=Path)
    parser.add_argument("--run-id", default=None)
    parser.add_argument("--port", type=int)
    args = parser.parse_args()
    project = args.project.resolve()
    run_id = args.run_id or uuid.uuid4().hex
    if not IDENTIFIER.fullmatch(args.fixture) or not IDENTIFIER.fullmatch(run_id):
        parser.error("invalid fixture name or run ID")
    script = args.script or project / "tests" / f"{args.fixture}.gd"
    log_root = args.log_root or project / ".godot/validation/executions" / run_id
    folder = log_root / args.fixture
    try:
        verdict = run_fixture(project, args.engine.resolve(), args.fixture, args.kind, script.resolve(),
                              folder, run_id, args.pack.resolve() if args.pack else None, args.port)
    except (OSError, ValueError) as error:
        print(f"FAIL: {args.fixture} {run_id}: {error}", file=sys.stderr)
        return 1
    print(f"{'PASS' if verdict['passed'] else 'FAIL'}: {args.fixture} {run_id} ({folder.resolve()})")
    for peer, outcome in verdict["peers"].items():
        print(f"  {peer} exit={outcome['exit']}: {'; '.join(outcome['issues']) or 'PASS'}")
    return 0 if verdict["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())

