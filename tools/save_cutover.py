"""Offline, byte-preserving rehearsal of the AC-06 save-root cutover.

No save conversion, recovery, production activation or deletion occurs here.
Inspect a quiescent backup, retain its plan outside it, then explicitly stage
that exact plan. Publication is a no-replace directory rename on local NTFS.
Run --help for the three operations. Paths are operator-selected, never guessed.
"""
import argparse
from contextlib import contextmanager
import ctypes
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys

POLICY_FILE = Path(__file__).resolve().parents[1] / "assets/content/save_cutover.json"
SENTINEL = ".mystical-garden-persistence.lock"
PLAN_FILE = ".cutover-plan.json"
STAGE_SUFFIX = ".migration-pending"
RECOVERY_SUFFIXES = (".transaction", ".txn_link", ".txn_stage", ".recovery", ".tmp",
                     ".txn_expected", ".txn_receipt", ".txn_previous", ".txn_publish", ".transaction.new")
RESERVED_NAMES = {"CON", "PRN", "AUX", "NUL", "CONIN$", "CONOUT$"}


def canonical(value):
    return (json.dumps(value, ensure_ascii=True, sort_keys=True, indent=2) + "\n").encode()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def policy():
    value = json.loads(POLICY_FILE.read_bytes())
    if (set(value) != {"schema", "root_name", "marker", "max_files", "max_bytes"}
            or value["schema"] != 1 or not isinstance(value["root_name"], str)
            or not re.fullmatch(r"Mystical Garden Guarded [1-9][0-9]*", value["root_name"])
            or value["marker"] != "guarded-root.json"
            or not all(type(value[key]) is int and value[key] > 0 for key in ("max_files", "max_bytes"))):
        raise ValueError("Unsupported save-cutover policy")
    return value


def policy_digest():
    config = policy()
    return sha((str(config["schema"]) + "\n" + config["root_name"] + "\n" + config["marker"]).encode())


def ordinary(name):
    stem = name.split(".", 1)[0].upper()
    return (bool(name) and name not in (".", "..") and not name.endswith((".", " "))
            and not any(ord(c) < 32 or c in '\\/:"<>|?*~' for c in name)
            and stem not in RESERVED_NAMES and not re.fullmatch(r"(?:COM|LPT)[0-9\u00b9\u00b2\u00b3]", stem))


def plain(path, missing=False):
    """Reject aliases before resolve() could hide them; every ancestor matters."""
    path = Path(os.path.abspath(path))
    if os.name == "nt" and (not path.drive or str(path).startswith("\\\\") or len(str(path)) >= 260):
        raise ValueError("Use a short, local drive-absolute path")
    for part in path.parts[1:]:
        if not ordinary(part):
            raise ValueError("Unsupported path component: " + part)
    for entry in (*reversed(path.parents), path):
        try:
            info = entry.lstat()
        except FileNotFoundError:
            if missing:
                continue
            raise ValueError("Missing path: " + str(entry)) from None
        if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x400:
            raise ValueError("Redirected path: " + str(entry))
        if entry != path and not stat.S_ISDIR(info.st_mode):
            raise ValueError("Non-directory ancestor: " + str(entry))
    return path


