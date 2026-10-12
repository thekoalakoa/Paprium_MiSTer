#!/usr/bin/env bash
# Build the Paprium MCU firmware for the MiSTer core: krikzz's mega-ppm at its pinned commit +
# patches/mega-ppm-pocket.patch, linked with scripts/firmware/paprium_mcu.ld and split into the four
# memory init files the RTL reads:
#
#   rtl/PAPRIUM/mcu.txt       IROM rom0, 32 KB          ($readmemh in rtl/PAPRIUM/mcu_core.sv)
#   rtl/PAPRIUM/mcu_ext.txt   IROM extension, 22 KB     ($readmemh in rtl/PAPRIUM/mcu_core.sv)
#   rtl/PAPRIUM/wram_hi.txt   WRAM even bytes           ($readmemh in rtl/PAPRIUM/memory.sv)
#   rtl/PAPRIUM/wram_lo.txt   WRAM odd bytes            ($readmemh in rtl/PAPRIUM/memory.sv)
#
# Usage:
#   ./scripts/build_mcu.sh --brain DIR [--mega-ppm DIR] [--gcc-bin DIR] [--out DIR] [--no-install] [--any-brain]
#
#   --brain DIR     (required) a folder holding the CPU MATE brain from the release download
#                   cpu-mate-brain_0.2.6.zip: brain.bin, cf.bin and rodata.bin. The MiSTer firmware has no
#                   build without the brain, so the four init files are not in the repository at all.
#   --any-brain     accept brain files whose md5s are not the 0.2.6 ones (the entry table in
#                   zz_buddy_brain.c belongs to that exact brain build, so expect trouble)
#   --mega-ppm DIR  a git clone of https://github.com/krikzz/mega-ppm (default: ../repos/mega-ppm next to
#                   this repository, or $MEGA_PPM). Only the pinned commit is read, with git archive: the
#                   clone's working tree and branch do not matter and are never modified.
#   --gcc-bin DIR   the bin folder of the xPack riscv-none-elf GCC 15.2.0 toolchain (default: $RISCV_GCC_BIN,
#                   then riscv-none-elf-gcc on PATH, then ../tools/xpack-riscv-none-elf-gcc-15.2.0-1/bin)
#   --out DIR       build folder (default: build_output/mcu-release, git-ignored)
#   --no-install    do not copy the four images into rtl/PAPRIUM/
#
# The four images contain the brain, so they are git-ignored: never commit them. See docs/firmware/README.md.
#
# Needs: bash, git, tar, python 3, and the toolchain above. Git Bash on Windows works.
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FW_DIR="$SCRIPT_DIR/firmware"
PATCH="$PROJECT_DIR/patches/mega-ppm-pocket.patch"

MEGA_PPM_COMMIT=84be6bdd0bff18bf143d9ab3cc7267a5954d5a70
PREFIX=riscv-none-elf
EXT_KB=22

# the CPU MATE brain of the 0.2.6 release download
BRAIN_FILES="brain.bin cf.bin rodata.bin"
BRAIN_MD5_brain=1b64e14d710e8768d3385d1421162bc7
BRAIN_MD5_cf=a5fa37b435f26f9fc2c8fd62d218d7ef
BRAIN_MD5_rodata=5b1d74f454b578196ed1e82548f01b99

# image md5s (mcu.txt mcu_ext.txt wram_hi.txt wram_lo.txt, as written: CRLF lines)
# image md5s of the MiSTer 0.2.6 RELEASE firmware (mcu.txt mcu_ext.txt wram_hi.txt wram_lo.txt, LF lines)
KNOWN_release_brain="47644152a84ef5ca2333037ebbd1d9c4 4c23775c3b728107ca4985a07e1af6a2 3fe6acc44730cfc1d94dfe4d942bbf95 256d3b2a941f985117c50907f4becc0a"

VARIANT=release
BRAIN_DIR=""
ANY_BRAIN=0
MEGA_PPM="${MEGA_PPM:-$PROJECT_DIR/../repos/mega-ppm}"
GCC_BIN="${RISCV_GCC_BIN:-}"
OUT=""
INSTALL=1

usage() { sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --brain)      [ $# -ge 2 ] || die "--brain needs a folder"; BRAIN_DIR="$2"; shift ;;
        --any-brain)  ANY_BRAIN=1 ;;
        --mega-ppm)   [ $# -ge 2 ] || die "--mega-ppm needs a folder"; MEGA_PPM="$2"; shift ;;
        --gcc-bin)    [ $# -ge 2 ] || die "--gcc-bin needs a folder"; GCC_BIN="$2"; shift ;;
        --out)        [ $# -ge 2 ] || die "--out needs a folder"; OUT="$2"; shift ;;
        --no-install) INSTALL=0 ;;
        -h|--help)    usage; exit 0 ;;
        *)            usage >&2; die "unknown argument: $1" ;;
    esac
    shift
done

# ---------------------------------------------------------------- tools
PY=""
for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(sys.version_info < (3, 6))' >/dev/null 2>&1; then
        PY="$c"; break
    fi
