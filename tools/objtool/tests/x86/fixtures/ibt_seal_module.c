// SPDX-License-Identifier: GPL-2.0
/*
 * A module object which has already been through objtool --ibt, as a single-
 * object module has by the time klp-build copies it.
 *
 * Both functions change.  noseal() carries an IBT_NOSEAL() entry, which keeps
 * its ENDBR64 even though nothing in the object takes its address; sealed()
 * has none, so objtool lists its ENDBR64 in .ibt_endbr_seal for the module
 * loader to overwrite.
 */

static const char __modinfo[]
	__attribute__((section(".modinfo"), used, aligned(1))) = "\0name=" MODNAME;

/* IBT_NOSEAL(), spelled out so the fixture builds without kernel headers */
asm(".pushsection .discard.ibt_endbr_noseal\n\t"
    ".quad noseal\n\t"
    ".popsection");

#ifdef PATCHED
#define DELTA 2
#else
#define DELTA 1
#endif

__attribute__((noinline)) int noseal(int x)
{
	return x * 4 + DELTA;
}

__attribute__((noinline)) int sealed(int x)
{
	return x * 8 + DELTA;
}

int user(int x)
{
	return noseal(x) + sealed(x);
}