def ntfs(path):
    if os.name != "nt":
        raise ValueError("Save cutover is supported only on Windows fixed local NTFS")
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.GetVolumePathNameW.argtypes = [ctypes.c_wchar_p, ctypes.c_wchar_p, ctypes.c_uint32]
    kernel.GetDriveTypeW.argtypes = [ctypes.c_wchar_p]
    kernel.GetVolumeInformationW.argtypes = [ctypes.c_wchar_p, ctypes.c_wchar_p, ctypes.c_uint32,
                                            ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p,
                                            ctypes.c_wchar_p, ctypes.c_uint32]
    volume, filesystem = ctypes.create_unicode_buffer(260), ctypes.create_unicode_buffer(32)
    if not kernel.GetVolumePathNameW(str(path), volume, 260) or kernel.GetDriveTypeW(volume.value) != 3:
        raise ValueError("Use a fixed local NTFS volume")
    if (not kernel.GetVolumeInformationW(volume.value, None, 0, None, None, None, filesystem, 32)
            or filesystem.value != "NTFS"):
        raise ValueError("Use a fixed local NTFS volume")
    kernel.CreateFileW.restype = ctypes.c_void_p
    kernel.CreateFileW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
                                  ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
    kernel.CloseHandle.argtypes = [ctypes.c_void_p]
    kernel.GetFinalPathNameByHandleW.argtypes = [ctypes.c_void_p, ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32]
    kernel.GetFileInformationByHandleEx.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p, ctypes.c_uint32]
    # Native gameplay authorization also refuses case-sensitive ancestry.
    # Check it before publishing a root that the game could never admit.
    ancestry = [entry for entry in reversed(path.parents) if entry != Path(path.anchor)] + [path]
    for entry in ancestry:
        handle = kernel.CreateFileW(str(entry), 0x80, 7, None, 3, 0x02200000, None)
        if handle == ctypes.c_void_p(-1).value:
            raise ValueError("Cannot inspect physical NTFS path")
        try:
            physical = ctypes.create_unicode_buffer(260)
            count = kernel.GetFinalPathNameByHandleW(handle, physical, 260, 0)
            if not count or count >= 260 or physical.value.removeprefix("\\\\?\\").casefold() != str(entry).casefold():
                raise ValueError("Drive aliases and redirected physical roots are unsupported")
            flags = ctypes.c_uint32()
            if not kernel.GetFileInformationByHandleEx(handle, 23, ctypes.byref(flags), ctypes.sizeof(flags)) or flags.value:
                raise ValueError("Case-sensitive or unsupported NTFS ancestry")
        finally:
            kernel.CloseHandle(handle)


def live_roots():
    """Known live locations are excluded even if someone passes one as a backup."""
    appdata = os.environ.get("APPDATA", "")
    profile = os.environ.get("USERPROFILE", "")
    parents = [Path(appdata)] if appdata else []
    if profile:
        parents.append(Path(profile) / "AppData/Roaming")
    return [parent / name for parent in parents for name in
            ("Mystical Garden", "Mystical Garden Prototype", policy()["root_name"])]


def overlaps(first, second):
    return first == second or first in second.parents or second in first.parents


def read_regular(path):
    path = plain(path)
    before = path.stat()
    if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1 or before.st_size > policy()["max_bytes"]:
        raise ValueError("Nonregular or hard-linked file: " + str(path))
    with path.open("rb") as stream:
        if identity(os.fstat(stream.fileno())) != identity(before):
            raise ValueError("File changed before reading: " + str(path))
        data = stream.read()
        after = os.fstat(stream.fileno())
    if identity(before) != identity(after) or identity(path.stat()) != identity(after) or len(data) != after.st_size:
        raise ValueError("File changed while reading: " + str(path))
    return data


def identity(info):
    # Windows path-stat and fstat disagree on ctime (birth vs change time).
    # Stable file identity, size/mtime and repeated byte digests are required.
    return (info.st_dev, info.st_ino, info.st_mode, info.st_nlink, info.st_size, info.st_mtime_ns)


def raise_walk_error(error):
    raise error


def inventory(root, ignored=()):
    root = plain(root)
    if not root.is_dir():
        raise ValueError("Backup must be a directory")
    config = policy()
    files, directories, total, names = [], [], 0, set()
    for folder, dirs, leaves in os.walk(root, followlinks=False, onerror=raise_walk_error):
        for name in sorted(dirs + leaves):
            entry = plain(Path(folder) / name)
            relative = entry.relative_to(root).as_posix()
            key = relative.casefold()
            if key in names:
                raise ValueError("Case-colliding backup names: " + relative)
            names.add(key)
            if len(names) > config["max_files"]:
                raise ValueError("Backup exceeds the entry limit")
            if relative in ignored:
                if entry.is_dir(): raise ValueError("Reserved file is a directory")
                read_regular(entry)
                continue
            if entry.is_dir():
                directories.append(relative)
                continue
            if (name.lower().endswith(RECOVERY_SUFFIXES)
                    or name.lower() in ("session.cfg", config["marker"], PLAN_FILE, "playtest.identity")):
                raise ValueError("Unresolved recovery, lease or foreign-root evidence: " + relative)
            data = read_regular(entry)
            total += len(data)
            if total > config["max_bytes"]:
                raise ValueError("Backup exceeds the byte limit")
            files.append({"path": relative, "size_bytes": len(data), "sha256": sha(data)})
    return {"directories": sorted(directories), "files": sorted(files, key=lambda row: row["path"]), "total_bytes": total}


