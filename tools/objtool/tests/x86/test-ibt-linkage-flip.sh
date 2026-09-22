#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Dropping "static" is not a free change under IBT.  The compiler gives an
# externally visible function an ENDBR64 landing pad that the static one did
# not need, so a patch which only widens the linkage still moves the
# function's instructions, and klp diff carries it into the patch.
#
# That is the wanted answer, not a wart to be normalised away.  A patch which
# promotes a function usually does so because something is about to take its
# address, and the address it will be called through has to land on an ENDBR.
# The kernel's copy is the one without the pad, so on CET hardware reusing it
# would #CP.  The extra clone costs a few bytes; skipping it costs a fault.
#
# What must not follow from the linkage change is a second copy of the data --
# see test-local-to-global-flip, which makes the same point with IBT out of
# the picture.  Here the point is that IBT does not break that part.

. "$(dirname "$0")/../lib.sh"

setup
require_cf_protection branch
build_pair ibt_linkage.c -fcf-protection=branch

# The premise: the compiler did what this test is about.  A toolchain which
# emits pads by some other rule leaves nothing here to measure.
has_endbr orig.o promoted &&
	probe_skip "compiler pads the static function too"
has_endbr patched.o promoted ||
	probe_skip "compiler did not pad the promoted function"

run_diff

assert_diff_log 'changed function: promoted'
assert_diff_log 'changed function: caller'

# The pad is a real instruction change, so the promoted function is cloned
# with it.
assert_patched promoted

# The landing pad is the whole of that change: four bytes of ENDBR64 in front
# of the same body.
grew=$(( $(sym_size patched.o promoted) - $(sym_size orig.o promoted) ))
[ "$grew" = 4 ] ||
	fail "promoted grew by $grew bytes, expected the 4 of an ENDBR64"
has_endbr out.o promoted ||
	fail "the cloned promoted() lost its landing pad"

# Correlation is not what the pad disturbs.  Both symbols pair with their
# counterparts; one of them simply compares unequal afterwards.
diff_log | grep -q 'no correlation' &&
	fail "linkage change under IBT reported as an uncorrelated symbol"

# A function whose linkage and body both stay put keeps its checksum even
# though it carries a pad on both sides: the pad itself is not what makes
# promoted() differ.
assert_not_patched stable
assert_klp_sym stable vmlinux

pass "ENDBR from a widened linkage is a change, and only that function's"
