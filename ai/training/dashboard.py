"""A live training dashboard in the browser. Reads the run folder only, so it is safe while training runs.

  python dashboard.py [--run-dir <folder>] [--port 8765] [--no-browser] [--lan]

Serves http://127.0.0.1:<port>/ (this computer only) and opens it. With --lan it also answers other computers on
the local network, at the addresses it prints; Windows asks once whether to let Python through its firewall.
The page refreshes itself every 15 seconds. Close the window running this script to stop the dashboard;
training is not affected.

Charts mark the changes listed in changes.json (next to this script) and, automatically, restarts and resumes
from an older checkpoint. Updates lost to such a resume are left out, so the lines never double back.
"""

from __future__ import annotations

import argparse
import json
import socket
import sys
import threading
import time
import webbrowser
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import safe_files as S

HERE = Path(__file__).resolve().parent
PAGE = HERE / "dashboard.html"
CHANGES = HERE / "changes.json"
MAX_POINTS = 1500
## A pause longer than this between updates counts as a restart.
RESTART_GAP = 120
FIELDS = ("wipe_rate", "explore_found_rate", "explore_first_sight_s", "damage_to_party", "life_return",
          "entropy", "entropy_fight", "entropy_messages", "approx_kl", "clip_fraction", "value_loss", "learning_rate",
          "squad_mix", "replay_gap", "explained_variance", "free_share", "wipe", "cleared", "timeout", "speed", "rows", "episodes",
          "entropy_behaviour", "entropy_enemy_target", "entropy_ally_target", "entropy_manoeuvre", "entropy_commit",
          "commit_set_share", "commit_long_share")
# Commitment options held for 2 s or more (mob_contract.json commitments_ms: usual, 0.25, 0.5, 1, 1.25, 2, 2.5, 3 s).
LONG_COMMIT_FROM = 5
## Compared hour over hour in the summary.
SUMMARY = ("wipe_rate", "explore_found_rate", "explore_first_sight_s", "damage_to_party", "life_return", "entropy",
           "approx_kl", "explained_variance", "speed")
MILESTONES = [250e6 * n for n in range(1, 41)]


def default_run_dir() -> Path:
    settings = S.load_training_settings(HERE)
    configured = settings.get("run_dir") or ""
    return Path(configured) if configured else Path.home() / "Documents" / "Godot" / "mob-training" / "run"


