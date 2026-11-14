"""Archive a playtest using the existing Connected and VerifyOnly workflows."""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from types import SimpleNamespace
import uuid
import zipfile

import validation_execution as evidence

VERSION = re.compile(r"(0|[1-9][0-9]{0,5})\.(0|[1-9][0-9]{0,5})\.(0|[1-9][0-9]{0,5})(?:-playtest\.([1-9][0-9]{0,5}))?")
REPO = Path(__file__).resolve().parent.parent
LOCK_DESCRIPTOR = evidence.LOCK_RESOURCE.with_name("persistence_lock.gdextension")
GAME = "Mystical Garden.exe"
DEFAULT_ARCHIVE = Path.home() / "Documents" / "MG-Playtests"


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def git(*args, repo=REPO):
    # Use the selected checkout, even when called from another Git command.
    redirect = {"GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY",
                "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_CONFIG", "GIT_CONFIG_COUNT"}
    env = {key: value for key, value in os.environ.items() if key.upper() not in redirect}
    return subprocess.check_output(["git", "--no-optional-locks", *args], cwd=repo, env=env)


def version_name(value):
    match = VERSION.fullmatch(value)
    if not match:
        raise ValueError("Use a version such as 0.1.0 or 0.1.0-playtest.2.")
    return ".".join(match.groups()[:3]) + "-playtest." + (match[4] or "1")


def source_revision(allow_editor_copy=False):
    status = git("-c", "core.fsmonitor=false", "status", "--porcelain=v1", "-z", "--untracked-files=all")
    if allow_editor_copy and status == b"?? assets/native/persistence_lock/~b0_native_lock.dll\0":
        duplicate = REPO / evidence.LOCK_RESOURCE.with_name("~" + evidence.LOCK_LIBRARY)
        if (not duplicate.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT
                and sha(duplicate) == sha(REPO / evidence.LOCK_RESOURCE)):
            status = b""
    if status:
        raise ValueError("Commit the source changes and use a clean checkout before building.")
    for entry in git("ls-files", "-v", "-z").split(b"\0"):
        if entry and not entry.startswith(b"H "):
            raise ValueError("The Git index has hidden, sparse, or unresolved entries.")
    if any(entry and not entry.startswith((b"100644 ", b"100755 "))
           for entry in git("ls-files", "--stage", "-z").split(b"\0")):
        raise ValueError("Playtest builds require ordinary tracked files, without symlinks or submodules.")
    return git("rev-parse", "HEAD").decode().strip()


def validate_archive(path):
    for part in (path, *path.parents):
        if part.exists() or part.is_symlink():
            info = part.lstat()
            if info.st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT or not part.is_dir():
                raise ValueError("Use an ordinary local archive directory without links or junctions.")
    # Windows returns 3 for fixed drives. The native startup probe checks NTFS.
    import ctypes
    if ctypes.windll.kernel32.GetDriveTypeW(str(path.anchor)) != 3:
        raise ValueError("Use a fixed local drive for the playtest archive.")


def archive_path(override):
    archive = Path(os.path.abspath(override or DEFAULT_ARCHIVE))
    validate_archive(archive)
    if (archive == REPO or REPO in archive.parents and archive != REPO / "playtest-releases"
            or archive.name in (".git", ".godot")):
        raise ValueError("Use a directory outside the source tree, or its ignored playtest-releases folder.")
    protected = [Path.home() / "AppData" / name for name in ("Roaming", "Local", "LocalLow")]
    protected.extend(Path(os.environ[name]) for name in ("APPDATA", "LOCALAPPDATA") if os.environ.get(name))
    if any(archive == path or path in archive.parents for path in protected):
        raise ValueError("The release archive must be outside Windows application data directories.")
    if len(str(archive)) > 60:
        raise ValueError("Use a shorter archive path so the Windows fixtures fit within MAX_PATH.")
    return archive


ROOT_KEYS = {"workspace": "WorkspaceRoot", "stage": "StageRoot",
             "evidence": "EvidenceRoot", "archive": "ArchiveRoot", "engine": "Engine"}


def output_path(value):
    path = Path(value)
    if (not path.is_absolute() or not path.parts[1:] or not re.fullmatch(r"[A-Za-z]:", path.drive)
            or any(part in (".", "..") or part.endswith((".", " ")) or re.search(r'[<>:"|?*~\x00-\x1f]', part)
                   for part in path.parts[1:])):
        raise ValueError("Use an ordinary absolute Windows output path.")
    validate_archive(path)
    return path


