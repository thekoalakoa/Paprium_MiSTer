#!/bin/bash
# Build paprium_pcm_preload for the MiSTer ARM HPS (run on DE10, or cross-gcc).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-$ROOT/paprium_pcm_preload}"
CC="${CC:-gcc}"
$CC -O2 -Wall -o "$OUT" "$ROOT/paprium_pcm_preload.c"
echo "built: $OUT"
