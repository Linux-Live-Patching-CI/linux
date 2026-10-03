#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# The five -fcf-protection modes come down to two for klp diff.
#
# On x86 "return" asks for shadow-stack compatibility, which needs no code: the
# CPU keeps the shadow stack itself, and the compiler only records the fact in
# a .note.gnu.property.  "full" is "branch" plus that note, and gcc's "check"
# changes nothing about code generation.  So as far as instructions go:
#
#     none == return == check        branch == full
#
# The kernel only ever builds with none or branch (arch/x86/Makefile), and the
# IBT tests exercise branch where it matters.  They do not also run under
# return and full, and this test is why they need not: it checks the
# equivalence the others rely on, so a compiler which one day emits code for
# "return" breaks here rather than silently escaping coverage.
#
# It also checks the note itself never reaches the patch.  The kernel discards
# .note.gnu.property at link time; a copy in the patch module would be noise
# at best.

. "$(dirname "$0")/../lib.sh"

setup
require_cf_protection branch

# build_mode <mode>: diff ibt_linkage.c built with -fcf-protection=<mode>, and
# leave behind the checksums of its functions and the functions it changed.
build_mode()
{
	local m="$1" f

	orig_obj="orig-$m.o"
	patched_obj="patched-$m.o"
	build_one ibt_linkage.c "$orig_obj" "-fcf-protection=$m"
	build_one ibt_linkage.c "$patched_obj" "-fcf-protection=$m" -DPATCHED
	run_diff

	out_sections | grep -q 'note\.gnu\.property' &&
		fail "-fcf-protection=$m: .note.gnu.property copied into the patch"

	for f in promoted stable caller; do
		echo "$f $(checksum_of "$orig_obj" "$f") $(checksum_of "$patched_obj" "$f")"
	done > "$workdir/sums-$m"
	# checksum_of() prints nothing on failure, and two empty lines compare
	# equal.
	awk 'NF != 3' "$workdir/sums-$m" | grep -q . &&
		fail "-fcf-protection=$m: no checksum recorded for some function"
	grep -o 'changed function: .*' "$workdir/diff.log" | sort > "$workdir/changed-$m"
	cp "$workdir/out.o" "$workdir/out-$m.o"
}

# same <mode> <reference>: the mode gave klp diff exactly the reference's view.
same()
{
	cmp -s "$workdir/sums-$1" "$workdir/sums-$2" ||
		fail "-fcf-protection=$1 checksums differ from $2:" \
		     "$(diff "$workdir/sums-$2" "$workdir/sums-$1" | grep '^[<>]' | tr '\n' ' ')"
	cmp -s "$workdir/changed-$1" "$workdir/changed-$2" ||
		fail "-fcf-protection=$1 changed a different set of functions from $2"
}

build_mode none
build_mode branch

# The premise: the two classes really are different.  If a compiler padded
# nothing under branch, every comparison below would pass vacuously.
has_endbr orig-none.o stable &&
	fail "-fcf-protection=none emitted an ENDBR64"
has_endbr orig-branch.o stable ||
	probe_skip "compiler did not pad an external function under branch"
cmp -s "$workdir/sums-none" "$workdir/sums-branch" &&
	fail "none and branch gave identical checksums, so this compares nothing"

for m in return check; do
	cc_supports "-fcf-protection=$m" || continue	# clang has no "check"
	build_mode "$m"
	same "$m" none
done

cc_supports -fcf-protection=full ||
	fail "compiler takes -fcf-protection=branch but not full"
build_mode full
same full branch

pass "return and check diff as none, full as branch"