def output_options(args):
    values = {}
    if args.config:
        config = Path(args.config)
        if not config.is_absolute() or config.is_relative_to(REPO) or config.is_symlink():
            raise ValueError("Select a local workspace configuration outside the repository.")
        validate_archive(config.parent)
        if not config.is_file() or config.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:
            raise ValueError("Workspace configuration is redirected.")
        values = json.loads(config.read_text(encoding="utf-8-sig"))
        if (not isinstance(values, dict) or values.keys() - set(ROOT_KEYS.values())
                or any(not isinstance(value, str) or not value.strip() for value in values.values())):
            raise ValueError("Invalid workspace configuration keys or values.")
    paths = {name: getattr(args, name) or values.get(key) for name, key in ROOT_KEYS.items()}
    configured = bool(args.config or any(paths[name] for name in ("workspace", "stage", "evidence")))
    if paths["archive"]:
        output_path(paths["archive"])
    paths["archive"] = archive_path(paths["archive"] or (REPO.parent / "Releases" if configured else None))
    if not configured:
        return SimpleNamespace(**paths, configured=False)
    parent = REPO.parent
    for name, leaf in (("workspace", "w"), ("stage", "r"), ("evidence", "Evidence")):
        paths[name] = output_path(paths[name] or parent / leaf)
    roots = [paths[n] for n in ("workspace", "stage", "evidence", "archive")]
    protected = [REPO, parent / "Backups", parent / "Mystical Garden Battlefield Trials",
                 parent / "Playtest Shortcuts", parent / "Tools", parent / "Reports",
                 Path.home() / "AppData"]
    protected += [Path(os.environ[n]) for n in ("APPDATA", "LOCALAPPDATA") if os.environ.get(n)]
    for root in roots:
        if any(root.is_relative_to(x) or x.is_relative_to(root)
               for x in protected + [x for x in roots if x != root]) or roots.count(root) != 1:
            raise ValueError("Output roots must be distinct and separate from source, saves and protected directories.")
        if root.drive.lower() != paths["archive"].drive.lower():
            raise ValueError("Configured outputs must be on the archive volume.")
        validate_archive(root)
    import ctypes
    filesystem = ctypes.create_unicode_buffer(32)
    if not ctypes.windll.kernel32.GetVolumeInformationW(
            roots[0].anchor, None, 0, None, None, None, filesystem, len(filesystem)) or filesystem.value != "NTFS":
        raise ValueError("Configured development outputs require a fixed local NTFS volume.")
    return SimpleNamespace(**paths, configured=True)


def shader_suffix(version):
    return (Path("AppData/Roaming") / ("Mystical Garden Playtest " + version)
            / "shader_cache" / ("s" * 32) / ("a" * 64) / ("b" * 40 + ".cache"))


def desktop_parent(parents, version):
    for parent in sorted(set(parents), key=lambda path: len(str(path))):
        validate_archive(parent)
        if len(str(parent / ("mg" + "0" * 6) / shader_suffix(version))) < 260:
            return parent
    raise ValueError("Use a shorter local archive or Windows TEMP path for desktop verification.")


def validate_build_paths(roots, work, stage, output, version):
    project = work / "p"
    user_dir = "Mystical Garden Playtest " + version
    # The packaged smoke fixture writes under its log root. Model its longest
    # diagnostic and recovery participant paths rather than only the base root.
    smoke = work / "n" / ("0" * 24) / "userdata" / user_dir
    profiles = (smoke / "diagnostics" / ("session-" + "0" * 35) / "events-000001.jsonl",
                project / ".godot/vd" / ("0" * 12) / user_dir / "release-fixtures"
                / "saves/characters/slot_000001/character.cfg.transaction.expected",
                stage / "retail/00/u/AppData/Roaming" / user_dir / "saves/slot_1/garden.cfg",
                stage / "export" / ("0" * 12) / GAME,
                project / ".godot/validation/package-runs" / ("0" * 32)
                / "guarded_gameplay_transactions/assets/native/persistence_lock/b0_native_lock.dll",
                output / "retail-logs/12/process.stderr.log",
                roots.archive / version / "game/licenses/persistence_lock.gdextension")
    if any(len(str(path)) >= 260 for path in profiles):
        raise ValueError("An output root produces a fixture, stage or archive path beyond the Windows path budget.")
    # Ensure local disks can accommodate imports, the staged package and evidence.
    if shutil.disk_usage(roots.archive.anchor).free < 2 * 1024**3:
        raise ValueError("At least 2 GiB of free workspace is required for validation and packaging.")


def remove_owned_tree(path, parent):
    validate_archive(path)
    if path.parent != parent:
        raise ValueError("Disposable directory ownership changed.")

    def readonly_file(operation, name, error):
        item = Path(name)
        info = item.lstat()
        if (operation != os.unlink or not isinstance(error, PermissionError)
                or not item.is_relative_to(path) or not stat.S_ISREG(info.st_mode)
                or info.st_nlink != 1
                or info.st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT
                or not info.st_file_attributes & stat.FILE_ATTRIBUTE_READONLY):
            raise error
        item.chmod(stat.S_IREAD | stat.S_IWRITE)
        operation(name)

    shutil.rmtree(path, onexc=readonly_file)


@contextmanager
def owned_profile(parent, record=None):
    # mkdir is exclusive. Keep the complete profile if the probe raises.
    profile = parent / ("mg" + uuid.uuid4().hex[:6])
    validate_archive(profile)
    if record:
        record(profile, "planned")
    profile.mkdir()
    try:
        if record:
            record(profile, "allocated")
        yield profile
    except BaseException:
        print(f"Retained failed desktop profile: {profile}", file=sys.stderr, flush=True)
        raise
    else:
        remove_owned_tree(profile, parent)
        if record:
            record(profile, "removed")


def run(command, cwd, env, log, timeout=None, check=True):
    with log.open("wb") as output, log.with_name(log.stem + ".stderr.log").open("wb") as errors:
        result = subprocess.run([str(value) for value in command], cwd=cwd, env=env,
                                stdout=output, stderr=errors, timeout=timeout, check=False,
                                creationflags=subprocess.CREATE_NO_WINDOW)
    if check and result.returncode:
        raise ValueError(f"Process exited {result.returncode}. See {log.name} and its stderr log.")
    return result.returncode


def tracked(project):
    return [Path(path.decode("utf-8")) for path in git("ls-files", "-z", repo=project).split(b"\0") if path]


def input_manifest(project, names):
    return "".join(f"{sha(project / name)}  {name.as_posix()}\n" for name in sorted(names))


