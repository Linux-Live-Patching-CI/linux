#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# A patch must not hand out a pointer to a function the kernel sealed.
#
# With IBT, objtool seals each ENDBR64 in vmlinux that nothing takes the
# address of, and the kernel turns those into NOPs at boot.  klp diff does not
# clone a function whose body is unchanged; the patch reaches the kernel's copy
# through a klp relocation instead.  If the patch is the first to take that
# function's address, the pointer lands on a sealed function and the first
# indirect call through it faults (#CP, or a kCFI/FineIBT hash failure).
#
# klp diff sees one object, so it cannot know whether some other object kept
# the ENDBR64 alive.  It warns for every new address-taking reference which
# might hit a sealed function, and stays quiet for those which cannot: the
# original object took the address already, the function is exported, the
# reference is a plain call, or the kernel was not built with IBT at all.

. "$(dirname "$0")/../lib.sh"

setup
require_cf_protection branch

sealed="sealed_text sealed_data sealed_extern"
quiet="already_taken extern_taken exported exported_ns ext_counter called"

export_syms exported
add_exports_ns vmlinux module:kvm exported_ns

# Without IBT there are no landing pads and nothing to seal.
build_pair ibt_sealed_target.c -fcf-protection=none
run_diff
diff_log | grep -q 'new function pointer' &&
	fail "warned about sealing in a build without IBT:" \
	     "$(diff_log | grep "new function pointer")"

build_pair ibt_sealed_target.c -fcf-protection=branch
for f in sealed_text sealed_data already_taken exported exported_ns called; do
	has_endbr orig.o "$f" ||
		probe_skip "compiler did not pad $f() under branch"
done

# The premise, from objtool's side: the original object seals the functions
# the warnings are about, and called() too, which the patch only calls, but
# not already_taken(), whose address it stores.
cp "$workdir/orig.o" "$workdir/sealed.o"
"$OBJTOOL" --ibt --link "$workdir/sealed.o" > "$workdir/seal.log" 2>&1 ||
	fail "objtool --ibt failed on the original: $(cat "$workdir/seal.log")"
seal_list=$(objdump -r -j .ibt_endbr_seal "$workdir/sealed.o")
for f in sealed_text sealed_data; do
	grep -qw "$f" <<< "$seal_list" ||
		probe_skip "objtool did not seal $f() in the original"
done
grep -qw called <<< "$seal_list" ||
	probe_skip "objtool did not seal called() in the original"
grep -qw already_taken <<< "$seal_list" &&
	fail "objtool sealed already_taken() although the original takes its address"

run_diff

# The patch really does point at the kernel's copies rather than clones.
for f in $sealed $quiet; do
	assert_not_patched "$f"
done
for f in sealed_text sealed_data sealed_extern already_taken extern_taken \
	 exported_ns ext_counter; do
	assert_klp_sym "$f" vmlinux
done

for f in $sealed; do
	assert_diff_log "new function pointer to $f\(\)"
done
for f in $quiet; do
	diff_log | grep -q "new function pointer to $f()" &&
		fail "warned about $f(), which cannot be sealed"
done

# A warning, not an error: the patch may well be fine.
[ -s "$workdir/out.o" ] || fail "klp diff produced no output"

pass "new pointers to possibly sealed functions are reported, and only those"