done
[ -n "$PY" ] || die "python 3 not found"
md5() { "$PY" -I -B -c 'import hashlib, sys; print(hashlib.md5(open(sys.argv[1], "rb").read()).hexdigest())' "$1"; }

if [ -z "$GCC_BIN" ]; then
    if command -v "$PREFIX-gcc" >/dev/null 2>&1; then
        GCC_BIN="$(dirname "$(command -v "$PREFIX-gcc")")"
    else
        GCC_BIN="$PROJECT_DIR/../tools/xpack-riscv-none-elf-gcc-15.2.0-1/bin"
    fi
fi
[ -x "$GCC_BIN/$PREFIX-gcc" ] || [ -x "$GCC_BIN/$PREFIX-gcc.exe" ] || \
    die "toolchain not found in $GCC_BIN (get xPack riscv-none-elf-gcc 15.2.0, or pass --gcc-bin)"
export PATH="$GCC_BIN:$PATH"
GCC_VER="$($PREFIX-gcc --version | head -1)"
case "$GCC_VER" in
    *15.2.0*) ;;
    *) echo "warning: $GCC_VER - the shipped images were built with xPack GCC 15.2.0; other versions give other md5s" >&2 ;;
esac

[ -f "$PATCH" ] || die "missing $PATCH"
[ -d "$MEGA_PPM" ] || die "no mega-ppm clone at $MEGA_PPM
  git clone https://github.com/krikzz/mega-ppm.git \"$MEGA_PPM\"   (or pass --mega-ppm DIR)"
git -C "$MEGA_PPM" cat-file -e "$MEGA_PPM_COMMIT^{commit}" 2>/dev/null || \
    die "$MEGA_PPM does not have commit $MEGA_PPM_COMMIT (git -C \"$MEGA_PPM\" fetch origin)"

# ---------------------------------------------------------------- the brain (optional)
if [ -n "$BRAIN_DIR" ]; then
    [ -d "$BRAIN_DIR" ] || die "--brain: no folder $BRAIN_DIR"
    BRAIN_DIR="$(cd "$BRAIN_DIR" && pwd)"
    for f in $BRAIN_FILES; do
        [ -f "$BRAIN_DIR/$f" ] || die "--brain: $BRAIN_DIR has no $f (expected: $BRAIN_FILES)"
        want="BRAIN_MD5_${f%.bin}"
        got="$(md5 "$BRAIN_DIR/$f")"
        if [ "$got" != "${!want}" ]; then
            [ "$ANY_BRAIN" = 1 ] || die "--brain: $f md5 $got, the 0.2.6 brain is ${!want} (--any-brain to build anyway)"
            echo "warning: $f md5 $got is not the 0.2.6 brain (${!want})" >&2
        fi
    done
    KIND=brain
else
    usage >&2; die "--brain <folder> is required (the CPU MATE brain from cpu-mate-brain_0.2.6.zip)"
fi

[ -n "$OUT" ] || OUT="$PROJECT_DIR/build_output/mcu-$VARIANT"
# the build folder is emptied first, but only if it is empty already or one of ours (marker file): a mistyped --out
# must never wipe someone's folder
MARK=.build_mcu-output
if [ -d "$OUT" ] && [ -n "$(ls -A "$OUT")" ] && [ ! -f "$OUT/$MARK" ]; then
    die "--out $OUT is a non-empty folder that build_mcu.sh did not make; give an empty or new folder"
fi
rm -rf "$OUT"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
echo "made by scripts/build_mcu.sh; the whole folder is deleted by the next build into it" > "$OUT/$MARK"
SRC="$OUT/src"
OBJ="$OUT/obj"
mkdir -p "$SRC" "$OBJ"

echo "variant:   $VARIANT, with the CPU MATE brain ($BRAIN_DIR)"
echo "toolchain: $GCC_VER"
echo "mega-ppm:  $MEGA_PPM @ ${MEGA_PPM_COMMIT:0:7}"
echo "out:       $OUT"
echo

# ---------------------------------------------------------------- source = pinned mega-ppm + our patch
# git archive of the commit itself (LF, whatever the clone's checkout settings), then the patch with any CRs a
# Windows checkout added taken out again. The source tree is its own (throwaway) repository, so git apply works on
# it and not on a repository around the build folder.
git -C "$MEGA_PPM" -c core.autocrlf=false archive "$MEGA_PPM_COMMIT" mcu | tar -x -C "$SRC"
tr -d '\r' < "$PATCH" > "$OUT/mega-ppm-pocket.patch"
(
    cd "$SRC"
    git init -q .
    git -c core.autocrlf=false -c core.safecrlf=false apply --whitespace=nowarn "$OUT/mega-ppm-pocket.patch"
)
MCU="$SRC/mcu"
LIB="$MCU/lib"