def inspect_backup(backup):
    backup = plain(backup)
    if any(overlaps(backup, plain(root, missing=True)) for root in live_roots()):
        raise ValueError("Inspect a quiescent backup, never a live save root or its parent")
    ntfs(backup)
    contents = inventory(backup, (SENTINEL,))
    if contents != inventory(backup, (SENTINEL,)):
        raise ValueError("Backup changed during inspection")
    return {"schema": 1, "source_backup": str(backup), "policy_sha256": policy_digest(), **contents}


def read_plan(path, expected):
    data = read_regular(path)
    if not re.fullmatch("[0-9a-f]{64}", expected) or sha(data) != expected:
        raise ValueError("The reviewed manifest hash does not match")
    value = json.loads(data)
    if (canonical(value) != data or set(value) != {"schema", "source_backup", "policy_sha256", "directories", "files", "total_bytes"}
            or value["schema"] != 1 or value["policy_sha256"] != policy_digest()):
        raise ValueError("Unsupported or noncanonical cutover manifest")
    # Re-inspect the source, rather than trusting writable paths in a manifest.
    if inspect_backup(value["source_backup"]) != value:
        raise ValueError("Backup no longer matches the reviewed manifest")
    return value


@contextmanager
def destination_lock(destination):
    """Short-lived OS ownership; termination releases it without deleting evidence."""
    lock_path = destination.with_name(destination.name + ".migration-lock")
    plain(lock_path, missing=True)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateFileW.restype = ctypes.c_void_p
    kernel.CreateFileW.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32, ctypes.c_uint32,
                                  ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32, ctypes.c_void_p]
    kernel.CloseHandle.argtypes = [ctypes.c_void_p]
    # OPEN_ALWAYS, no sharing, OPEN_REPARSE_POINT. Nothing inside saves is opened.
    handle = kernel.CreateFileW(str(lock_path), 0xC0000000, 0, None, 4, 0x00200000, None)
    if handle == ctypes.c_void_p(-1).value:
        raise ValueError("Migration destination is busy or unavailable (Windows error %d)" % ctypes.get_last_error())
    try:
        class Information(ctypes.Structure):
            _fields_ = [("attributes", ctypes.c_uint32), ("created", ctypes.c_uint32 * 2),
                        ("accessed", ctypes.c_uint32 * 2), ("written", ctypes.c_uint32 * 2),
                        ("volume", ctypes.c_uint32), ("size_high", ctypes.c_uint32),
                        ("size_low", ctypes.c_uint32), ("links", ctypes.c_uint32),
                        ("index_high", ctypes.c_uint32), ("index_low", ctypes.c_uint32)]
        info = Information()
        kernel.GetFileInformationByHandle.argtypes = [ctypes.c_void_p, ctypes.POINTER(Information)]
        if not kernel.GetFileInformationByHandle(handle, ctypes.byref(info)):
            raise OSError(ctypes.get_last_error(), "Could not inspect migration lock")
        if info.attributes & (0x400 | 0x10) or info.links != 1 or info.size_high or info.size_low:
            raise ValueError("Migration lock contains unexpected evidence")
        yield
    finally:
        if not kernel.CloseHandle(handle):
            raise OSError(ctypes.get_last_error(), "Could not release migration lock")


def write_new(path, data):
    with path.open("xb") as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
    if read_regular(path) != data:
        raise ValueError("Copy verification failed: " + str(path))


