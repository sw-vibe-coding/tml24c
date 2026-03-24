# Scheme Compatibility: Status and TODO

## Approach

tml24c supports Scheme idioms via `prelude/scheme.l24`, a custom prelude loaded on the bare REPL. The reader accepts both `#t`/`#f` and `t`/`nil` natively — no mode flag needed. Both dialects coexist in the same binary.

```bash
just run-custom prelude/scheme.l24              # interactive
just eval-custom demos/scheme.l24 prelude/scheme.l24  # file eval
```

## Implemented

| Feature | How | Notes |
|---------|-----|-------|
| `#t` / `#f` | Reader (C) | `#t` → `T_VAL`, `#f` → `NIL_VAL` |
| `let` | Macro (prelude) | Expands to lambda application |
| `let*` | Macro (prelude) | Sequential binding via nested `let` |
| `cond` with `else` | Macro (prelude) | Uses `'else` instead of `'t` |
| `define-fn` | Macro (prelude) | `(define-fn (f x) body)` shorthand |
| `and` / `or` | Macros (prelude) | Two-arg, short-circuit |
| `when` / `unless` | Macros (prelude) | |
| `equal?` | Function (prelude) | Deep structural equality on pairs and strings |
| `boolean?` | Function (prelude) | Checks `#t` or `#f` |
| `list?` | Function (prelude) | Walks cdr chain to nil |
| `even?` / `odd?` | Functions (prelude) | |
| `zero?` / `positive?` / `negative?` | Functions (prelude) | |
| `modulo` / `remainder` | Aliases (prelude) | Both map to `%` |
| `abs` / `max` / `min` | Functions (prelude) | |
| `map` / `filter` / `for-each` | Functions (prelude) | |
| `append` / `reverse` / `length` | Functions (prelude) | |
| `list-ref` | Function (prelude) | Scheme name for `nth` |
| `display` / `newline` | C primitives | Already standard |
| `apply` | C primitive | Already standard |
| `set!` | Special form (C) | Already standard |
| `begin` | Special form (C) | Already standard |
| Tail-call optimization | Evaluator (C) | Guaranteed for `if`, `begin`, closure apply |
| `string-length` / `string-ref` / `string-append` / `string=?` | C primitives | R7RS-compatible names |
| `number->string` | C primitive | |
| `symbol->string` / `string->symbol` | C primitives | |

## TODO: Feasible (pure Lisp, no C changes)

| Feature | Effort | Notes |
|---------|--------|-------|
| `letrec` | Small | `(letrec ((f (lambda ...))) body)` — expand to `let` + `set!`: `(let ((f nil)) (set! f (lambda ...)) body)` |
| `do` loop | Small | Macro expanding to named-let or tail recursion |
| `case` | Small | Macro expanding to nested `cond` with `eq?` |
| `string-copy` / `substring` | Small | Need `string-ref` + loop to build new string |
| `assoc` / `assv` / `assq` | Small | `assq` = our `assoc` (uses `eq?`), `assoc` uses `equal?` |
| `member` / `memv` / `memq` | Small | Search list by equality |
| `map` (multi-list) | Medium | `(map + '(1 2) '(3 4))` — needs variadic map |
| `for-each` (multi-list) | Medium | Same as multi-list map |
| `dynamic-wind` | Medium | Before/after thunks — no `call/cc` so simpler version possible |
| Proper tail recursion in `or`/`and` | Small | Need `gensym` to avoid double eval |
| `quasiquote` nesting | Medium | Nested `` ` `` inside `` ` `` — partially works |

## TODO: Requires C Changes

| Feature | Effort | Notes |
|---------|--------|-------|
| `(define (f x) body)` shorthand in eval | Small (~10 lines) | Detect `(define (name . params) body)` → `(define name (lambda params body))` |
| `char` type | Medium | New tag or extended type, `char?`, `char->integer`, `integer->char`, char literals `#\a` |
| `string->number` | Small | Parse string to fixnum, inverse of `number->string` |
| `read` (from string) | Small | Already have `read_str` in C, just expose as primitive |
| Multiple return values | Medium | `values` + `call-with-values` — needs new type or convention |
| `with-exception-handler` / `raise` | Medium | Error handling — needs longjmp or continuation mechanism |
| `exact?` / `inexact?` | N/A | Only fixnums, no floats on COR24 |

## Not Feasible on tml24c

| Feature | Why |
|---------|-----|
| `call-with-current-continuation` (`call/cc`) | Requires reifying the C stack as a first-class object. On COR24 with 3-8KB EBR stack, this would need copying the entire stack, which is both complex (~200 lines) and memory-expensive. |
| `syntax-rules` / `syntax-case` (hygienic macros) | Full hygiene requires a renaming/marking system for bound variables during macro expansion (~200+ lines of C). Our `defmacro` + `gensym` covers most use cases. |
| Full numeric tower | COR24 has 22-bit fixnums only. No bignums, rationals, floats, or complex numbers. |
| `char` type with Unicode | 24-bit word size limits char range. ASCII only is feasible. |
| Tail-call in `and`/`or`/`cond` bodies | Our macro-based versions expand to `if` which IS TCO'd, so this already works for the final expression. |
| R7RS library system | No filesystem, no module loader. Single global namespace. |

## Recommended Priority

1. **`letrec`** — unlocks self-referencing local functions, very common in Scheme
2. **`(define (f x) body)` shorthand** — most-missed convenience from R7RS
3. **`case`** — useful macro, easy
4. **`member`/`assoc` with `equal?`** — standard Scheme list operations
5. **`char` type** — enables string processing, but significant effort

## Testing

The Scheme prelude should be validated against a set of R7RS examples. Create `tests/scheme-tests.l24` with standard Scheme idioms to verify correctness.