class Metrics:
    """Reads metrics.jsonl as it grows, skipping a line cut short by a power loss. When training resumes from an
    older checkpoint, the updates after it were lost: they are dropped and the resume is recorded as an event."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.rows: list[dict] = []
        self.events: list[dict] = []
        self.offset = 0
        self.lock = threading.Lock()

    def refresh(self) -> tuple[list[dict], list[dict]]:
        with self.lock:
            if not self.path.exists():
                return self.rows, self.events
            size = self.path.stat().st_size
            if size < self.offset:
                self.rows, self.events, self.offset = [], [], 0
            with self.path.open("rb") as source:
                source.seek(self.offset)
                chunk = source.read()
            end = chunk.rfind(b"\n") + 1
            self.offset += end
            for line in chunk[:end].splitlines():
                try:
                    row = json.loads(line)
                    stamp = time.mktime(time.strptime(row["time"], "%Y-%m-%d %H:%M:%S"))
                except (ValueError, KeyError):
                    continue
                self._add(row, stamp)
            return self.rows, self.events

    def _add(self, row: dict, stamp: float) -> None:
        episodes = max(1, int(row.get("episodes", 0)))
        outcomes = row.get("outcomes", {})
        for name in ("wipe", "cleared", "timeout"):
            row[name] = outcomes.get(name, 0) / episodes
        # Per-head entropy (logged from the phase 1 fixes on) and how often a set hold length is chosen.
        for head, value in (row.get("entropy_heads") or {}).items():
            row[f"entropy_{head}"] = value
        choices = row.get("commit_choices")
        if choices:
            row["commit_set_share"] = 1.0 - float(choices[0])
            row["commit_long_share"] = float(sum(choices[LONG_COMMIT_FROM:]))
        last = self.rows[-1] if self.rows else None
        resumed_at = row["samples"] - int(row.get("rows", 0))
        if last is not None and row["samples"] <= last["samples"]:
            lost = last["samples"] - resumed_at
            while self.rows and self.rows[-1]["samples"] > resumed_at:
                self.rows.pop()
            self.events.append({"kind": "rewind", "version": row.get("version"), "t": stamp,
                                "title": "Resumed from an older checkpoint",
                                "detail": f"{lost / 1e6:.1f}M decisions trained since that checkpoint were lost."})
            last = self.rows[-1] if self.rows else None
        elif last is not None and stamp - last["_t"] > RESTART_GAP:
            self.events.append({"kind": "restart", "version": row.get("version"), "t": stamp, "title": "Restarted",
                                "detail": f"Training paused for {(stamp - last['_t']) / 60:.0f} minutes."})
        gap = stamp - last["_t"] if last is not None else 0.0
        row["_gap"] = gap if 0 < gap < RESTART_GAP else 0.0
        row["_new"] = row["samples"] - last["samples"] if row["_gap"] > 0 else 0
        row["_t"] = stamp
        self.rows.append(row)


def mean(rows: list[dict], field: str) -> float | None:
    values = [r[field] for r in rows if isinstance(r.get(field), (int, float))
              and not (field == "replay_gap" and r[field] < 0)]
    return sum(values) / len(values) if values else None


def speed(rows: list[dict]) -> float | None:
    """Decisions over seconds across a stretch: log times only have whole seconds, so single updates are noisy."""
    seconds = sum(r["_gap"] for r in rows)
    return sum(r["_new"] for r in rows) / seconds if seconds >= 6 else None


def change_versions() -> list[int]:
    return sorted(int(entry.get("version", 0)) for entry in (S.read_json(CHANGES) or {}).get("changes", []))


def bucketed(rows: list[dict]) -> list[dict]:
    """At most about MAX_POINTS points, each the mean of consecutive updates, so long runs stay quick to draw. No
    point mixes updates from either side of a listed change, so a jump in level stays a clean step."""
    if not rows:
        return []
    size = max(1, -(-len(rows) // MAX_POINTS))
    breaks = change_versions()
    groups, group = [], []
    for row in rows:
        version = row.get("version")
        crossed = group and version is not None and group[-1].get("version") is not None and \
            any(group[-1]["version"] < at <= version for at in breaks)
        if len(group) == size or crossed:
            groups.append(group)
            group = []
        group.append(row)
    groups.append(group)
    points = []
    for group in groups:
        point = {"time": group[-1]["time"], "t": group[-1]["_t"], "samples": group[-1]["samples"],
                 "version": group[-1].get("version")}
        for field in FIELDS:
            point[field] = speed(group) if field == "speed" else mean(group, field)
        points.append(point)
    return points


def place(rows: list[dict], version: int) -> dict | None:
    """The first update at or after a policy version."""
    for row in rows:
        if row.get("version") is not None and row["version"] >= version:
            return row
    return None


def changes(rows: list[dict], events: list[dict]) -> list[dict]:
    marks = []
    listed = (S.read_json(CHANGES) or {}).get("changes", [])
    for entry in listed:
        at = place(rows, int(entry.get("version", 0)))
        if at is not None:
            marks.append({"kind": "change", "version": at.get("version"), "t": at["_t"], "samples": at["samples"],
                          "title": entry.get("title", ""), "detail": entry.get("detail", "")})
    listed_versions = [m["version"] for m in marks]
    for event in events:
        at = place(rows, int(event.get("version") or 0))
        # A restart for a listed change is that change; it needs no mark of its own.
        if event["kind"] == "restart" and at is not None and any(abs((at.get("version") or 0) - v) <= 5 for v in listed_versions):
            continue
        if at is not None:
            marks.append({**event, "samples": at["samples"], "t": at["_t"]})
    marks.sort(key=lambda m: m["t"])
    number = 0
    for mark in marks:
        if mark["kind"] == "change":
            number += 1
            mark["number"] = number
    return marks


def summary(rows: list[dict], now: float) -> dict:
    """Each key figure over the last hour of training against the hour before it."""
    recent = [r for r in rows if r["_t"] > now - 3600]
    before = [r for r in rows if now - 7200 < r["_t"] <= now - 3600]
    result = {}
    for field in SUMMARY:
        result[field] = {"now": speed(recent) if field == "speed" else mean(recent, field),
                         "before": speed(before) if field == "speed" else mean(before, field)}
    return result


def pace(rows: list[dict], now: float) -> dict:
    recent = [r for r in rows if r["_t"] > now - 3600]
    if len(recent) < 2:
        return {}
    per_second = speed(recent) or 0.0
    total = rows[-1]["samples"]
    target = next((m for m in MILESTONES if m > total), None)
    return {"per_hour": per_second * 3600, "next": target,
            "eta_hours": (target - total) / per_second / 3600 if target and per_second > 0 else None}


def worker_ages(workers: list[dict], now: float) -> None:
    for progress in workers:
        try:
            progress["age"] = now - datetime.fromisoformat(str(progress.get("time"))).timestamp()
        except ValueError:
            progress["age"] = None


def since_change(rows: list[dict]) -> list[dict]:
    """The updates since the newest listed change that has updates after it, plus a quarter as many before it for
    context. All of them when no change falls inside the rows."""
    for at in reversed(change_versions()):
        start = next((i for i, r in enumerate(rows) if r.get("version") is not None and r["version"] >= at), None)
        if start is not None and start > 0 and len(rows) - start >= 2:
            return rows[max(0, start - (len(rows) - start) // 4):]
    return rows


def snapshot(run_dir: Path, metrics: Metrics, hours: float | None, focus: bool = False) -> dict:
    rows, events = metrics.refresh()
    now = time.time()
    # Ranges and comparisons count back from the latest update, so a paused run still shows its last hours.
    latest = rows[-1]["_t"] if rows else now
    shown = [r for r in rows if r["_t"] >= latest - hours * 3600] if hours else rows
    if focus:
        shown = since_change(shown)
    checkpoints = []
    folder = run_dir / "checkpoints"
    for path in sorted(folder.glob("ckpt_*.pt"), key=S.checkpoint_version) + sorted((folder / "milestones").glob("ckpt_*.pt"), key=S.checkpoint_version):
        checkpoints.append({"name": path.name, "version": S.checkpoint_version(path), "milestone": path.parent.name == "milestones",
                            "age": now - path.stat().st_mtime,
                            "time": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(path.stat().st_mtime))})
    workers = [w for w in (S.read_json(p) for p in sorted((run_dir / "workers").glob("w*.json"))) if w]
    worker_ages(workers, now)
    processes = S.read_json(run_dir / "processes.json") or {}
    trainer = S.read_json(run_dir / "trainer.json") or {}
    heartbeat_age = None
    if trainer.get("time"):
        heartbeat_age = now - time.mktime(time.strptime(trainer["time"], "%Y-%m-%d %H:%M:%S"))
    return {
        "run_dir": str(run_dir), "host": socket.gethostname(), "now": time.strftime("%Y-%m-%d %H:%M:%S"), "trainer": trainer,
        "heartbeat_age": heartbeat_age, "stop_requested": (run_dir / "STOP").exists(), "started": processes.get("started"),
        "worker_count": max(0, len(processes.get("processes", [])) - 1), "workers": workers,
        "shards_waiting": len(list((run_dir / "shards").glob("*.shard"))) if (run_dir / "shards").exists() else 0,
        "checkpoints": checkpoints, "updates": len(rows), "hours": hours, "points": bucketed(shown),
        "changes": changes(rows, events), "summary": summary(rows, latest), "pace": pace(rows, latest),
        "last_update_age": now - rows[-1]["_t"] if rows else None,
        "benchmarks": benchmarks(run_dir), "best_benchmark": S.read_json(run_dir.parent / "benchmark" / "best.json"),
    }


def benchmarks(run_dir: Path, keep: int = 12) -> list[dict]:
    """The latest benchmark.py results (benchmark/history.jsonl next to the run folder): each brain's per-fight edge
    over the scripted brain on the fixed fights. Older lines without edges are skipped."""
    path = run_dir.parent / "benchmark" / "history.jsonl"
    if not path.exists():
        return []
    found = []
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if entry.get("edge"):
            found.append({"version": entry.get("version"), "time": entry.get("time"), "label": entry.get("label", ""),
                          "edge": entry["edge"]})
    return found[-keep:]


def lan_addresses() -> list[str]:
    """This computer's IPv4 addresses on its networks, for other computers to reach the dashboard."""
    try:
        addresses = socket.gethostbyname_ex(socket.gethostname())[2]
    except OSError:
        addresses = []
    return [a for a in addresses if not a.startswith("127.") and not a.startswith("169.254.")]