def stage(plan_path, expected, destination, fault=None):
    """fault is a test-only callback; the CLI exposes no injection option."""
    plan = read_plan(plan_path, expected)
    backup = plain(plan["source_backup"])
    destination = plain(destination, missing=True)
    if destination.name != policy()["root_name"] or overlaps(backup, destination):
        raise ValueError("Use the separate guarded-root name, outside the backup")
    if any(overlaps(destination, plain(root, missing=True)) for root in live_roots()
           if root.name != policy()["root_name"]):
        raise ValueError("The destination must not overlap an older live root")
    if overlaps(plain(plan_path), destination) or overlaps(plain(plan_path), backup):
        raise ValueError("Keep the reviewed manifest outside both save roots")
    parent = plain(destination.parent)
    if not parent.is_dir(): raise ValueError("Create/select an existing ordinary destination parent")
    ntfs(parent)
    staging = destination.with_name(destination.name + STAGE_SUFFIX)
    marker = canonical({"schema": 1, "root_name": policy()["root_name"], "origin": "migration",
                        "policy_sha256": plan["policy_sha256"], "manifest_sha256": expected})
    with destination_lock(destination):
        if destination.exists():
            if read_regular(destination / policy()["marker"]) == marker and read_regular(destination / PLAN_FILE) == canonical(plan):
                return {"status": "already_published", "destination": str(destination), "manifest_sha256": expected}
            raise ValueError("Destination already exists; no save was overwritten")
        if staging.exists():
            plain(staging)
            if read_regular(staging / PLAN_FILE) != canonical(plan):
                raise ValueError("Pending migration belongs to a different plan")
            # Refuse foreign files; partial files remain evidence, never overwritten.
            allowed = {row["path"] for row in plan["files"]} | {PLAN_FILE, policy()["marker"]}
            allowed_dirs = set(plan["directories"])
            for folder, dirs, leaves in os.walk(staging, followlinks=False, onerror=raise_walk_error):
                for name in dirs + leaves:
                    path = plain(Path(folder) / name)
                    relative = path.relative_to(staging).as_posix()
                    if relative not in (allowed_dirs if path.is_dir() else allowed):
                        raise ValueError("Unexpected pending migration evidence: " + relative)
        else:
            staging.mkdir()
            write_new(staging / PLAN_FILE, canonical(plan))
        for relative in plan["directories"]:
            (staging / relative).mkdir(exist_ok=True)
        for row in plan["files"]:
            source, target = backup / row["path"], staging / row["path"]
            data = read_regular(source)
            if len(data) != row["size_bytes"] or sha(data) != row["sha256"]:
                raise ValueError("Backup changed before copy: " + row["path"])
            if target.exists():
                if read_regular(target) != data:
                    raise ValueError("Incomplete or changed staged copy retained: " + row["path"])
            else:
                write_new(target, data)
            if fault: fault("copied", row["path"])
        marker_path = staging / policy()["marker"]
        if marker_path.exists():
            if read_regular(marker_path) != marker: raise ValueError("Changed staged root identity")
        else:
            write_new(marker_path, marker)
        expected_contents = {key: plan[key] for key in ("directories", "files", "total_bytes")}
        if inventory(staging, (PLAN_FILE, policy()["marker"])) != expected_contents:
            raise ValueError("Staged root does not match the reviewed manifest")
        if inspect_backup(backup) != plan:
            raise ValueError("Backup changed; staged evidence retained")
        if fault: fault("before_publish", "")
        # Windows rename refuses an existing destination, including an empty one.
        staging.rename(destination)
        return {"status": "published", "destination": str(destination), "manifest_sha256": expected}


def verify(plan_path, expected, destination):
    plan = read_plan(plan_path, expected)
    destination = plain(destination)
    expected_contents = {key: plan[key] for key in ("directories", "files", "total_bytes")}
    marker = json.loads(read_regular(destination / policy()["marker"]))
    if (destination.name != policy()["root_name"] or marker != {"schema": 1, "root_name": policy()["root_name"],
            "origin": "migration", "policy_sha256": plan["policy_sha256"], "manifest_sha256": expected}
            or read_regular(destination / PLAN_FILE) != canonical(plan)
            or inventory(destination, (PLAN_FILE, policy()["marker"])) != expected_contents):
        raise ValueError("Destination differs from its initial migration; it was not overwritten")
    return {"status": "verified_initial_copy", "manifest_sha256": expected}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="operation", required=True)
    inspect = sub.add_parser("inspect", help="Read a quiescent backup; create no files")
    inspect.add_argument("backup", type=Path)
    inspect.add_argument("--plan", type=Path, help="Write a NEW reviewed manifest outside the backup")
    for name in ("stage", "verify"):
        command = sub.add_parser(name)
        command.add_argument("plan", type=Path)
        command.add_argument("--manifest-sha256", required=True)
        command.add_argument("--destination", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        if args.operation == "inspect":
            plan = inspect_backup(args.backup)
            if args.plan:
                output = plain(args.plan, missing=True)
                if overlaps(output, plain(args.backup)):
                    raise ValueError("Keep the reviewed manifest outside the backup")
                write_new(output, canonical(plan))
                print(canonical({"plan": str(output), "manifest_sha256": sha(canonical(plan))}).decode(), end="")
            else:
                print(canonical(plan).decode(), end="")
        else:
            operation = stage if args.operation == "stage" else verify
            print(canonical(operation(args.plan, args.manifest_sha256, args.destination)).decode(), end="")
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print("CUTOVER REFUSED: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
