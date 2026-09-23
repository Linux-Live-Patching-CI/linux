#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# A patch which starts taking the address of a static function.  The pointer it
# creates will be called through, and what it points at decides whether that
# call survives IBT.
#
# Under -fcf-protection=branch the compiler pads target() with ENDBR64 in the
# patched build only.  Its checksum moves, so klp diff clones it, and the new
# pointer has to be to that clone: the kernel's target() never had a landing
# pad, so an indirect call to it would #CP.
#
# Without CET target() is byte-for-byte the same on both sides.  Then the
# right answer is the opposite one: leave it alone and have the pointer refer
# to the kernel's copy through a klp symbol, as for any other unchanged static.
#
# The same source gives different correct outputs in the two modes, which is
# why this test runs both instead of relying on the suite's pinned default.

. "$(dirname "$0")/../lib.sh"

setup
require_cf_protection branch

# Without CET: nothing to clone, the address is the kernel's.
build_pair ibt_address_taken.c -fcf-protection=none
run_diff

assert_diff_log 'changed function: user'
assert_checksum_matches target
assert_not_patched target
assert_klp_sym target vmlinux

# With CET: the new landing pad is a change, and the pointer follows the clone.
build_pair ibt_address_taken.c -fcf-protection=branch

has_endbr orig.o target &&
	probe_skip "compiler pads the static function before its address is taken"
has_endbr patched.o target ||
	probe_skip "compiler did not pad the address-taken function"

run_diff

assert_diff_log 'changed function: target'
assert_diff_log 'changed function: user'
assert_patched target
has_endbr out.o target ||
	fail "the cloned target() lost its landing pad"

# Every reference to target() in the patch, the stored address included, is to
# the clone.  A klp symbol here would be a pointer to the unpadded original.
assert_no_klp_sym target
assert_reloc_sym .text.user target

pass "taking a static function's address under IBT points at a padded clone"