def seed_cache(project, shared):
    cache = shared / "validation"
    validate_archive(cache)
    for name, packaged in (("cache.json", False), ("package-cache.json", True)):
        index = cache / name
        if not index.is_file():
            continue
        if index.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:
            raise ValueError("The reusable validation index is redirected.")
        content = evidence.read_json(index)
        rows = content["results"].values() if packaged else (item["logs"] for item in content.values())
        destination = project / ".godot/validation"
        for row in rows:
            for relative in row:
                path = Path(relative)
                if path.is_absolute() or ".." in path.parts:
                    raise ValueError("The reusable validation log escaped its root.")
                original = cache / path
                validate_archive(original.parent)
                if not original.is_file():
                    continue  # The strict planner will run the fixture again.
                if original.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:
                    raise ValueError("The reusable validation log is redirected.")
                copy = destination / path
                copy.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(original, copy)
        destination.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(index, destination / name)


def keep_cache(project, shared, output):
    validation = project / ".godot/validation"
    for name, results in (("cache.json", False), ("package-cache.json", True)):
        cache = evidence.read_json(validation / name)
        if not cache:
            raise ValueError("Incomplete release validation cache.")
        rows = cache["results"].values() if results else (item["logs"] for item in cache.values())
        for row in rows:
            for relative, digest in row.items():
                path = Path(relative)
                if path.is_absolute() or ".." in path.parts or sha(validation / path) != digest:
                    raise ValueError("Validation evidence was changed or escaped its root.")
                dest = shared / "validation" / path
                validate_archive(dest.parent)
                dest.parent.mkdir(parents=True, exist_ok=True)
                if os.path.lexists(dest) and dest.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:
                    raise ValueError("The reusable validation archive contains a redirected file.")
                if not dest.exists():
                    shutil.copyfile(validation / path, dest)
                elif sha(dest) != digest:
                    raise ValueError("A prior validation log already uses this identity.")
        latest = shared / "validation" / name
        scratch = latest.with_suffix("." + uuid.uuid4().hex + ".tmp")
        shutil.copyfile(validation / name, scratch)
        scratch.replace(latest)
        shutil.copyfile(validation / name, output / name)


def summarize(project, package, output):
    root = project / ".godot/validation"
    source = evidence.read_json(root / "latest-report.json")
    if not source or not all(source.get(k) is True for k in ("passed", "stable_inputs", "release_ready")):
        raise ValueError("Missing current connected validation evidence.")
    source_rows = evidence.read_json(root / "cache.json")
    package_rows = evidence.read_json(root / "package-cache.json")
    if not source_rows or not package_rows:
        raise ValueError("Missing connected or packaged fixture records.")
    if set(source_rows) != set(source["plan"]["selected"]) or set(package_rows["results"]) != set(package["plan"]["keys"]):
        raise ValueError("Incomplete source or packaged suite evidence.")
    registry = evidence.read_json(project / "tools/test_map.json")["suites"]

    def row(name, paths):
        verdict = next((root / path for path in paths if path.endswith("/verdict.json")), None)
        if verdict is None:
            summary = next(root / path for path in paths if path.endswith("/summary.json"))
            data = evidence.read_json(summary)
            return {"run_id": data["run_id"], "exits": {peer["name"]: peer["exit"] for peer in data["peers"]}}
        data = evidence.read_json(verdict)
        fixture = registry.get(name, {}).get("script", f"tests/{name}.gd")
        script = project / fixture
        if script.is_file() and sha(script) != data["script_sha256"]:
            raise ValueError(f"Stale fixture bytes for {name}.")
        return {"run_id": data["run_id"], "fixture_sha256": data["script_sha256"],
                "exits": {peer: value["exit"] for peer, value in data["peers"].items()}}

    result = {
        "source_run_id": source["run_id"], "package_run_id": package["plan"]["run_id"],
        "source": {name: row(name, value["logs"]) for name, value in source_rows.items()},
        "packaged": {name: row(name, paths) for name, paths in package_rows["results"].items()},
        "startup": [row(Path(path).parent.name, {path: value}) for path, value in package["startup_logs"].items()
                    if path.endswith("/verdict.json")],
    }
    for collection in (result["source"].values(), result["packaged"].values(), result["startup"]):
        if any(code != 0 for item in collection for code in item["exits"].values()):
            raise ValueError("Release evidence includes a nonzero process exit.")
    evidence.write_json(output / "validation-summary.json", result)
    return result


def retail_probes(stage, pack, metadata, env, profile_parent=None, record_profile=None):
    temp = Path(tempfile.gettempdir()).resolve(strict=True)
    candidates = (stage.parents[2], temp) if stage.parents[1].name == ".staging" else (temp,)
    parent = profile_parent or desktop_parent(candidates, metadata["playtest_version"])
    with owned_profile(parent, record_profile) as desktop_profile:
        return _retail_probes(stage, pack, metadata, env, desktop_profile)


