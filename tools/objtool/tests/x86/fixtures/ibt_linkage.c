// SPDX-License-Identifier: GPL-2.0
/*
 * IBT and the instruction checksum.
 *
 * Under -fcf-protection=branch the compiler opens every function it cannot
 * prove is reached only by direct calls with an ENDBR64 landing pad.  A static
 * function whose address is never taken needs none; giving the same function
 * external linkage makes it a possible indirect target, so it gains four
 * bytes.
 *
 * "promoted" therefore has different instructions in the two builds even
 * though its source body is untouched, while "stable" keeps its landing pad on
 * both sides and must checksum the same.
 */

static const char __modinfo[]
	__attribute__((section(".modinfo"), used, aligned(1))) = "\0name=vmlinux";

/* noinline, or these are folded into the caller and have no symbol */

/* Static in the original, external in the patch: ENDBR appears. */
#ifdef PATCHED
__attribute__((noinline)) int promoted(int x)
#else
__attribute__((noinline)) static int promoted(int x)
#endif
{
	return x + 1;
}

/* External on both sides, body untouched: ENDBR on both, checksum stable. */
__attribute__((noinline)) int stable(int x)
{
	return x + 2;
}

int caller(int x)
{
#ifdef PATCHED
	return promoted(x) + stable(x) + 1;
#else
	return promoted(x) + stable(x);
#endif
}
