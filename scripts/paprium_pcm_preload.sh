#!/bin/bash
# MiSTer Scripts/ helper — full preload paprium.pcm into DDR @ 0x10000000
set -euo pipefail
PCM="${1:-/media/fat/games/MegaDrive/Paprium/paprium.pcm}"
BIN="/media/fat/Scripts/paprium_pcm_preload"
if [[ ! -x "$BIN" ]]; then
  echo "missing $BIN — copy the ARM binary built by scripts/build_pcm_preload.sh"
  exit 1
fi
exec "$BIN" "$PCM"
