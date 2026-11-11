# gpsp-pico

> **All of the emulation here is gpSP's.** gpSP (gameplaySP) was written by **Exophase** and is
> kept alive by the libretro team and its contributors at
> [libretro/gpsp](https://github.com/libretro/gpsp), among them **twinaphex**, **notaz**,
> **aliaspider**, **Autechre** and **David Guillen Fandos** (davidgfnet). If this core makes
> your games better, the credit is theirs.

[gpSP](https://github.com/libretro/gpsp), built as a loadable Game Boy Advance core for the
GammaOS bootloader emulator on the Konkr Pocket Advance (MediaTek MT6785, `lk-mt6785`, branch
`lk-gba-emu-sd-card-kpa`).

This repository adds no emulation code: it holds the upstream tree as a submodule, the small set
of patches the bootloader needs, the glue that lets gpSP run inside a bootloader with no
operating system, and a build script.

**This is an experimental project and does not accept issues.** Please do not report problems you
see with gpsp-pico to gpSP upstream either: this build runs gpSP in a bootloader on hardware
upstream does not target, from an older upstream commit, so its behaviour here says nothing about
gpSP itself.

## Credits

- **gpSP** (GPL-2.0-or-later): the Game Boy Advance emulator, its interpreter, its ARM dynamic
  recompiler, memory and save chip handling, renderer, sound and cheats. Originally gameplaySP by
  Exophase (2006); the libretro port and its many contributors since, see
  `git -C upstream shortlog -sn`.
- `arm/arm_codegen.h` and `arm/arm_dpimacros.h`, the ARM instruction encoders the recompiler
  emits with, are by Sergey Chaban and Wild West Software (MIT style licence, kept in the files).
- `libretro.h` is the libretro API header by the RetroArch team (MIT); the core still uses its
  input constants and callback types.

## License

gpSP is under the GNU General Public License, version 2 or (at your option) any later version.
The blob is a work based on gpSP, so it is distributed under the GPL as well: `LICENSE` is
upstream's `COPYING` (GPL version 2). The glue in `pico/`, the patches in `patches/` and
`build.sh` are GPL-2.0-or-later too. Each file keeps its own notice. The blob also links a few
libgcc helpers (GCC Runtime Library Exception); `THIRD_PARTY_NOTICES.md` lists everything.

Whoever passes the blob on must offer its complete source with it: this repository with the
upstream submodule at the recorded commit is that source, and `./build.sh` rebuilds the blob from
it bit for bit.

## Layout

| Path | What it is |
| --- | --- |
| `upstream/` | gpSP, as a git submodule at `300d0c0` (2021-02-15), never modified in place |
| `patches/` | changes to upstream, applied by `build.sh` to a copy in `out/src` |
| `pico/gba_wrap.c` | the bridge to the LK's GBA driver: arena layout, the per frame hand-off, input, audio, saves and states |
| `pico/gba_shim.c` | `__clear_cache` for the recompiler, `strtol`, file and time stubs, the cartridge clock |
| `pico/blob_libc.c` | the few C library routines the core calls, a bump heap, printf stubs |
| `pico/gba_core_exports.c` | the LK's core interface (`gba_core_abi.h`, version 2) filled in for gpSP |
| `pico/gba_core_abi.h` | a copy of `lk-mt6785/emu/gba/gba_core_abi.h`; the LK's copy is the reference |
| `pico/blob.ld` | link script: flat image, fixed address, 20 byte header |
| `build.sh` | builds `out/gpsp-pico.blob` |
| `THIRD_PARTY_NOTICES.md` | what is in the blob and under which licence |

### Upstream base

gpSP was copied into the LK tree (`emu/gba`, LK commit `d4e22ac`, 2026-08-24) without a record of
its upstream commit. Scoring every commit of libretro/gpsp against the copied files puts it at
`300d0c0` ("Merge pull request #93", 2021-02-15, the same tree as `ed3ba2c`): only five of the
copied files differ from it, by 87 lines, all of them the LK's own changes. Every difference the
blob is built from is in `patches/`. With them applied, every file the build compiles or includes
is identical to the LK's copy.

### Patches

| Patch | Why |
| --- | --- |
| `0001-lk-translation-cache-size.patch` | `cpu.h`: with `GBA_LK_SMALL_CACHE`, 3.25 MB of translation caches (2.5 MB ROM, 512 KB RAM, 256 KB BIOS) instead of the large default, so they fit at 0x4E000000 below the blob and stay within ARM BL's +-32 MB reach of the helpers the generated code calls. Without the define, upstream's sizes are unchanged. |
| `0002-arm-stub-cache-globals.patch` | `arm/arm_stub.S`: drops the `.globl` lines for `invalidate_icache_region` and `invalidate_cache_region`, which the file never defines (on ARM, `cpu_threaded.c` makes them no-ops and calls `__clear_cache`), so the object has no dangling undefined symbols. Carried because the LK's copy has it; the blob is the same bytes with or without it. |
| `0003-in-memory-loaders.patch` | `gba_memory.c`, `gba_memory.h`: the bootloader has no files. `load_gamepak_mem` and `load_bios_mem` do what `load_gamepak` and `load_bios` do (header, game config, save type detection) on an image already in memory; `init_gamepak_buffer_ext` and `gamepak_memory_map_size` put the 32 MB ROM buffer and its page map in memory the host gives, instead of `malloc`. |
| `0004-waitcnt-wait-states.patch` | `gba_memory.c`: a write to WAITCNT sets the cartridge's sequential wait states for the three ROM regions (`1 + {2,1}`, `{4,1}`, `{8,1}`, a 32 bit fetch two 16 bit accesses). Every game sets the faster waits at boot; charging the power on default for every ROM fetch made games run slower than the console and lag in heavy scenes. |
| `0005-light-state-load.patch` | `gba_memory.c`: with `g_gba_load_light` set (the LK sets it only around run ahead's per frame state load), loading a state keeps the ROM and BIOS translations, flushing only RAM code, and keeps the sound channels' sample pointers. Both are valid within one session of the same game, and resetting them every frame cost a full retranslate and played sustained PSG notes at the wrong pitch. |
| `0006-frame-boundary-finish.patch` | `main.c`: `gba_frame_boundary_finish` runs the tail of the vblank wrap (sound update, cheats, VCOUNT 0, the missing hblank) that a run ahead re-entry would skip, so each committed frame is exactly 280896 cycles. |
| `0007-sound-ring-snapshot.patch` | `sound.c`: `gba_sound_ring_save` and `gba_sound_ring_load` copy the audio ring, which save states do not hold, so run ahead's muted look-ahead frames leave the committed audio untouched. |

Upstream's `retro_emu_thread.c` was also edited in the LK copy (debug prints, a static argument
buffer). It is not built, by the LK or here, so those edits are not carried.

## Building

Needs `arm-none-eabi-gcc` and binutils (tested with 10.3-2021.07 and binutils 2.38, Ubuntu 22.04's
`gcc-arm-none-eabi`), `patch`, `python3` and git.

```
git clone --recurse-submodules <this repository>   # or: git submodule update --init upstream
./build.sh
```

Output: `out/gpsp-pico.blob`, plus the ELF and a link map. The script prints the size, how much of
the 4 MiB core slot it takes, and its SHA-256.

The flags are the LK's: ARMv7-A in 32 bit ARM state, soft float, no unaligned accesses (the LK
runs with alignment checking on), freestanding, `-O2`, gpSP's ARM recompiler. Sources, flags,
link order and link script are the ones the LK tree built `core_gba.blob` with, and the output is
byte-identical to it: with this toolchain the blob is 1014880 bytes, SHA-256
`9b28ce6b1638189f52631b747c8f4deee966091e728b65dd5545fe39e031ee59`, the same as the LK's
`emu/gba/core_gba.blob` at `ca3405f`. Nothing in the blob depends on where the tree is checked
out.

`EXTRA_PATCHES=/path/a.patch ./build.sh` applies more patches after `patches/` for experiments.
Releases use none.

## Installing

Copy `out/gpsp-pico.blob` to the SD card as `/cores/gpsp-pico.blob`.

## How the LK uses it

- The LK keeps only itself on the eMMC; the emulator cores live on the card in `/cores`. When a
  Game Boy Advance game runs on gpSP, the LK's `gba_core_load_file` (`emu/gba/gba_core_loader.c`,
  with `core_file.c`) opens `/cores/gpsp-pico.blob`, checks the header (magic `0x41424743`, a
  version from 2 to the newest the LK knows), checks that the entry, the image and the BSS fit
  the file and the 4 MiB GBA core slot at 0x4E400000, copies the image there, zeroes the BSS,
  cleans the data cache and invalidates the instruction cache over it, and calls the entry,
  `gba_core_blob_init`, with its table of imports.