def _retail_probes(stage, pack, metadata, env, desktop_profile):
    results = {}
    executable_hash = sha(pack)
    sandbox = stage / "retail"
    sandbox.mkdir()
    version = metadata["playtest_version"]
    ready = re.compile(rf"(?m)^PLAYTEST READY: {re.escape(version)} . protocol {metadata['protocol']} . legacy-contained$")
    backend = "PLAYTEST BLOCKED: The playtest persistence library is missing or incompatible."
    expected_errors = [
        'Condition "!FileAccess::exists(path)" is true. Returning: ERR_FILE_NOT_FOUND',
        "GDExtension dynamic library not found: 'res://assets/native/persistence_lock/persistence_lock.gdextension'.",
        "Error loading extension: 'res://assets/native/persistence_lock/persistence_lock.gdextension'.",
    ]

    for number, probe in enumerate(("normal", "missing", "incompatible", "external-driver", "override",
                                    "redirect", "junction", "linked-save", "incompatible-save", "newer-root",
                                    "desktop", "unmarked-save", "invalid-shader-cache")):
        home = sandbox / f"{number:02d}"
        home.mkdir()
        profile = desktop_profile if probe == "desktop" else home / "u"
        roaming = profile / "AppData/Roaming"
        local = profile / "AppData/Local"
        roaming.mkdir(parents=True)
        local.mkdir()
        release_root = roaming / metadata["save_root"]
        legacy = roaming / "Mystical Garden Prototype"
        legacy.mkdir()
        anchor = legacy / "garden.cfg"
        anchor.write_bytes(b"disposable prototype marker\n")
        baseline = sha(anchor)
        if probe == "incompatible-save":
            release_root.mkdir()
            (release_root / "playtest.identity").write_bytes(b"newer playtest identity\n")
        if probe == "unmarked-save":
            unmarked = release_root / "saves/slot_1/garden.cfg"
            unmarked.parent.mkdir(parents=True)
            unmarked.write_bytes(b"unmarked garden evidence\n")
        if probe == "invalid-shader-cache":
            unexpected = release_root / "shader_cache/garden.cfg"
            unexpected.parent.mkdir(parents=True)
            unexpected.write_bytes(b"unrecognized cache content\n")
        if probe == "linked-save":
            release_root.mkdir()
            (release_root / "settings.cfg").hardlink_to(anchor)
        if probe == "junction":
            subprocess.run(["cmd.exe", "/d", "/c", "mklink", "/J", str(release_root), str(legacy)],
                           check=True, capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW)
        child_env = dict(env, USERPROFILE=str(profile), APPDATA=str(roaming), LOCALAPPDATA=str(local))
        if probe == "redirect":
            child_env["APPDATA"] = str(home)
        exe = home / GAME
        newer = roaming / "Mystical Garden Playtest 999999.0.0-playtest.1"
        if probe == "newer-root":
            newer.mkdir()
            (newer / "garden.cfg").write_bytes(b"disposable newer-version marker\n")
        # The EXE is immutable; each case still has its own DLL and profile.
        exe.hardlink_to(pack)
        companion = home / evidence.LOCK_LIBRARY
        if probe != "missing":
            if probe == "incompatible":
                companion.write_bytes(b"Not a Windows DLL\n")
            else:
                shutil.copyfile(pack.with_name(evidence.LOCK_LIBRARY), companion)
        args = ["--headless", "--quit-after", "30", "--max-fps", "120"]
        if probe == "desktop":
            args = ["--position", "-32000,-32000", "--quit-after", "90", "--max-fps", "120"]
        if probe == "external-driver":
            (home / "external.gd").write_text('extends SceneTree\nfunc _initialize():\n print("EXTERNAL DRIVER RAN")\n quit(19)\n')
            args += ["--script", "external.gd"]
            child_env["MYSTICAL_VALIDATION_RUN"] = "external-driver"
        if probe == "override":
            (home / "override.cfg").write_text('[application]\nconfig/custom_user_dir_name="Mystical Garden Prototype"\nconfig/mystical_playtest=false\n')
        log = home / "process.log"
        code = run([exe, *args], home, child_env, log, timeout=30, check=False)
        stdout = log.read_text(encoding="utf-8-sig", errors="replace")
        stderr = (home / "process.stderr.log").read_text(encoding="utf-8-sig", errors="replace")
        errors = evidence.ENGINE_ERROR.findall(stdout + "\n" + stderr)
        allowed = expected_errors if probe == "missing" else [
            line for line in errors if line.startswith("Can't open dynamic library:")
            and "Error 193" in line
        ] if probe == "incompatible" else []
        if probe == "incompatible":
            allowed += ["Can't open GDExtension dynamic library: 'res://assets/native/persistence_lock/persistence_lock.gdextension'.",
                        "Error loading extension: 'res://assets/native/persistence_lock/persistence_lock.gdextension'."]
        if sorted(errors) != sorted(allowed) or (probe == "incompatible" and len(allowed) != 3) or evidence.FAIL.search(stdout + "\n" + stderr):
            raise ValueError(f"Unexpected retail engine output in {probe}: {errors}")
        success = probe in ("normal", "override", "external-driver", "newer-root", "desktop")
        blocked = {
            "missing": backend, "incompatible": backend,
            "redirect": "PLAYTEST BLOCKED: Use the default local Windows AppData folder for this playtest.",
            "junction": "PLAYTEST BLOCKED: The playtest save root is unsupported or redirected.",
            "linked-save": "PLAYTEST BLOCKED: The playtest save root is unsupported or currently busy.",
            "incompatible-save": "PLAYTEST BLOCKED: The playtest save set does not match this version.",
            "unmarked-save": "PLAYTEST BLOCKED: The playtest save set does not match this version.",
            "invalid-shader-cache": "PLAYTEST BLOCKED: The playtest save set does not match this version.",
        }
        if code != 0 or "EXTERNAL DRIVER RAN" in stdout or sha(anchor) != baseline:
            raise ValueError(f"Retail execution or protected root check failed in {probe}.")
        if success:
            if not ready.search(stdout) or not (release_root / "playtest.identity").is_file() or not (release_root / "diagnostics").is_dir():
                raise ValueError(f"Retail title, version or isolated save root missing in {probe}.")
        elif probe in blocked:
            if blocked[probe] not in stdout or "PLAYTEST READY:" in stdout or (release_root / "diagnostics").exists():
                raise ValueError(f"Retail did not refuse the {probe} probe before gameplay.")
        if probe == "unmarked-save":
            if (release_root / "playtest.identity").exists() or unmarked.read_bytes() != b"unmarked garden evidence\n":
                raise ValueError("Retail altered the unmarked save set.")
        if probe == "invalid-shader-cache":
            if (release_root / "playtest.identity").exists() or unexpected.read_bytes() != b"unrecognized cache content\n":
                raise ValueError("Retail altered unrecognized cache content.")
        if probe == "desktop" and not (release_root / "shader_cache").is_dir():
            raise ValueError("Desktop acceptance did not exercise renderer-created storage.")
        if probe in ("normal", "desktop"):
            identity = release_root / "playtest.identity"
            fingerprint = sha(identity)
            reopen = home / "reopen.log"
            reopen_exit = run([exe, *args], home, child_env, reopen, timeout=30, check=False)
            reopened = reopen.read_text(encoding="utf-8-sig", errors="replace")
            reopen_errors = (home / "reopen.stderr.log").read_text(encoding="utf-8-sig", errors="replace")
            if reopen_exit or not ready.search(reopened) or evidence.ENGINE_ERROR.search(reopened + reopen_errors) or fingerprint != sha(identity):
                raise ValueError("Retail could not reopen its exact version and commit.")
            reopen_id = "desktop-reopen" if probe == "desktop" else "reopen"
            results[reopen_id] = {"exit": reopen_exit, "run_id": f"{version}-{reopen_id}",
                                 "exe_sha256": sha(exe), "logs": home.name, "expected_errors": 0, "ready": True}
        if probe == "newer-root" and (sorted(x.name for x in newer.iterdir()) != ["garden.cfg"]
                                      or (newer / "garden.cfg").read_bytes() != b"disposable newer-version marker\n"):
            raise ValueError("An earlier playtest touched another version's save root.")
        if list(roaming.rglob("character.cfg")) or list(roaming.rglob("catalog.cfg")):
            raise ValueError(f"Unexpected canonical profile or catalog during retail probe {probe}.")
        results[probe] = {"exit": code, "run_id": f"{version}-{probe}", "exe_sha256": sha(exe), "logs": home.name,
                          "expected_errors": len(allowed), "ready": success}
    if sha(pack) != executable_hash or any(row["exe_sha256"] != executable_hash for row in results.values()):
        raise ValueError("The shared retail executable changed during probes.")
    return results


