// SPDX-License-Identifier: GPL-2.0
/*
 * Arm64 text sections get $x mapping symbols (and data gets $d).  Many share
 * the same few names, so correlating them by name is meaningless.
 *
 * The patched build adds a function, which adds another $x, so the two sides
 * have unequal counts.  That is what makes a naive correlate-by-name produce
 * "no correlation: $x" warnings -- equal counts would match positionally and
 * the bug would be silent.
 */

static const char __modinfo[]
	__attribute__((section(".modinfo"), used, aligned(1))) = "\0name=vmlinux";

int untouched(int x)
{
	return x * 3;
}

#ifdef PATCHED
int added(int x)
{
	return x + 5;
}
#endif

int changed(int x)
{
#ifdef PATCHED
	return x + 2;
#else
	return x + 1;
#endif
}
