"""Archive a playtest using the existing Connected and VerifyOnly workflows."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import uuid
import zipfile

import validation_execution as evidence

VERSION = re.compile(r"(0|[1-9][0-9]{0,5})\.(0|[1-9][0-9]{0,5})\.(0|[1-9][0-9]{0,5})(?:-playtest\.([1-9][0-9]{0,5}))?")
REPO = Path(__file__).resolve().parent.parent
LOCK_DESCRIPTOR = evidence.LOCK_RESOURCE.with_name("persistence_lock.gdextension")
GAME = "Mystical Garden.exe"


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def git(*args, repo=REPO):
    return subprocess.check_output(["git", "--no-optional-locks", *args], cwd=repo)


def version_name(value):
    match = VERSION.fullmatch(value)
    if not match:
        raise ValueError("Use a version such as 0.1.0 or 0.1.0-playtest.2.")
    return ".".join(match.groups()[:3]) + "-playtest." + (match[4] or "1")


def source_revision():
    if git("status", "--porcelain=v1", "-z", "--untracked-files=all"):
        raise ValueError("Commit the source changes and use a clean checkout before building.")
    for entry in git("ls-files", "-v", "-z").split(b"\0"):
        if entry and not entry.startswith(b"H "):
            raise ValueError("The Git index has hidden, sparse, or unresolved entries.")
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
    if not (shared / "validation").is_dir():
        return
    shutil.copytree(shared / "validation", project / ".godot/validation")


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
                dest.parent.mkdir(parents=True, exist_ok=True)
                if not dest.exists():
                    shutil.copyfile(validation / path, dest)
                elif sha(dest) != digest:
                    raise ValueError("A prior validation log already uses this identity.")
        shutil.copyfile(validation / name, shared / "validation" / name)
        shutil.copyfile(validation / name, output / name)


def summarize(project, package, output):
    root = project / ".godot/validation"
    source = evidence.read_json(root / "latest-report.json")
    if not source or not all(source.get(k) is True for k in ("passed", "stable_inputs", "release_ready")):
        raise ValueError("Missing current connected validation evidence.")
    source_rows = evidence.read_json(root / "cache.json")
    package_rows = evidence.read_json(root / "package-cache.json")
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


def retail_probes(stage, pack, metadata, env):
    results = {}
    sandbox = stage / "retail"
    sandbox.mkdir()
    version = metadata["playtest_version"]
    ready = f"PLAYTEST READY: {version} · protocol {metadata['protocol']} · legacy-contained"
    backend = "PLAYTEST BLOCKED: The playtest persistence library is missing or incompatible."
    expected_errors = [
        'Condition "!FileAccess::exists(path)" is true. Returning: ERR_FILE_NOT_FOUND',
        "GDExtension dynamic library not found: 'res://assets/native/persistence_lock/persistence_lock.gdextension'.",
        "Error loading extension: 'res://assets/native/persistence_lock/persistence_lock.gdextension'.",
    ]

    for probe in ("normal", "missing", "incompatible", "external-driver", "override", "redirect", "junction",
                  "linked-save", "incompatible-save", "newer-root"):
        home = sandbox / probe
        home.mkdir()
        profile = home / "u"
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
        os.link(pack, exe)  # Disposable files on the same archive volume.
        companion = home / evidence.LOCK_LIBRARY
        if probe != "missing":
            if probe == "incompatible":
                companion.write_bytes(b"Not a Windows DLL\n")
            else:
                shutil.copyfile(pack.with_name(evidence.LOCK_LIBRARY), companion)
        args = ["--headless", "--quit-after", "30", "--max-fps", "120"]
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
            allowed += ["Error loading extension: 'res://assets/native/persistence_lock/persistence_lock.gdextension'."]
        if sorted(errors) != sorted(allowed) or (probe == "incompatible" and len(allowed) != 2) or evidence.FAIL.search(stdout + "\n" + stderr):
            raise ValueError(f"Unexpected retail engine output in {probe}: {errors}")
        success = probe in ("normal", "override", "external-driver", "newer-root")
        blocked = {
            "missing": backend, "incompatible": backend,
            "redirect": "PLAYTEST BLOCKED: Use the default local Windows AppData folder for this playtest.",
            "junction": "PLAYTEST BLOCKED: The playtest save root is unsupported or redirected.",
            "linked-save": "PLAYTEST BLOCKED: The playtest save root is unsupported or currently busy.",
            "incompatible-save": "PLAYTEST BLOCKED: The playtest save set does not match this version.",
        }
        if code != 0 or "EXTERNAL DRIVER RAN" in stdout or sha(anchor) != baseline:
            raise ValueError(f"Retail execution or protected root check failed in {probe}.")
        if success:
            if ready not in stdout or not (release_root / "playtest.identity").is_file() or not (release_root / "diagnostics").is_dir():
                raise ValueError(f"Retail title, version or isolated save root missing in {probe}.")
        elif probe in blocked:
            if blocked[probe] not in stdout or "PLAYTEST READY:" in stdout or (release_root / "diagnostics").exists():
                raise ValueError(f"Retail did not refuse the {probe} probe before gameplay.")
        if probe == "newer-root" and sorted(x.name for x in newer.iterdir()) != ["garden.cfg"]:
            raise ValueError("An earlier playtest touched another version's save root.")
        if list(roaming.rglob("character.cfg")) or list(roaming.rglob("catalog.cfg")):
            raise ValueError(f"Unexpected canonical profile or catalog during retail probe {probe}.")
        results[probe] = {"exit": code, "run_id": f"{version}-{probe}", "exe_sha256": sha(exe),
                          "expected_errors": len(allowed), "ready": success}
    return results


def bundle(stage, pack, project, metadata, checks, retail):
    payload = stage / "game"
    payload.mkdir()
    names = [GAME, evidence.LOCK_LIBRARY]
    pck = pack.with_suffix(".pck")
    if pck.is_file():
        names.append(pck.name)
    for name in names:
        shutil.copyfile(pack.parent / name, payload / name)
    extension = payload / "licenses"
    extension.mkdir()
    shutil.copyfile(project / LOCK_DESCRIPTOR, extension / LOCK_DESCRIPTOR.name)
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


def build(args):
    if os.name != "nt" or sys.maxsize <= 2**32:
        raise ValueError("The playtest builder requires Windows x64.")
    version = version_name(args.version)
    revision = source_revision()
    engine = Path(args.engine).resolve(strict=True)
    archive = Path(os.path.abspath(args.archive or REPO / "playtest-releases"))
    validate_archive(archive)
    if (archive == REPO or REPO in archive.parents and archive != REPO / "playtest-releases"
            or archive.name in (".git", ".godot")):
        raise ValueError("Use the ignored default archive or a directory outside the source tree.")
    tag = f"playtest/{version}"
    if git("tag", "--list", tag) or (archive / version).exists():
        raise ValueError(f"Release {version} or its annotated tag already exists.")
    shell = shutil.which("pwsh")
    if not shell:
        raise ValueError("PowerShell 7 is required by release validation.")
    archive.mkdir(parents=True, exist_ok=True)
    shared = archive / ".cache"
    shared.mkdir(exist_ok=True)
    validate_archive(shared)
    lock = shared / "build.lock"
    with lock.open("x", encoding="ascii") as handle:
        handle.write(str(os.getpid()))
    try:
        if (archive / version).exists() or git("tag", "--list", tag):
            raise ValueError(f"Release {version} already exists.")
        stage = archive / ".staging" / uuid.uuid4().hex[:10]
        validate_archive(stage)
        stage.mkdir(parents=True)
        print(f"Building {version} at {revision}. Staging: {stage}", flush=True)
        work = stage / "work"
        output = stage / "evidence"
        output.mkdir()
        project = work / "p"
        subprocess.run(["git", "clone", "--quiet", "--no-hardlinks", "--no-checkout", "--", str(REPO), str(project)],
                       check=True, stdout=subprocess.DEVNULL)
        git("checkout", "--quiet", "--detach", revision, repo=project)
        names = tracked(project)
        if not (project / evidence.LOCK_RESOURCE).is_file() or not (project / LOCK_DESCRIPTOR).is_file():
            raise ValueError("Required native DLL or GDExtension descriptor is missing.")
        manifest = input_manifest(project, names)
        (output / "TESTED_INPUTS.sha256").write_text(manifest, encoding="utf-8", newline="\n")
        inputs = sha(output / "TESTED_INPUTS.sha256")
        env = {key: value for key, value in os.environ.items() if not key.startswith("MYSTICAL_")}
        for key, leaf in (("APPDATA", "app"), ("LOCALAPPDATA", "local"), ("TEMP", "tmp"), ("TMP", "tmp"), ("XDG_DATA_HOME", "app")):
            path = work / leaf
            path.mkdir(exist_ok=True)
            env[key] = str(path)
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        seed_cache(project, shared)
        run([engine, "--headless", "--path", project, "--editor", "--import"], project, env, output / "import.log")
        # Godot rewrites text import sidecars with LF. Use committed bytes for
        # validation and retain the generated import cache.
        for relative in (Path(os.fsdecode(line)) for line in git("diff", "--name-only", "-z", "--", "*.import", repo=project).split(b"\0") if line):
            raise ValueError(f"Godot changed the committed import configuration: {relative}.")
        git("restore", "--worktree", "--", "*.import", repo=project)
        if input_manifest(project, names) != manifest or git("status", "--porcelain=v1", repo=project):
            raise ValueError("Godot import changed the committed build inputs.")
        print("Running Connected validation. See evidence/connected.log.", flush=True)
        run([shell, "-NoProfile", "-File", project / "tools/validate_release.ps1", "-Mode", "Connected", "-Engine", engine],
            project, env, output / "connected.log")
        version_info = subprocess.check_output([str(engine), "--version"], env=env, text=True).strip()
        if version_info != "4.7.2.stable.official.ed1daf0bf":
            raise ValueError("Godot and the native DLL require the verified 4.7.2 editor revision.")
        print("Running Windows VerifyOnly. See evidence/verifyonly.log.", flush=True)
        run([shell, "-NoProfile", "-File", project / "tools/release_latest.ps1", "-VerifyOnly",
             "-PlaytestVersion", version, "-PlaytestCommit", revision, "-InputManifestSha256", inputs, "-Engine", engine],
            project, env, output / "verifyonly.log")
        package = evidence.read_json(project / ".godot/validation/last-package.json")
        pack = Path(package["path"])
        metadata = evidence.read_json(project / "assets/content/build_manifest.json")
        source_dll = project / evidence.LOCK_RESOURCE
        if (metadata["playtest_version"] != version or metadata["git_commit"] != revision
                or metadata["input_manifest_sha256"] != inputs or pack.name != GAME
                or pack.parent.parent != project / ".godot/release" or sha(pack) != package["sha256"]
                or sha(source_dll) != package["native_dll_sha256"] or sha(pack.with_name(evidence.LOCK_LIBRARY)) != sha(source_dll)):
            raise ValueError("Staged build identity or native dependency does not match VerifyOnly.")
        metadata["godot_version"] = version_info
        metadata["protocol"] = int(re.search(r"(?m)^const PROTOCOL\s*:?=\s*(\d+)", (project / "network_settings.gd").read_text())[1])
        gate = (project / "persistence_writer_integration.gd").read_text()
        if "const PRODUCTION_CUTOVER_APPROVED := false" not in gate or "const VERIFIED_WRITERS = []" not in gate:
            raise ValueError("Playtest export requires disabled production persistence.")
        checks = summarize(project, package, output)
        shutil.copyfile(pack.with_name("export-project.godot"), output / "export-project.godot")
        evidence.write_json(output / "export-build.json", metadata)
        git("restore", "--worktree", "--", "export_presets.cfg", "assets/content/build_manifest.json", repo=project)
        if input_manifest(project, names) != manifest or git("status", "--porcelain=v1", repo=project):
            raise ValueError("Build inputs differ from the committed source.")
        print("Checking the actual retail executable in disposable Windows profiles.", flush=True)
        retail = retail_probes(stage, pack, metadata, env)
        evidence.write_json(output / "package-verification.json", {key: package[key] for key in
                            ("at", "sha256", "native_dll_sha256", "plan", "startup_logs")})
        bundle(stage, pack, project, metadata, checks, retail)
        keep_cache(project, shared, output)
        for log in (stage / "retail").glob("*/*.log"):
            dest = output / "retail-logs" / log.parent.name
            dest.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(log, dest / log.name)
        if source_revision() != revision or git("tag", "--list", tag):
            raise ValueError("Source revision or release tag changed during validation.")
        # Keep test profiles, tooling and generated imports out of completed releases.
        completed = stage / "completed"
        completed.mkdir()
        for name in ("game", "evidence", "SHA256SUMS.txt", "manifest.json", f"Mystical-Garden-{version}-win64.zip"):
            (stage / name).rename(completed / name)
        completed.rename(archive / version)  # Windows refuses an existing destination.
        # Retain the raw run evidence in the validation cache and release logs.
        # The source clone and disposable userdata are not part of the release.
        shutil.rmtree(work, ignore_errors=True)
        shutil.rmtree(stage / "retail", ignore_errors=True)
        print(f"Verified playtest archived at {archive / version}. No release tag was created.", flush=True)
    finally:
        lock.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--archive", default="")
    parser.add_argument("--engine", required=True)
    try:
        build(parser.parse_args())
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"Playtest build refused: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
