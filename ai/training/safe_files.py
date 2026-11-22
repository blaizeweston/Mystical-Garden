"""Crash- and power-loss-safe files for training: atomic writes, checksums and checkpoints with fallback.

Every file is written to a temporary name, flushed to disk with fsync and then renamed over the target, so a
reader sees either the old file or the new one, never half of one. Checkpoints also carry a SHA-256 sidecar; a
checkpoint whose bytes do not match is skipped and the newest good one is used instead.
"""

from __future__ import annotations

import hashlib
import io
import json
import os
import re
from pathlib import Path

import torch

CHECKPOINT_PATTERN = re.compile(r"^ckpt_(\d+)\.pt$")


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def atomic_write_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    with temporary.open("wb") as out:
        out.write(data)
        out.flush()
        os.fsync(out.fileno())
    os.replace(temporary, path)


def atomic_write_json(path: Path, value: object) -> None:
    atomic_write_bytes(path, json.dumps(value, indent=1).encode("utf-8"))


def read_json(path: Path) -> dict | None:
    """The file's JSON object, or None when it is missing or unreadable."""
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return value if isinstance(value, dict) else None


def append_line(path: Path, line: str) -> None:
    """Appends one line and syncs it. A power loss can only cut the last line short, which readers skip."""
    with path.open("a", encoding="utf-8") as out:
        out.write(line + "\n")
        out.flush()
        os.fsync(out.fileno())


def remove_temporaries(folder: Path) -> int:
    removed = 0
    if folder.exists():
        for path in folder.glob("*.tmp"):
            path.unlink(missing_ok=True)
            removed += 1
    return removed


def checkpoint_version(path: Path) -> int:
    match = CHECKPOINT_PATTERN.match(path.name)
    return int(match.group(1)) if match else -1


def save_checkpoint(folder: Path, state: dict, version: int, keep: int) -> Path:
    """Writes ckpt_<version>.pt and its checksum, points latest.json at it and keeps the newest `keep`."""
    buffer = io.BytesIO()
    torch.save(state, buffer)
    data = buffer.getvalue()
    path = folder / f"ckpt_{version:07d}.pt"
    atomic_write_bytes(path, data)
    atomic_write_bytes(path.with_name(path.name + ".sha256"), sha256_hex(data).encode("ascii"))
    atomic_write_json(folder / "latest.json", {"file": path.name, "version": version, "sha256": sha256_hex(data)})
    checkpoints = sorted((p for p in folder.glob("ckpt_*.pt") if checkpoint_version(p) >= 0), key=checkpoint_version)
    for old in checkpoints[:-keep] if keep > 0 else []:
        old.unlink(missing_ok=True)
        old.with_name(old.name + ".sha256").unlink(missing_ok=True)
    return path


def verified_bytes(path: Path) -> bytes | None:
    """The checkpoint's bytes when they match its checksum sidecar, else None."""
    try:
        data = path.read_bytes()
        expected = path.with_name(path.name + ".sha256").read_text(encoding="ascii").strip()
    except OSError:
        return None
    return data if sha256_hex(data) == expected else None


def load_checkpoint(folder: Path, log=print) -> tuple[dict, Path] | None:
    """The newest checkpoint that passes its checksum and loads, trying latest.json first. None when none do."""
    candidates: list[Path] = []
    latest = read_json(folder / "latest.json")
    if latest and isinstance(latest.get("file"), str):
        candidates.append(folder / latest["file"])
    newest_first = sorted((p for p in folder.glob("ckpt_*.pt") if checkpoint_version(p) >= 0), key=checkpoint_version, reverse=True)
    candidates += [p for p in newest_first if p not in candidates]
    for path in candidates:
        data = verified_bytes(path)
        if data is None:
            if path.exists():
                log(f"Skipping checkpoint {path.name}: its checksum does not match.")
            continue
        try:
            state = torch.load(io.BytesIO(data), map_location="cpu", weights_only=True)
        except Exception as error:  # noqa: BLE001 - any unreadable checkpoint falls back to an older one
            log(f"Skipping checkpoint {path.name}: {error}")
            continue
        return state, path
    return None
