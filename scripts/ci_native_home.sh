#!/usr/bin/env bash
set -euo pipefail

# Run only inside xvfb-run on a temporary public CI runner. The app is given an
# in-memory procedural catalog and no preference folder; no user files are read.
app="$1"
out="$2"
mkdir -p "$out"
export LIGHTCRAFT_GPU_BACKEND=glow
export LIGHTCRAFT_GPU=0
export LIGHTCRAFT_NO_PREFS=1
export RUST_BACKTRACE=1
"$app" --memory >"$out/desktop.log" 2>&1 &
app_pid=$!
trap 'kill "$app_pid" 2>/dev/null || true; wait "$app_pid" 2>/dev/null || true' EXIT

found=0
for _ in $(seq 1 60); do
    if ! kill -0 "$app_pid" 2>/dev/null; then
        cat "$out/desktop.log"
        echo "LightStrike desktop exited before opening a window" >&2
        exit 1
    fi
    if xwininfo -root -tree | grep -q 'LightStrike'; then
        found=1
        break
    fi
    sleep 0.5
done
if [ "$found" != 1 ]; then
    cat "$out/desktop.log"
    echo "LightStrike desktop window was not found on Xvfb" >&2
    exit 1
fi

# X11 registers the window before the procedural catalog finishes opening.
# Allow that work and the 1.2-second introduction to finish before capturing.
sleep 12
if ! kill -0 "$app_pid" 2>/dev/null; then
    cat "$out/desktop.log"
    echo "LightStrike desktop exited before the workspace capture" >&2
    exit 1
fi
scrot -z "$out/native-home.png"
python3 - "$out/native-home.png" <<'PY'
from pathlib import Path
import struct
import sys
image = Path(sys.argv[1]).read_bytes()
assert image.startswith(b"\x89PNG\r\n\x1a\n") and image[12:16] == b"IHDR"
assert struct.unpack(">II", image[16:24]) == (1280, 800)
print("Native Xvfb desktop screenshot: 1280x800")
PY
