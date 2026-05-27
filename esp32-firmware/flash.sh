#!/usr/bin/env bash
# flash.sh — Compile + flash ESP32 via USB (env: esp32dev)
#
# Usage:
#   ./flash.sh              # auto-detect port, flash only
#   ./flash.sh -m           # flash + open serial monitor after
#   ./flash.sh -p /dev/ttyUSB1   # specify port explicitly
#   ./flash.sh -p /dev/ttyUSB1 -m
#
# Requirements:
#   - PlatformIO CLI  ($HOME/.platformio/penv/bin must be in PATH, or installed globally)
#   - User in 'dialout' group  (sudo usermod -aG dialout $USER, then re-login)
#   - ESP32 connected via USB

set -euo pipefail

# ── PlatformIO path ────────────────────────────────────────────────────────────
export PATH="$HOME/.platformio/penv/bin:$PATH"

# ── Defaults ───────────────────────────────────────────────────────────────────
PORT=""
MONITOR=false
ENV="esp32dev"

# ── Args ───────────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--port)    PORT="$2"; shift 2 ;;
    -m|--monitor) MONITOR=true;  shift ;;
    -h|--help)
      sed -n '2,12p' "$0"   # print the usage block above
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Auto-detect port if not provided ──────────────────────────────────────────
if [[ -z "$PORT" ]]; then
  # Prefer /dev/serial/by-id symlinks (stable names)
  FOUND=$(ls /dev/serial/by-id/ 2>/dev/null | head -1)
  if [[ -n "$FOUND" ]]; then
    PORT=$(readlink -f "/dev/serial/by-id/$FOUND")
  else
    # Fallback: first ttyUSB or ttyACM
    PORT=$(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | head -1 || true)
  fi
fi

if [[ -z "$PORT" ]]; then
  echo "❌  No serial port found. Is the ESP32 plugged in?"
  echo "    Run:  ls /dev/ttyUSB* /dev/ttyACM*"
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ESP32 Flash"
echo "  Port : $PORT"
echo "  Env  : $ENV"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Kill any process holding the port (e.g. serial monitor) ──────────────────
if command -v fuser &>/dev/null && fuser "$PORT" &>/dev/null 2>&1; then
  echo "⚠️   Port $PORT is busy — killing holder..."
  fuser -k "$PORT" || true
  sleep 0.5
fi

# ── Flash ─────────────────────────────────────────────────────────────────────
pio run \
  --environment "$ENV" \
  --target upload \
  --upload-port "$PORT"

echo ""
echo "✅  Flash complete"

# ── Monitor (optional) ────────────────────────────────────────────────────────
if [[ "$MONITOR" == true ]]; then
  echo "📡  Opening serial monitor on $PORT (Ctrl-C to exit)..."
  echo ""
  pio device monitor --port "$PORT" --baud 115200
fi