def bundle(stage, pack, project, metadata, checks, retail):
    payload = stage / "game"
    payload.mkdir()
    names = [GAME, evidence.LOCK_LIBRARY]
    pck = pack.with_suffix(".pck")
    if pck.is_file():
        names.append(pck.name)
    actual = {path.name for path in pack.parent.iterdir() if path.is_file()}
    if actual - {"export-project.godot"} != set(names):
        raise ValueError("The export has additional sidecars. Review their runtime role before bundling.")
    for name in names:
        shutil.copyfile(pack.parent / name, payload / name)
    extension = payload / "licenses"
    extension.mkdir()
    shutil.copyfile(project / LOCK_DESCRIPTOR, extension / LOCK_DESCRIPTOR.name)
    credits = project / "assets/source/ART_CREDITS.md"
    if credits.is_file():
        shutil.copyfile(credits, extension / credits.name)
    version = metadata["playtest_version"]
    readme = (project / "tools/README_PLAYTEST.txt").read_text(encoding="utf-8")
    (payload / "README_PLAYTEST.txt").write_text(readme.replace("@VERSION@", version).replace("@ROOT@", metadata["save_root"]), encoding="utf-8")
    info = {
        "version": version, "git_commit": metadata["git_commit"], "git_tag": None,
        "created_utc": metadata["built_utc"], "godot": metadata["godot_version"], "target": "Windows x86_64",
        "multiplayer_protocol": metadata["protocol"], "persistence": "legacy route with native containment",
        "save_root": "%APPDATA%/" + metadata["save_root"], "compatibility": "Exact version and commit only. No automatic import.",
        "source_run_id": checks["source_run_id"], "package_run_id": checks["package_run_id"],
        "exe_sha256": sha(payload / GAME), "native_dll_sha256": sha(payload / evidence.LOCK_LIBRARY),
        "input_manifest_sha256": metadata["input_manifest_sha256"],
        "distribution": "Awaiting manual acceptance and local release approval.",
        "pck": pck.name if pck.is_file() else "embedded", "extension_descriptor": "embedded; reference copy in licenses/",
    }
    (payload / "BUILD_INFO.txt").write_text("Mystical Garden playtest\n\n" + "\n".join(
        f"{key.replace('_', ' ').title()}: {value if value is not None else 'pending approval'}" for key, value in info.items()
    ) + "\n\nThe archive's SHA256SUMS.txt contains the ZIP checksum.\n", encoding="utf-8")
    members = [{"path": path.relative_to(payload).as_posix(), "size": path.stat().st_size, "sha256": sha(path)}
               for path in sorted(payload.rglob("*")) if path.is_file()]
    evidence.write_json(payload / "manifest.json", {"schema": 1, **info, "files": members,
                                                    "manifest_digest": "See external SHA256SUMS.txt."})
    zip_path = stage / f"Mystical-Garden-{version}-win64.zip"
    all_members = {row["path"]: (row["size"], row["sha256"]) for row in members}
    all_members["manifest.json"] = ((payload / "manifest.json").stat().st_size, sha(payload / "manifest.json"))
    with zipfile.ZipFile(zip_path, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=4) as archive:
        for name in all_members:
            archive.write(payload / name, name)
    with zipfile.ZipFile(zip_path) as archive:
        if archive.namelist() != list(all_members):
            raise ValueError("Unexpected ZIP contents.")
        for name, (size, digest) in all_members.items():
            with archive.open(name) as stream:
                if archive.getinfo(name).file_size != size or hashlib.file_digest(stream, "sha256").hexdigest() != digest:
                    raise ValueError(f"ZIP verification failed for {name}.")
    (stage / "SHA256SUMS.txt").write_text(f"{sha(zip_path)}  {zip_path.name}\n{all_members['manifest.json'][1]}  manifest.json\n", encoding="ascii")
    shutil.copyfile(payload / "manifest.json", stage / "manifest.json")
    evidence.write_json(stage / "evidence/retail-probes.json", retail)


