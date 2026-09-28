#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Arm64 ELF files mark code/data transitions with mapping symbols ($x, $d,
# …).  Thousands share the same few names; they are not real symbols and must
# not be correlated.
#
# If they are, a patch that adds or removes a function changes the count and
# klp diff emits "no correlation: $x" for every unmatched one.  Those warnings
# look like the real correlation failures this suite watches for (see
# test-function-removal), so a genuine problem is easy to miss.  Nothing fails
# at build time.
#
# Fixed by commit b889e71c7017 ("objtool/klp: Don't correlate arm64 mapping
# symbols"), which adds is_mapping_sym() to dont_correlate().
#
# The fixture's added function is load-bearing: without it both sides have the
# same number of $x symbols, positional matching succeeds, and removing the
# fix changes nothing observable.
#
# Toolchains disagree on the spelling: gcc emits bare "$x", clang emits
# "$x.0", "$x.1", ….  Match either form, the same way is_mapping_sym() keys
# off '$' rather than an exact name.

. "$(dirname "$0")/../lib.sh"

setup
build_pair mapping_symbols.c

# Premise: the toolchain emitted mapping symbols, and the patched object has
# more of them than the original (from 'added'), so correlation by name cannot
# get a 1:1 match.
count_map()
{
	# $x or $x.<n> (and __pi_$x…); NOTYPE keeps section symbols out.
	in_symbols "$1" | awk '$4 == "NOTYPE" && $NF ~ /\$x(\.|$)/' | wc -l
}

n_orig=$(count_map "$orig_obj")
n_patched=$(count_map "$patched_obj")
[ "$n_orig" -gt 0 ] && [ "$n_patched" -gt "$n_orig" ] ||
	fail "expected more \$x* in patched than orig (orig=$n_orig patched=$n_patched)"

run_diff

diff_log | grep -qE 'no correlation: \$' &&
	fail "mapping symbol was subjected to correlation"

assert_patched changed
assert_symbol added
assert_not_patched untouched

pass "arm64 mapping symbols skipped by correlation"
