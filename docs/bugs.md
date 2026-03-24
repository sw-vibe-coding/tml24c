# Known Bugs

## GC collects live objects during eval (root cause of multiple symptoms)

**Status:** Open. Partially mitigated by gc_protect in eval_list, read_list, begin handler, and REPL.

**Root cause:** The mark-sweep GC only marks from `global_env` and the explicit `gc_roots[]` stack. Local C variables (function arguments, loop temporaries) are NOT scanned. When GC triggers during eval — via cons allocation in eval_list, read_list, or string creation — values held only in C locals can be collected.

**Symptoms:**
1. **String literals return wrong length:** `(string-length "hello")` returns 0 when the string is inline (GC collects the string's heap cell during eval_list). Works correctly when the string is bound to a variable in global_env.
2. **Bottles demo stops after ~3 verses:** The local `env` binding (e.g., n=3) is collected during display/string operations within begin, causing subsequent iterations to fail silently.
3. **Buffer size sensitivity:** Changing `char buf[128]` to `char buf[32]` in read_string appeared to fix strings, but actually just shifted GC timing. The bug was NOT a tc24r compiler issue — a standalone reproducer with the same call depth works correctly.

**Proper fix:** Conservative GC that scans the C stack for potential heap pointers. The COR24 EBR stack region is known (0xFEE000–0xFEFFFF), and tagged heap pointers are identifiable by their low 2 bits. Scanning the stack from SP to the initial SP and treating any word that looks like a valid tagged pointer as a root would prevent collection of live objects without requiring manual gc_protect calls.

**Current mitigations:**
- `gc_protect(expr)` / `gc_protect(result)` in the REPL
- `gc_protect(val)` / `gc_protect(rest)` in eval_list
- `gc_protect(first)` / `gc_protect(head)` / `gc_protect(elem)` in read_list
- `gc_protect(env)` in begin handler
- String literals limited to 31 chars (buf[32]) as an accidental mitigation

**Workaround:** Bind values to variables via `define` before passing them to functions. This places them in `global_env` where GC can find them.

## REPL single-line input limit

**Status:** Open.

`read_line` uses a 256-byte buffer. Expressions must fit on one line. Multi-line input would require paren-counting to detect incomplete expressions and continue reading.

## String literal length limit

**Status:** 31 characters (buf[32] in read_string).

Can be increased once the GC root scanning issue is properly fixed (conservative GC). The buffer size is not the real constraint — it was reduced as an accidental mitigation for the GC bug above.