def archive_candidates(version, preferred, historical):
    for root in dict.fromkeys(archive_path(root) for root in (preferred, *historical)):
        location = root / version
        if os.path.lexists(location):
            validate_archive(location)
            yield location


def refuse_duplicate(version, archive, historical):
    if git("tag", "--list", f"playtest/{version}"):
        raise ValueError(f"Release {version} already has a local tag.")
    existing = next(archive_candidates(version, archive, historical), None)
    if existing:
        raise ValueError(f"Release {version} already exists at {existing}.")


def build(args):
    if os.name != "nt" or sys.maxsize <= 2**32:
        raise ValueError("The playtest builder requires Windows x64.")
    version = version_name(args.version)
    roots = output_options(args)
    if git("rev-parse", "--show-toplevel").decode().strip().replace("\\", "/").casefold() != REPO.as_posix().casefold():
        raise ValueError("Unexpected Git project root.")
    revision = source_revision(roots.configured)
    if args.expected_revision and args.expected_revision != revision:
        raise ValueError("The clean checkout does not match the expected revision.")
    if not roots.engine:
        raise ValueError("Supply the Godot editor executable.")
    engine = Path(roots.engine).absolute()
    validate_archive(engine.parent)
    if engine.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT or not engine.is_file():
        raise ValueError("Use the verified local Godot editor executable.")
    version_info = subprocess.check_output([str(engine), "--version"], text=True).strip()
    if version_info != "4.7.2.stable.official.ed1daf0bf":
        raise ValueError("Godot and the native DLL require the verified 4.7.2 editor revision.")
    archive = roots.archive
    refuse_duplicate(version, archive, args.history)
    shell = shutil.which("pwsh")
    if not shell:
        raise ValueError("PowerShell 7 is required by release validation.")
    attempt = uuid.uuid4().hex[:8]
    stage = (roots.stage if roots.configured else archive / ".staging") / attempt
    work = roots.workspace / attempt if roots.configured else stage / "work"
    output = roots.evidence / "Playtest/Runs" / attempt if roots.configured else stage / "evidence"
    shared = roots.evidence / "Playtest/WorkingCache" / hashlib.sha256(str(archive).casefold().encode()).hexdigest()[:12] if roots.configured else archive / ".cache"
    for path in (stage, work, output, shared):
        validate_archive(path)
    temp = Path(tempfile.gettempdir()).resolve(strict=True)
    profile_parent = desktop_parent((roots.workspace, temp) if roots.configured else (archive, temp), version)
    if roots.configured:
        validate_build_paths(roots, work, stage, output, version)
    for required in (evidence.LOCK_RESOURCE, LOCK_DESCRIPTOR, Path("project.godot")):
        git("cat-file", "-e", f"{revision}:{required.as_posix()}")
        f = REPO / required
        validate_archive(f.parent)
        if not f.is_file() or f.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:
            raise ValueError(f"Missing or redirected build dependency: {required}")
    if args.plan:
        print(json.dumps({"commit": revision, "engine": str(engine), "version": version,
                          "workspace": str(work), "stage": str(stage), "evidence": str(output),
                          "archive": str(archive), "desktop_profile_parent": str(profile_parent)}, indent=2))
        return
    archive.mkdir(parents=True, exist_ok=True)
    shared.mkdir(parents=True, exist_ok=True)
    validate_archive(shared)
    lock = archive / ".build.lock" if roots.configured else shared / "build.lock"
    with lock.open("x", encoding="ascii") as handle:
        handle.write(str(os.getpid()))
    status = {"attempt": attempt, "version": version, "commit": revision, "engine": str(engine),
              "workspace": str(work), "stage": str(stage), "evidence": str(output), "archive": str(archive),
              "desktop_profile_parent": str(profile_parent), "state": "starting"}
    export_root = stage / "export" if roots.configured else work / "p/.godot/release"
    status["export_root"] = str(export_root)
    manifest_path = None
    try:
        refuse_duplicate(version, archive, args.history)
        stage.mkdir(parents=True)
        print(f"Building {version} at {revision}. Staging: {stage}", flush=True)
        work.mkdir(parents=True)
        output.mkdir(parents=True)
        manifest_path = output / "output-roots.json"
        evidence.write_json(manifest_path, status)
        project = work / "p"
        project.mkdir()
        # Fetch only the selected commit, without creating a configured remote.
        git("init", "--quiet", repo=project)
        git("fetch", "--quiet", "--no-tags", "--", str(REPO), revision, repo=project)
        git("-c", "core.autocrlf=true", "checkout", "--quiet", "--detach", revision, repo=project)
        names = tracked(project)
        if not (project / evidence.LOCK_RESOURCE).is_file() or not (project / LOCK_DESCRIPTOR).is_file():
            raise ValueError("Required native DLL or GDExtension descriptor is missing.")
        manifest = input_manifest(project, names)
        (output / "TESTED_INPUTS.sha256").write_text(manifest, encoding="utf-8", newline="\n")
        inputs = sha(output / "TESTED_INPUTS.sha256")
        env = {key: value for key, value in os.environ.items() if not key.upper().startswith(("MYSTICAL_", "GIT_"))}
        for key, leaf in (("APPDATA", "app"), ("LOCALAPPDATA", "local"), ("TEMP", "tmp"), ("TMP", "tmp"), ("XDG_DATA_HOME", "app")):
            path = work / leaf
            path.mkdir(exist_ok=True)
            env[key] = str(path)
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        if roots.configured:
            smoke_profiles = work / "n"
            smoke_profiles.mkdir()
            env["MYSTICAL_VALIDATION_SMOKE_PROFILES"] = str(smoke_profiles)
        seed_cache(project, shared)
        run([engine, "--headless", "--path", project, "--editor", "--import"], project, env, output / "import.log")
        # Godot rewrites text import sidecars with LF. Use committed bytes for
        # validation and retain the generated import cache.
        changed_imports = git("-c", "core.safecrlf=false", "diff", "--name-only", "--", "*.import", repo=project)
        if changed_imports:
            raise ValueError("Godot changed committed import configuration: " + changed_imports.decode().strip())
        git("-c", "core.autocrlf=true", "restore", "--worktree", "--", "*.import", repo=project)
        if input_manifest(project, names) != manifest or git("status", "--porcelain=v1", repo=project):
            raise ValueError("Godot import changed the committed build inputs.")
        print("Running Connected validation. See evidence/connected.log.", flush=True)
        run([shell, "-NoProfile", "-File", project / "tools/validate_release.ps1", "-Mode", "Connected", "-Engine", engine],
            project, env, output / "connected.log")
        print("Running Windows VerifyOnly. See evidence/verifyonly.log.", flush=True)
        release_args = [shell, "-NoProfile", "-File", project / "tools/release_latest.ps1", "-VerifyOnly",
                        "-PlaytestVersion", version, "-PlaytestCommit", revision, "-InputManifestSha256", inputs,
                        "-Engine", engine]
        if roots.configured:
            env["MYSTICAL_PLAYTEST_EXPORT_ROOT"] = str(export_root)
        run(release_args, project, env, output / "verifyonly.log")
        package = evidence.read_json(project / ".godot/validation/last-package.json")
        pack = Path(package["path"])
        metadata = evidence.read_json(project / "assets/content/build_manifest.json")
        source_dll = project / evidence.LOCK_RESOURCE
        if (metadata["playtest_version"] != version or metadata["git_commit"] != revision
                or metadata["input_manifest_sha256"] != inputs or pack.name != GAME
                or pack.parent.parent != export_root or sha(pack) != package["sha256"]
                or sha(source_dll) != package["native_dll_sha256"] or sha(pack.with_name(evidence.LOCK_LIBRARY)) != sha(source_dll)):
            raise ValueError("Staged build identity or native dependency does not match VerifyOnly.")
        metadata["godot_version"] = version_info
        metadata["protocol"] = int(re.search(r"(?m)^const PROTOCOL\s*:?=\s*(\d+)", (project / "network_settings.gd").read_text())[1])
        gate = (project / "persistence_writer_integration.gd").read_text()
        if "const PRODUCTION_CUTOVER_APPROVED := false" not in gate or "const VERIFIED_WRITERS = []" not in gate:
            raise ValueError("Playtest export requires disabled production persistence.")
        checks = summarize(project, package, output)
        shutil.copyfile(pack.with_name("export-project.godot"), output / "export-project.godot")
        shutil.copyfile(export_root / "export.log", output / "export.log")
        evidence.write_json(output / "export-build.json", metadata)
        git("-c", "core.autocrlf=true", "restore", "--worktree", "--", "export_presets.cfg", "assets/content/build_manifest.json", repo=project)
        if input_manifest(project, names) != manifest or git("status", "--porcelain=v1", repo=project):
            raise ValueError("Build inputs differ from the committed source.")
        print("Checking the actual retail executable in disposable Windows profiles.", flush=True)
        retail_stage = stage if roots.configured else work
        def record_profile(path, state):
            status.update(desktop_profile=str(path), desktop_profile_state=state)
            evidence.write_json(manifest_path, status)

        retail = retail_probes(retail_stage, pack, metadata, env, profile_parent, record_profile)
        evidence.write_json(output / "package-verification.json", {key: package[key] for key in
                            ("at", "sha256", "native_dll_sha256", "plan", "startup_logs")})
        if roots.configured:
            (stage / "evidence").mkdir()
        bundle(stage, pack, project, metadata, checks, retail)
        if roots.configured:
            shutil.copyfile(stage / "evidence/retail-probes.json", output / "retail-probes.json")
        keep_cache(project, shared, output)
        shutil.copyfile(project / ".godot/validation/latest-report.json", output / "connected-report.json")
        for log in (retail_stage / "retail").glob("*/*.log"):
            dest = output / "retail-logs" / log.parent.name
            dest.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(log, dest / log.name)
        if source_revision(roots.configured) != revision:
            raise ValueError("Source revision changed during validation.")
        refuse_duplicate(version, archive, args.history)
        # Keep test profiles, tooling and generated imports out of completed releases.
        status["state"] = "validated"
        evidence.write_json(manifest_path, status)
        if roots.configured:
            shutil.copytree(output, stage / "evidence", dirs_exist_ok=True)
        completed = stage / "completed"
        completed.mkdir()
        for name in ("game", "evidence", "SHA256SUMS.txt", "manifest.json", f"Mystical-Garden-{version}-win64.zip"):
            (stage / name).rename(completed / name)
        completed.rename(archive / version)  # Windows refuses an existing destination.
        # Retain the raw run evidence in the validation cache and release logs.
        # The source clone and disposable userdata are not part of the release.
        if roots.configured:
            status["state"] = "published"
            try:
                for path, root in ((stage, roots.stage), (work, roots.workspace)):
                    if path.name != attempt:
                        raise ValueError("Disposable run ownership changed.")
                    remove_owned_tree(path, root)
                status["cleanup"] = "complete"
            except (OSError, ValueError) as error:
                status["cleanup"] = f"pending: {error}"
                print(f"Retained disposable paths: {error}", file=sys.stderr)
            evidence.write_json(manifest_path, status)
        else:
            if work.resolve().parent == stage.resolve() and work.resolve() == work:
                shutil.rmtree(work, ignore_errors=True)
            completed.rmdir()
            if not any(stage.iterdir()):
                stage.rmdir()
        print(f"Verified playtest archived at {archive / version}. No release tag was created.", flush=True)
    except BaseException as error:
        if manifest_path is not None and manifest_path.exists():
            status.update(state="failed", error=str(error))
            evidence.write_json(manifest_path, status)
        raise
    finally:
        lock.unlink()