- The entry returns the export table (`gba_core_exports` in `gba_core_abi.h`), and the LK's
  driver runs the game through it: `core_init` with the core's arena, `core_start` with the ROM
  it read into `rom_ptr` and the BIOS, the CPU loop on its own thread, the per frame calls, save
  states, battery saves and the run ahead hooks.
- armGBA-pico uses the same slot, so loading one GBA core replaces the other. For a missing or
  damaged file the loader gives a short reason (`core_file_error`).

## Target notes for maintainers

- **The interface.** `pico/gba_core_abi.h` is the contract with the LK. This blob is version 2:
  the version 1 table plus `skip_next_frame`, which the LK sets for frames it will not show (fast
  forward, run ahead's look-ahead) and `video.c` reads to leave out the drawing. The version 3
  fields (name, audio rate, state folder, options) are not provided; the LK reads them only when
  a core reports version 3. Keep the copy here identical to the LK's.
- **Imports.** The core calls out for three things: the audio sink, the wall clock for the
  cartridge RTC, and the yield at each vblank. `pico/gba_core_exports.c` defines those names in
  the blob and forwards each through the import table, so the core's own files need no edits.
- **Threads.** gpSP's CPU runs as a thread that yields to the frontend at every vblank
  (`switch_to_main_thread`). The LK runs `cpu_loop` on its own thread and resumes it once a frame;
  run ahead and resets re-enter it at a frame boundary.
- **Memory.** The translation caches are at the fixed address 0x4E000000 (3.25 MB, patch 0001),
  just below the blob at 0x4E400000: the recompiler emits direct BL calls from the caches to the
  blob's helpers, so they must stay within 32 MB of each other. Everything else is in the arena
  the LK passes to `core_init` (0x50000000): the 32 MB ROM buffer, the page map, the 240x160
  RGB565 screen, and a scratch tail the LK may use. `malloc` is a 256 KiB bump heap in the blob
  (`blob_libc.c`) for the few small allocations gpSP makes.
- **Cache maintenance.** `__clear_cache` (`gba_shim.c`) does range-scoped clean, invalidate, branch
  predictor invalidate and barriers over each block the recompiler writes. A whole I-cache
  invalidate per block made the translation-heavy start look like a hang.
- **Audio.** gpSP mixes at 65536 Hz stereo; the LK resamples to the codec.
- **Files.** The core still links its file-based loaders; the stubs in `gba_shim.c` satisfy the
  link and are never called. ROM, BIOS and saves move through memory only.
