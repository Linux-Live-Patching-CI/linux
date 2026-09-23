#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Adding "static" under IBT loses the function its ENDBR64, the mirror image of
# test-ibt-linkage-flip.  The instructions change, so klp diff has to carry
# the function into the patch even though its source body is the same.
#
# The clone arriving without a landing pad is fine.  Livepatch reaches it
# through ftrace, which leaves the handler with PUSH;RET rather than an
# indirect jump, so nothing ever branches to it indirectly.  Anything that
# still calls the old function through a pointer lands on the kernel's copy,
# which keeps its pad.
#
# What would be wrong is to decide the function is unchanged because only the
# pad moved: the patch would then keep calling a copy the new source says is
# static, and a checksum blind to ENDBR would hide a real difference whenever
# a pad matters.

. "$(dirname "$0")/../lib.sh"

setup
require_cf_protection branch
build_pair ibt_demote.c -fcf-protection=branch

has_endbr orig.o demoted ||
	probe_skip "compiler did not pad the external function"
has_endbr patched.o demoted &&
	probe_skip "compiler pads the static function too"

run_diff

assert_diff_log 'changed function: demoted'
assert_patched demoted

shrank=$(( $(sym_size orig.o demoted) - $(sym_size patched.o demoted) ))
[ "$shrank" = 4 ] ||
	fail "demoted shrank by $shrank bytes, expected the 4 of an ENDBR64"
has_endbr out.o demoted &&
	fail "the cloned demoted() gained a landing pad it does not have in the patch"

diff_log | grep -q 'no correlation' &&
	fail "linkage change under IBT reported as an uncorrelated symbol"

pass "ENDBR lost to a narrowed linkage is a change"