def inspect_release(version, location):
    validate_archive(location)
    for name in ("manifest.json", "SHA256SUMS.txt", f"Mystical-Garden-{version}-win64.zip"):
        artifact = location / name
        if not artifact.is_file() or artifact.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:
            raise ValueError("The archived release is incomplete or redirected.")
    manifest = evidence.read_json(location / "manifest.json")
    if not manifest or manifest.get("version") != version:
        raise ValueError("The completed release manifest is missing or mismatched.")
    revision = manifest["git_commit"]
    if not re.fullmatch(r"[0-9a-f]{40}", revision) or git("rev-parse", revision + "^{commit}").decode().strip() != revision:
        raise ValueError("The release commit is unavailable.")
    zip_path = location / f"Mystical-Garden-{version}-win64.zip"
    zip_hash, manifest_hash = sha(zip_path), sha(location / "manifest.json")
    expected = f"{zip_hash}  {zip_path.name}\n{manifest_hash}  manifest.json\n"
    if (location / "SHA256SUMS.txt").read_text(encoding="ascii") != expected:
        raise ValueError("The immutable ZIP or manifest no longer matches its archived checksum.")
    with zipfile.ZipFile(zip_path) as packed:
        if packed.read("manifest.json") != (location / "manifest.json").read_bytes():
            raise ValueError("Archive and bundled manifests differ.")
        files = manifest["files"]
        if set(packed.namelist()) != {"manifest.json", *(entry["path"] for entry in files)} or len(packed.namelist()) != len(files) + 1:
            raise ValueError("Unexpected release ZIP members.")
        for entry in files:
            with packed.open(entry["path"]) as stream:
                if (packed.getinfo(entry["path"]).file_size != entry["size"]
                        or hashlib.file_digest(stream, "sha256").hexdigest() != entry["sha256"]):
                    raise ValueError("A release ZIP member failed verification.")
    tag = f"playtest/{version}"
    return {"version": version, "archive": str(location.parent), "location": str(location),
            "git_commit": revision, "git_tag": tag, "zip_sha256": zip_hash, "manifest_sha256": manifest_hash,
            "already_approved": bool(git("tag", "--list", tag)) or os.path.lexists(location / "approval.json")}


