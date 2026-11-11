# Third party notices

The gpsp-pico blob (`gpsp-pico.blob`) is built from the following. Everything in it is under the
GNU General Public License, version 2 or later, except the parts listed with their own permissive
licences below, which only ask for their notices to be kept and are compatible with the GPL.

## gpSP (GPL-2.0-or-later)

- Source: <https://github.com/libretro/gpsp>, the `upstream/` submodule, at the commit recorded in
  this repository (`300d0c0028e400eabd81dc718ee8cd8c6459b256`).
- Copyright (C) 2006 Exophase, and the libretro gpSP contributors (`git -C upstream shortlog -sn`).
  The licence text is upstream's `COPYING`, which is this repository's `LICENSE`.
- Compiled: `cpu.c`, `cpu_threaded.c`, `gba_memory.c`, `main.c`, `video.c`, `sound.c`, `input.c`,
  `cheats.c` and `arm/arm_stub.S`, with the headers they include (among them `gba_over.h`, the
  per game settings), after the patches in `patches/`. Upstream's libretro frontend
  (`libretro.c`), libco, its other platform backends and its tools are not built.

### Files inside gpSP under other licences

- `arm/arm_codegen.h`, `arm/arm_dpimacros.h`: Copyright (c) 2002 Wild West Software, Copyright (c)
  2001, 2002 Sergey Chaban. MIT style licence, the full text is at the top of each file. They are
  headers the recompiler's code emitter is built from.
- `libretro.h`: Copyright (C) 2010-2020 The RetroArch team. MIT licence, the full text is at the
  top of the file. Only its constants and types are used.

## This repository (GPL-2.0-or-later)

The glue in `pico/`, the patches in `patches/` and `build.sh`: Copyright (c) 2026 TheGammaSqueeze,
GPL-2.0-or-later. `pico/gba_core_abi.h` is a copy of the interface header of the GammaOS LK
(lk-mt6785) by the same author, provided here under the same terms.

The civil date conversion in `pico/gba_shim.c` (`localtime`) follows Howard Hinnant's published
days-to-civil algorithm (public domain).

## The C runtime linked into the blob

- **No C library.** The blob carries its own few C routines (`pico/blob_libc.c`,
  `pico/gba_shim.c`); newlib is not linked.
- **libgcc** (the GCC project): the soft float helpers (`_arm_addsubdf3`, `_arm_addsubsf3`,
  `_arm_muldf3`, `_arm_mulsf3`, `_arm_muldivdf3`, `_arm_muldivsf3`, `_arm_fixunsdfsi`,
  `_arm_fixunssfsi`) and integer division (`_divsi3`, `_dvmd_tls`), as the link map
  `out/gpsp-pico.map` lists them. GPL-3.0 with the GCC Runtime Library Exception, which places
  no conditions on the compiled blob.

## Corresponding source

The GPL asks that whoever receives the blob can obtain its complete source. That is this
repository with the upstream submodule at the recorded commit; `./build.sh` rebuilds the blob
from it, byte for byte with the same toolchain.
