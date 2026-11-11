/* SPDX-License-Identifier: GPL-2.0-or-later
 * Copyright (c) 2026 TheGammaSqueeze */
/* gpsp-pico: link script for the loadable core blob (see gba_core_abi.h).
 *
 * The blob is a flat binary linked at a FIXED DRAM VMA in the k85v1_64 WB window
 * [0x4E000000,0x56000000): the LK's GBA core slot at 0x4E400000, the same slot
 * armGBA-pico uses (loading one core replaces the other). It sits above the gpSP JIT
 * caches (0x4E000000, 3.25 MB, see gba_wrap.c) and below the core arena (0x50000000,
 * 64 MB). Being this close keeps the core's helper functions within ARM BL's +-32 MB
 * reach of the JIT caches (the dynarec emits direct BLs from generated code in the
 * caches to those helpers), which is the constraint that forbids the far arena. The
 * LK reads the image from the card to this VMA, zeroes [load_size, total_span),
 * cleans and invalidates the caches over it, then calls the entry.
 *
 * Header (image offset 0, 20 bytes):
 *   u32 magic      = 0x41424743 (GBA_CORE_ABI_MAGIC)
 *   u32 version    = 2 (GBA_CORE_ABI_VERSION; the LK accepts 2 to GBA_CORE_ABI_MAX)
 *   u32 entry      = offset of gba_core_blob_init from the image start
 *   u32 load_size  = bytes present in the file
 *   u32 total_span = load_size plus the BSS to zero
 */
ENTRY(gba_core_blob_init)

BLOB_VMA = 0x4E400000;

SECTIONS
{
	. = BLOB_VMA;

	.header : {
		LONG(0x41424743);                    /* [0] magic "GCBA" */
		LONG(2);                             /* [1] version */
		LONG(gba_core_blob_init - BLOB_VMA); /* [2] entry offset */
		LONG(__blob_load_end - BLOB_VMA);    /* [3] load_size: bytes present in the file */
		LONG(__blob_end - BLOB_VMA);         /* [4] total_span: zero [load_size, total_span] */
	}

	.text : { *(.text .text.*) }
	.rodata : { *(.rodata .rodata.*) }
	.data : { *(.data .data.*) }

	. = ALIGN(16);
	__blob_load_end = .;               /* end of bytes present in the flat image */

	.bss (NOLOAD) : {
		__blob_bss_start = .;
		*(.bss .bss.*)
		*(COMMON)
		. = ALIGN(16);
		__blob_bss_end = .;
	}
	__blob_end = .;

	/DISCARD/ : { *(.comment) *(.ARM.attributes) *(.note.*) }
}