def approval_selection(version, preferred, historical):
    version = version_name(version)
    selected = None
    copies = []
    for location in archive_candidates(version, preferred, historical):
        candidate = inspect_release(version, location)
        if selected and any(candidate[key] != selected[key] for key in
                            ("git_commit", "zip_sha256", "manifest_sha256", "already_approved")):
            raise ValueError(f"Conflicting copies of {version}. Select an explicit -ArchiveRoot.")
        if selected is None:
            selected = candidate
        else:
            copies.append(str(location))
    if selected is None:
        raise ValueError(f"No completed archive found for {version}.")
    return {**selected, "identical_copies": copies}


def approve(version, archive, expected_zip=None, expected_manifest=None):
    location = archive_path(archive) / version_name(version)
    identity = inspect_release(version_name(version), location)
    zip_hash, manifest_hash = identity["zip_sha256"], identity["manifest_sha256"]
    if ((expected_zip is not None and expected_zip != zip_hash)
            or (expected_manifest is not None and expected_manifest != manifest_hash)):
        raise ValueError("The release changed after review. Preview it again before approving.")
    if identity["already_approved"]:
        raise ValueError(f"Release {identity['version']} already has approval evidence.")
    tag, revision, version = (identity[key] for key in ("git_tag", "git_commit", "version"))
    approved = datetime.datetime.now(datetime.timezone.utc).isoformat()
    git("tag", "-a", tag, revision, "-m", f"Approved Mystical Garden playtest {version}\n\nZIP SHA-256: {zip_hash}\nManifest SHA-256: {manifest_hash}")
    evidence.write_json(location / "approval.json", {"git_tag": tag, "git_commit": revision,
                        "approved_utc": approved, "zip_sha256": zip_hash, "manifest_sha256": manifest_hash})
    print(f"Approved local tag {tag} at {revision}. Nothing was uploaded.", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    for name in ROOT_KEYS:
        parser.add_argument("--" + name)
    parser.add_argument("--config")
    parser.add_argument("--expected-revision")
    parser.add_argument("--approve", action="store_true")
    parser.add_argument("--plan", action="store_true")
    parser.add_argument("--history", action="append", default=[])
    parser.add_argument("--expected-zip")
    parser.add_argument("--expected-manifest")
    try:
        args = parser.parse_args()
        if args.approve:
            archive = output_options(args).archive
            if args.plan:
                print(json.dumps(approval_selection(args.version, archive, args.history if not args.archive else []),
                                 indent=2))
            else:
                if args.history:
                    raise ValueError("Approve an explicitly reviewed archive, without historical fallback.")
                approve(args.version, archive, args.expected_zip, args.expected_manifest)
        else:
            build(args)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        print(f"Playtest build refused: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
