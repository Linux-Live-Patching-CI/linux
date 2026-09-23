#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# What becomes of IBT sealing when the patched object belongs to a module.
#
# objtool --ibt lists every ENDBR64 nothing takes the address of in
# .ibt_endbr_seal, and the loader overwrites those with a NOP ("seals" them).
# Built-in objects reach klp diff without that section, because with
# CONFIG_KLP_BUILD the per-object objtool pass is deferred to vmlinux.o.  A
# single-object module is still checked object by object, so its .o arrives
# with the section already in it.
#
# That list must not be carried into the patch.  Its entries describe the
# module's copies, not the clones, and the objtool pass over the patch module
# builds a fresh list for what is actually in it -- unless one is already
# there, in which case it warns "file already has .ibt_endbr_seal, skipping"
# and seals nothing.
#
# IBT_NOSEAL() is the other direction: it is how code tells objtool an ENDBR
# must survive although nothing visible takes its address.  That entry does
# belong to the function, and has to come with its clone, or the clone gets
# sealed where the original was not.

. "$(dirname "$0")/../lib.sh"

setup
require_cf_protection branch
build_module_pair ibt_seal_module.c foo -fcf-protection=branch

has_endbr orig.o sealed ||
	probe_skip "compiler did not pad the external function"

run_objtool_check --ibt --link --module
assert_input_section .ibt_endbr_seal
assert_input_section .discard.ibt_endbr_noseal

run_diff

assert_patched noseal
assert_patched sealed
assert_no_section .ibt_endbr_seal
assert_reloc_count .discard.ibt_endbr_noseal 1
assert_reloc_sym .discard.ibt_endbr_noseal noseal

# The objtool pass the patch module gets, as in its kernel build.
cp "$workdir/out.o" "$workdir/module.o"
"$OBJTOOL" --ibt --link --module "$workdir/module.o" > "$workdir/check.log" 2>&1 ||
	fail "objtool --ibt on the patch failed: $(tail -1 "$workdir/check.log")"
grep -q 'already has .ibt_endbr_seal' "$workdir/check.log" &&
	fail "a stale .ibt_endbr_seal reached the patch module's objtool pass"

# The fresh list seals the clone nothing points at, and spares the one
# IBT_NOSEAL() protects.
seal="$($READELF -rW "$workdir/module.o" | awk '/rela\.ibt_endbr_seal/,/^$/')"
echo "$seal" | grep -q '\.text\.sealed' ||
	fail "the patch module's objtool pass did not seal sealed()"
echo "$seal" | grep -q '\.text\.noseal' &&
	fail "the patch module's objtool pass sealed noseal() despite IBT_NOSEAL()"

pass "module seal list regenerated for the patch, IBT_NOSEAL kept"