# ---------------------------------------------------------------- compile and link (as mega-ppm's Makefile, plus
# the switches below; Git Bash has no make)
# GCC 15 split CSR and FENCE.I out of the base ISA, so they are named explicitly: krikzz's Makefile says plain rv32im.
CC_OPTS="-march=rv32im_zicsr_zifencei -mabi=ilp32 -O2 -Wall -ffunction-sections -fdata-sections -nostartfiles"
CC_OPTS="$CC_OPTS -Wl,--gc-sections -lm -lc -lgcc -lc"
CC_OPTS="$CC_OPTS -falign-functions=4 -falign-labels=4 -falign-loops=4 -falign-jumps=4"
CC_OPTS="$CC_OPTS -Wno-pointer-sign -DBUDDY_STUB_BRAIN=0"
CC_OPTS="$CC_OPTS -DBUDDY_LINKED_BRAIN=1 -DBUDDY_TRAP_TRAMP=1 -DPPM_RELEASE=1"
for f in $BRAIN_FILES; do cp "$BRAIN_DIR/$f" "$OBJ/$f"; done      # zz_buddy_brain.c .incbin's them from here

# link order = the shipped build's: the app in name order, then the NEORV32 runtime, then crt0
SRCS=()
for f in everdrive.c main.c mame.c mdp.c paprium.c sfx.c zz_buddy.c zz_buddy_brain.c zz_buddy_trap.c; do
    SRCS+=("$MCU/$f")
done
for f in "$LIB"/source/*.c; do SRCS+=("$f"); done
if ! (
    cd "$OBJ" || exit 1          # (set -e is off inside an if condition: every step checks itself)
    OBJS=()
    for f in "${SRCS[@]}"; do
        o="$(basename "$f").o"
        $PREFIX-gcc -c $CC_OPTS -I "$LIB/include" -I "$MCU" "$f" -o "$o" || exit 1
        OBJS+=("$o")
    done
    # vu_due / vu_on are static in paprium.c; the CPU MATE glue reads them, so they are made global in the object
    # (no recompile: paprium.c's code is unchanged)
    $PREFIX-objcopy --globalize-symbol=vu_due --globalize-symbol=vu_on paprium.c.o || exit 1
    $PREFIX-gcc -c $CC_OPTS -I "$LIB/include" -I "$MCU" "$LIB/common/crt0.S" -o crt0.S.o || exit 1
    OBJS+=(crt0.S.o)
    $PREFIX-gcc $CC_OPTS -T "$FW_DIR/paprium_mcu.ld" "${OBJS[@]}" -o main.elf -Wl,-Map,main.map || exit 1
) > "$OUT/compile.log" 2>&1; then
    grep -E -i 'error|undefined|overlap|runs into|overflows' "$OUT/compile.log" | head -40 >&2 || true
    die "build failed, see $OUT/compile.log"
fi
echo "compiler warnings: $(grep -c 'warning:' "$OUT/compile.log" || true) (full text in compile.log)"

$PREFIX-size -A "$OBJ/main.elf" | grep -v -E "debug|comment|attributes" > "$OUT/size.txt"
$PREFIX-nm -n -S "$OBJ/main.elf" > "$OUT/main.nm"
"$PY" -I -B "$FW_DIR/mkimage.py" "$OBJ/main.elf" "$OUT/img" --ext-kb "$EXT_KB" > "$OUT/image.txt"

# ---------------------------------------------------------------- report
IMGS="mcu.txt mcu_ext.txt wram_hi.txt wram_lo.txt"
GOT=""
echo
for f in $IMGS; do
    m="$(md5 "$OUT/img/$f")"
    GOT="$GOT${GOT:+ }$m"
    printf '  %-12s %s\n' "$f" "$m"
done
"$PY" -I -B -c 'import json, sys
r = json.load(open(sys.argv[1]))
print("  rom image %d B: rom0 %d of 32768 B, extension %d of %d B; WRAM code window %d B" % (
    r["rom_bytes"], r["rom0_used"], r["ext_used"], r["ext_bytes"], r["wram_code_bytes"]))' "$OUT/img/image.json"
KNOWN_VAR="KNOWN_${VARIANT}_${KIND}"
if [ "$GOT" = "${!KNOWN_VAR}" ]; then
    echo "  = the shipped MiSTer 0.2.6 RELEASE firmware, byte for byte"
else
    echo "  (not a known 0.2.6 image set: the source, the patch, the brain or the toolchain differ)"
fi

# ---------------------------------------------------------------- install
# Quartus reads rtl/PAPRIUM/*.txt, never build_output/. A build that is not installed changes nothing.
if [ "$INSTALL" = 1 ]; then
    for f in $IMGS; do cp -f "$OUT/img/$f" "$PROJECT_DIR/rtl/PAPRIUM/$f"; done
    echo
    echo "installed -> rtl/PAPRIUM/{mcu,mcu_ext,wram_hi,wram_lo}.txt (what Quartus reads)"
    echo
    echo "  These images CONTAIN THE CPU MATE BRAIN. They are git-ignored; never commit them."
else
    echo
    echo "not installed (--no-install): rtl/PAPRIUM/ is unchanged"
fi