def serve(run_dir: Path, port: int, open_browser: bool, lan: bool = False) -> None:
    metrics = Metrics(run_dir / "logs" / "metrics.jsonl")

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802 - the standard library's name
            url = urlparse(self.path)
            if url.path == "/data":
                query = parse_qs(url.query)
                try:
                    hours = float(query.get("hours", ["0"])[0]) or None
                except ValueError:
                    hours = None
                focus = query.get("focus", ["0"])[0] == "1"
                body, kind = json.dumps(snapshot(run_dir, metrics, hours, focus)).encode("utf-8"), "application/json"
            elif url.path in ("/", "/index.html"):
                body, kind = PAGE.read_bytes(), "text/html; charset=utf-8"
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Type", kind)
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *_args) -> None:
            pass

    for candidate in range(port, port + 20):
        try:
            server = ThreadingHTTPServer(("0.0.0.0" if lan else "127.0.0.1", candidate), Handler)
            break
        except OSError:
            continue
    else:
        print(f"No free port from {port} to {port + 19}.")
        sys.exit(1)
    url = f"http://127.0.0.1:{server.server_address[1]}/"
    print(f"Training dashboard for {run_dir}", flush=True)
    print(f"Open {url} (close this window to stop the dashboard; training is not affected)", flush=True)
    if lan:
        chosen = server.server_address[1]
        for address in lan_addresses():
            print(f"From another computer on this network: http://{address}:{chosen}/", flush=True)
        print(f"Or by name: http://{socket.gethostname()}:{chosen}/", flush=True)
    if open_browser:
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--run-dir", type=Path)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--no-browser", action="store_true")
    parser.add_argument("--lan", action="store_true", help="also answer other computers on the local network")
    args = parser.parse_args()
    serve(args.run_dir or default_run_dir(), args.port, not args.no_browser, args.lan)
    return 0


if __name__ == "__main__":
    sys.exit(main())
