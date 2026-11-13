#!/usr/bin/env bash
# One launcher implementation prevents Windows/Unix result and timeout drift.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PWSH_BIN="${PWSH:-pwsh}"
if ! command -v "$PWSH_BIN" >/dev/null 2>&1; then
    echo "PowerShell 7 is required for this wrapper. Set PWSH or run run_net_test.ps1 directly." >&2
    exit 3
fi
args=(-NoLogo -NoProfile -File "$SCRIPT_DIR/run_net_test.ps1"
      -Clients "${CLIENTS:-3}" -Port "${PORT:-24600}" -PlayMs "${PLAY_MS:-2500}"
      -TimeoutMs "${TIMEOUT_MS:-20000}" -HostFps "${HOST_FPS:-60}" -GuestFps "${GUEST_FPS:-240}"
      -Role "${ROLE:-All}" -Index "${INDEX:-0}" -Address "${ADDRESS:-127.0.0.1}")
[[ -z "${GODOT:-}" ]] || args+=(-Godot "$GODOT")
[[ -z "${RUN_ID:-}" ]] || args+=(-RunId "$RUN_ID")
[[ -z "${PACK:-}" ]] || args+=(-Pack "$PACK")
exec "$PWSH_BIN" "${args[@]}" "$@"
