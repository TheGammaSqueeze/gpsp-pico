#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (c) 2026 TheGammaSqueeze
# gpsp-pico: build the gpSP core blob for the GammaOS LK (lk-mt6785, Konkr Pocket Advance).
#
#   ./build.sh            -> out/gpsp-pico.blob (copy it to the SD card as /cores/gpsp-pico.blob)
#   ./build.sh clean
#
# The upstream tree (submodule upstream/, libretro/gpsp) is never modified: it is copied to
# out/src, the patches in patches/ are applied there, and that copy is compiled together with
# the glue in pico/. Only gpSP's emulator core is built (cpu, the ARM dynarec, memory, video,
# sound, input, cheats); upstream's libretro.c, libco and the other platform backends are not.
#
# Target: the LK runs the core in 32 bit ARM state, soft float, with strict alignment (the
# flags the LK's own C code uses). The blob is self-contained: no C library, only libgcc, and
# the glue's own small libc (pico/blob_libc.c, pico/gba_shim.c).
#
# The flags, sources and link order are the ones the LK tree used to build core_gba.blob with
# (emu/gba/build_core_gba.sh and build_core_blob.sh); the output is byte-identical to it.
# Change them only on purpose.
set -euo pipefail
cd "$(dirname "$0")"
ROOT=$PWD
OUT=$ROOT/out
CC=${CC:-arm-none-eabi-gcc}
LD=${LD:-arm-none-eabi-ld}
OBJCOPY=${OBJCOPY:-arm-none-eabi-objcopy}

if [ "${1:-}" = clean ]; then rm -rf "$OUT"; exit 0; fi

if [ ! -f upstream/gba_memory.c ]; then
	git submodule update --init upstream
fi

UPSTREAM_REV=$(git -C upstream describe --tags --always 2>/dev/null || git -C upstream rev-parse --short HEAD)
PICO_REV=$(git describe --always --dirty 2>/dev/null || echo unknown)
VERSION="gpSP ${UPSTREAM_REV} (pico ${PICO_REV})"

rm -rf "$OUT/src" "$OUT/obj"
mkdir -p "$OUT/src" "$OUT/obj"
# copy the upstream tree without its git metadata (a file in a submodule checkout)
tar -C upstream --exclude=.git -cf - . | tar -C "$OUT/src" -xf -
# EXTRA_PATCHES: more patches for experiments, applied after these; releases use none
for p in patches/*.patch ${EXTRA_PATCHES:-}; do
	[ -e "$p" ] || continue
	echo ">> patch $(basename "$p")"
	case "$p" in /*) pp=$p;; *) pp=$ROOT/$p;; esac
	(cd "$OUT/src" && patch -p1 --quiet --forward < "$pp")
done

#   -DARM_ARCH -DHAVE_DYNAREC : the ARM dynamic recompiler (arm/arm_stub.S, arm/arm_emit.h)
#   -DHAVE_MMAP               : the translation caches are plain pointers (cpu_threaded.c) that
#                               gba_wrap.c points at fixed DRAM, instead of 11 MB of static arrays
#   -DGBA_LK_SMALL_CACHE      : 3.25 MB of translation caches (patch 0001), so they fit between
#                               0x4E000000 and the blob at 0x4E400000
#   -mno-unaligned-access     : the LK runs with strict alignment checking
#   -ffreestanding -fno-builtin: there is no C library; the blob carries its own few routines
FLAGS="-march=armv7-a -marm -mfloat-abi=soft -mno-unaligned-access \
	-ffreestanding -fno-builtin -fno-common -fno-short-enums -O2 \
	-DARM_ARCH -DHAVE_DYNAREC -DHAVE_MMAP -DGBA_LK_SMALL_CACHE \
	-I$OUT/src -I$OUT/src/arm"

# gpSP's core sources, then the dynarec's assembly dispatch
CORE="cpu cpu_threaded gba_memory main video sound input cheats"
for f in $CORE; do
	$CC $FLAGS -c "$OUT/src/$f.c" -o "$OUT/obj/$f.o"
done
$CC $FLAGS -c "$OUT/src/arm/arm_stub.S" -o "$OUT/obj/arm_stub.o"

# the glue: runtime shim and core bridge, then the interface exports and the libc
for f in gba_shim gba_wrap; do
	$CC $FLAGS -c "$ROOT/pico/$f.c" -o "$OUT/obj/$f.o"
done
for f in gba_core_exports blob_libc; do
	$CC $FLAGS -Wall -c "$ROOT/pico/$f.c" -o "$OUT/obj/$f.o"
done

# The link order is part of the output: objects in this order (sorted by name), then libgcc.
LINK="arm_stub blob_libc cheats cpu cpu_threaded gba_core_exports gba_memory gba_shim gba_wrap
	input main sound video"
OBJS=()
for f in $LINK; do OBJS+=("$OUT/obj/$f.o"); done
LIBGCC=$($CC $FLAGS -print-libgcc-file-name)

$LD -T "$ROOT/pico/blob.ld" -Map "$OUT/gpsp-pico.map" "${OBJS[@]}" "$LIBGCC" -o "$OUT/gpsp-pico.elf"
$OBJCOPY -O binary "$OUT/gpsp-pico.elf" "$OUT/gpsp-pico.blob"

python3 - "$OUT/gpsp-pico.blob" "$VERSION" <<'EOF'
import struct, sys, hashlib
d = open(sys.argv[1], 'rb').read()
magic, ver, entry, load, span = struct.unpack_from('<5I', d)
assert magic == 0x41424743 and ver == 2, "bad header"
assert load == len(d), "load size %d != file %d" % (load, len(d))
print("gpsp-pico.blob: %s" % sys.argv[2])
print("  file %d bytes, span %d bytes (%.2f MiB of the 4 MiB slot), entry +0x%x" % (len(d), span, span / 1048576.0, entry))
print("  sha256 %s" % hashlib.sha256(d).hexdigest())
EOF
