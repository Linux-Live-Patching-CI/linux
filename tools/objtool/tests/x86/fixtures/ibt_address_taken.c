// SPDX-License-Identifier: GPL-2.0
/*
 * A static function whose address the patch starts taking.
 *
 * In the original, target() is static and only called directly, so under
 * -fcf-protection=branch it needs no ENDBR64.  The patch stores its address in
 * a pointer, which makes it an indirect-call target, and the compiler pads it.
 * Without CET nothing about target() changes at all.
 */

static const char __modinfo[]
	__attribute__((section(".modinfo"), used, aligned(1))) = "\0name=vmlinux";

int (*hook)(int);

__attribute__((noinline)) static int target(int x)
{
	return x + 1;
}

int user(int x)
{
#ifdef PATCHED
	hook = target;
#endif
	return target(x);
}
