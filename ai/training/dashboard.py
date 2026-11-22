"""A live training dashboard in the browser. Reads the run folder only, so it is safe while training runs.

  python dashboard.py [--run-dir <folder>] [--port 8765] [--no-browser]

Serves http://127.0.0.1:<port>/ (this computer only) and opens it. The page refreshes itself every 15 seconds.
Close the window running this script to stop the dashboard; training is not affected.
"""

from __future__ import annotations

import argparse
import json
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import safe_files as S

HERE = Path(__file__).resolve().parent
PAGE = HERE / "dashboard.html"
MAX_POINTS = 1500
FIELDS = ("samples", "version", "wipe_rate", "explore_found_rate", "explore_first_sight_s", "damage_to_party", "life_return",
          "entropy", "approx_kl", "clip_fraction", "value_loss", "learning_rate", "squad_mix", "replay_gap", "cleared", "timeout",
          "speed", "rows", "episodes")


def default_run_dir() -> Path:
    settings = json.loads((HERE / "training.json").read_text(encoding="utf-8"))
    configured = settings.get("run_dir") or ""
    return Path(configured) if configured else Path.home() / "Documents" / "Godot" / "mob-training" / "run"


class Metrics:
    """Reads metrics.jsonl as it grows, skipping a line cut short by a power loss."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.rows: list[dict] = []
        self.offset = 0
        self.lock = threading.Lock()

    def refresh(self) -> list[dict]:
        with self.lock:
            if not self.path.exists():
                return self.rows
            size = self.path.stat().st_size
            if size < self.offset:
                self.rows, self.offset = [], 0
            with self.path.open("rb") as source:
                source.seek(self.offset)
                chunk = source.read()
            end = chunk.rfind(b"\n") + 1
            self.offset += end
            last_time = self.rows[-1]["_t"] if self.rows else None
            last_samples = self.rows[-1]["samples"] if self.rows else 0
            for line in chunk[:end].splitlines():
                try:
                    row = json.loads(line)
                except ValueError:
                    continue
                stamp = time.mktime(time.strptime(row["time"], "%Y-%m-%d %H:%M:%S"))
                episodes = max(1, int(row.get("episodes", 0)))
                outcomes = row.get("outcomes", {})
                row["cleared"] = outcomes.get("cleared", 0) / episodes
                row["timeout"] = outcomes.get("timeout", 0) / episodes
                # Seconds since the previous update; minutes mean training was paused, which speed ignores.
                gap = stamp - last_time if last_time is not None else 0.0
                row["_gap"] = gap if 0 < gap < 120 else 0.0
                row["_new"] = row["samples"] - last_samples if row["_gap"] > 0 else 0
                row["_t"] = stamp
                last_time, last_samples = stamp, row["samples"]
                self.rows.append(row)
            return self.rows


def bucketed(rows: list[dict]) -> list[dict]:
    """At most MAX_POINTS points, each the mean of consecutive updates, so long runs stay quick to draw."""
    if not rows:
        return []
    size = max(1, -(-len(rows) // MAX_POINTS))
    points = []
    for start in range(0, len(rows), size):
        group = rows[start:start + size]
        point = {"time": group[-1]["time"]}
        for field in FIELDS:
            values = [r[field] for r in group if isinstance(r.get(field), (int, float)) and r.get(field) is not None
                      and not (field == "replay_gap" and r[field] < 0)]
            if field in ("samples", "version"):
                point[field] = group[-1].get(field)
            elif field == "speed":
                # Decisions over seconds across the whole group: log times only have whole seconds.
                seconds = sum(r["_gap"] for r in group)
                point[field] = sum(r["_new"] for r in group) / seconds if seconds >= 6 else None
            else:
                point[field] = sum(values) / len(values) if values else None
        points.append(point)
    return points


def snapshot(run_dir: Path, metrics: Metrics) -> dict:
    rows = metrics.refresh()
    checkpoints = []
    folder = run_dir / "checkpoints"
    for path in sorted(folder.glob("ckpt_*.pt"), key=S.checkpoint_version) + sorted((folder / "milestones").glob("ckpt_*.pt"), key=S.checkpoint_version):
        checkpoints.append({"name": path.name, "version": S.checkpoint_version(path), "milestone": path.parent.name == "milestones",
                            "time": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(path.stat().st_mtime))})
    workers = []
    for path in sorted((run_dir / "workers").glob("w*.json")):
        progress = S.read_json(path)
        if progress:
            workers.append(progress)
    processes = S.read_json(run_dir / "processes.json") or {}
    trainer = S.read_json(run_dir / "trainer.json") or {}
    heartbeat_age = None
    if trainer.get("time"):
        heartbeat_age = time.time() - time.mktime(time.strptime(trainer["time"], "%Y-%m-%d %H:%M:%S"))
    return {
        "run_dir": str(run_dir), "now": time.strftime("%Y-%m-%d %H:%M:%S"), "trainer": trainer, "heartbeat_age": heartbeat_age,
        "stop_requested": (run_dir / "STOP").exists(), "started": processes.get("started"),
        "worker_count": len(processes.get("processes", [])) - 1 if processes else 0, "workers": workers,
        "shards_waiting": len(list((run_dir / "shards").glob("*.shard"))) if (run_dir / "shards").exists() else 0,
        "checkpoints": checkpoints, "updates": len(rows), "points": bucketed(rows),
        "latest": {k: v for k, v in rows[-1].items() if not k.startswith("_") and k != "speed"} if rows else None,
    }


def serve(run_dir: Path, port: int, open_browser: bool) -> None:
    metrics = Metrics(run_dir / "logs" / "metrics.jsonl")

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802 - the standard library's name
            if self.path.startswith("/data"):
                body, kind = json.dumps(snapshot(run_dir, metrics)).encode("utf-8"), "application/json"
            elif self.path in ("/", "/index.html"):
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
            server = ThreadingHTTPServer(("127.0.0.1", candidate), Handler)
            break
        except OSError:
            continue
    else:
        print(f"No free port from {port} to {port + 19}.")
        sys.exit(1)
    url = f"http://127.0.0.1:{server.server_address[1]}/"
    print(f"Training dashboard for {run_dir}")
    print(f"Open {url} (close this window to stop the dashboard; training is not affected)")
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
    args = parser.parse_args()
    serve(args.run_dir or default_run_dir(), args.port, not args.no_browser)
    return 0


if __name__ == "__main__":
    sys.exit(main())
