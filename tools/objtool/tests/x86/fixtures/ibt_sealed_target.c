// SPDX-License-Identifier: GPL-2.0
/*
 * A patch which starts taking the address of a function it does not clone.
 *
 * Under IBT, "objtool --ibt" seals every ENDBR64 in vmlinux whose function
 * nothing takes the address of.  A patch that stores a pointer to such a
 * function, without changing the function itself, points at the running
 * kernel's sealed copy, and an indirect call through it faults.
 *
 * Each function below covers one case klp diff has to tell apart.  None of
 * their bodies change, so none is cloned; only user() and the new table do.
 */

static const char __modinfo[]
	__attribute__((section(".modinfo"), used, aligned(1))) = "\0name=vmlinux";

#define noinline __attribute__((noinline))

typedef int (*fn_t)(int);

/* Only ever called directly in the original: may be sealed.  Warn. */
noinline int sealed_text(int x) { return x * 3; }

/* Same, but the patch takes its address from data.  Warn. */
noinline int sealed_data(int x) { return x * 5; }

/* Defined elsewhere and called directly here.  Warn: we cannot tell. */
extern int sealed_extern(int x);

/* The original already stored its address: its ENDBR64 is in use.  Quiet. */
noinline int already_taken(int x) { return x * 7; }

/* Defined elsewhere, but the original took its address too.  Quiet. */
extern int extern_taken(int x);

/*
 * Exported, so __ksymtab takes its address.  Quiet.  The plain export is
 * reached through an ordinary relocation; the namespaced one needs a klp
 * relocation, like the functions above.
 */
noinline int exported(int x) { return x * 11; }
noinline int exported_ns(int x) { return x * 17; }

/*
 * Undefined symbols have no type, so this could be a function as far as klp
 * diff can tell.  But the original reads it, and any reference other than a
 * call or jump counts as taking the address.  Quiet.
 */
extern int ext_counter;
volatile int *counter_ptr;

/* Still only called directly by the patch.  Quiet. */
noinline int called(int x) { return x * 13; }

/* volatile, or the compiler drops all but the last store */
volatile fn_t hook;
fn_t old_hooks[2] = { already_taken, extern_taken };

#ifdef PATCHED
fn_t new_hooks[] = { sealed_data };
#endif

int user(int x)
{
	int ret = sealed_extern(x) + called(x) + ext_counter;

#ifdef PATCHED
	hook = sealed_text;
	ret += hook(x);
	ret += new_hooks[0](x);
	hook = sealed_extern;
	hook = already_taken;
	hook = extern_taken;
	hook = exported;
	hook = exported_ns;
	counter_ptr = &ext_counter;
#else
	ret += sealed_text(x) + sealed_data(x) + exported(x) +
	       exported_ns(x);
#endif
	return ret;
}
