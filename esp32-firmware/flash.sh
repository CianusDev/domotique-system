#!/usr/bin/env bash
# flash.sh — ESP32 tool: flash, flash + monitor, or full erase
#
# Usage:
#   ./flash.sh              # interactive menu
#   ./flash.sh -p /dev/ttyUSB1   # specify port, then interactive menu
#
# Requirements:
#   - PlatformIO CLI  ($HOME/.platformio/penv/bin in PATH)
#   - User in 'dialout' group

set -euo pipefail

# ── PlatformIO path ────────────────────────────────────────────────────────────
export PATH="$HOME/.platformio/penv/bin:$PATH"

ENV="esp32dev"

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
CYN='\033[0;36m'
BLD='\033[1m'
RST='\033[0m'

# ── Args (optional port override) ─────────────────────────────────────────────
PORT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--port) PORT="$2"; shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Auto-detect port ──────────────────────────────────────────────────────────
if [[ -z "$PORT" ]]; then
  FOUND=$(ls /dev/serial/by-id/ 2>/dev/null | head -1)
  if [[ -n "$FOUND" ]]; then
    PORT=$(readlink -f "/dev/serial/by-id/$FOUND")
  else
    PORT=$(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null | head -1 || true)
  fi
fi

if [[ -z "$PORT" ]]; then
  echo -e "${RED}❌  No serial port found. Is the ESP32 plugged in?${RST}"
  echo    "    Run:  ls /dev/ttyUSB* /dev/ttyACM*"
  exit 1
fi

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLD}╔══════════════════════════════════════════╗${RST}"
echo -e "${BLD}║         ESP32 — Domotique Tool           ║${RST}"
echo -e "${BLD}╠══════════════════════════════════════════╣${RST}"
echo -e "${BLD}║${RST}  Port : ${CYN}${PORT}${RST}"
echo -e "${BLD}║${RST}  Env  : ${CYN}${ENV}${RST}"
echo -e "${BLD}╠══════════════════════════════════════════╣${RST}"
echo -e "${BLD}║${RST}  ${BLD}1)${RST} Flash"
echo -e "${BLD}║${RST}  ${BLD}2)${RST} Flash + ouvrir monitor série"
echo -e "${BLD}║${RST}  ${BLD}3)${RST} ${RED}Effacer complètement la mémoire flash${RST}"
echo -e "${BLD}║${RST}  ${BLD}q)${RST} Quitter"
echo -e "${BLD}╚══════════════════════════════════════════╝${RST}"
echo ""
read -rp "  Choix : " CHOICE
echo ""

# ── Helper: kill port holder ──────────────────────────────────────────────────
free_port() {
  if command -v fuser &>/dev/null && fuser "$PORT" &>/dev/null 2>&1; then
    echo -e "${YLW}⚠️  Port occupé — libération en cours...${RST}"
    fuser -k "$PORT" || true
    sleep 0.5
  fi
}

# ── Actions ───────────────────────────────────────────────────────────────────
case "$CHOICE" in

  # ── 1 : Flash ───────────────────────────────────────────────────────────────
  1)
    free_port
    echo -e "${CYN}⬆️  Compilation + flash sur $PORT...${RST}"
    echo ""
    pio run \
      --environment "$ENV" \
      --target upload \
      --upload-port "$PORT"
    echo ""
    echo -e "${GRN}✅  Flash terminé.${RST}"
    ;;

  # ── 2 : Flash + monitor ─────────────────────────────────────────────────────
  2)
    free_port
    echo -e "${CYN}⬆️  Compilation + flash sur $PORT...${RST}"
    echo ""
    pio run \
      --environment "$ENV" \
      --target upload \
      --upload-port "$PORT"
    echo ""
    echo -e "${GRN}✅  Flash terminé.${RST}"
    echo ""
    echo -e "${CYN}📡  Monitor série ouvert sur $PORT — Ctrl-C pour quitter${RST}"
    echo ""
    pio device monitor --port "$PORT" --baud 115200
    ;;

  # ── 3 : Erase ───────────────────────────────────────────────────────────────
  3)
    echo -e "${RED}${BLD}⚠️  ATTENTION${RST}"
    echo    "   Efface TOUTE la mémoire flash : firmware + NVS (WiFi, device ID)."
    echo    "   L'ESP32 devra être re-flashé et re-provisionné via BLE."
    echo ""
    read -rp "  Confirmer ? (oui/N) : " CONFIRM
    echo ""
    if [[ "$CONFIRM" != "oui" ]]; then
      echo "  Annulé."
      exit 0
    fi
    free_port
    echo -e "${RED}🗑️  Effacement complet de la flash...${RST}"
    echo ""
    # esptool.py livré avec PlatformIO (pas dans le PATH standard)
    ESPTOOL="$HOME/.platformio/packages/tool-esptoolpy/esptool.py"
    if [[ ! -f "$ESPTOOL" ]]; then
      echo -e "${RED}❌  esptool.py introuvable : $ESPTOOL${RST}"
      exit 1
    fi
    python3 "$ESPTOOL" --chip esp32 --port "$PORT" --baud 921600 erase_flash
    echo ""
    echo -e "${GRN}✅  Flash effacée. Re-flasher avec l'option 1 ou 2.${RST}"
    ;;

  # ── Quitter ─────────────────────────────────────────────────────────────────
  q|Q|"")
    echo "  Bye."
    exit 0
    ;;

  *)
    echo -e "${RED}❌  Choix invalide.${RST}"
    exit 1
    ;;

esac
