// SPDX-License-Identifier: GPL-2.0
/*
 * The reverse of ibt_linkage.c.  Under -fcf-protection=branch an external
 * function opens with ENDBR64; make it static, with its address never taken,
 * and the compiler drops the pad.  The body is untouched, the instructions
 * are not.
 */

static const char __modinfo[]
	__attribute__((section(".modinfo"), used, aligned(1))) = "\0name=vmlinux";

/* External in the original, static in the patch: ENDBR disappears. */
#ifdef PATCHED
__attribute__((noinline)) static int demoted(int x)
#else
__attribute__((noinline)) int demoted(int x)
#endif
{
	return x + 1;
}

int caller(int x)
{
	return demoted(x) * 2;
}
