# Error Handling

## Design

tml24c uses a simple error model: print a message, return `nil`, continue. There are no exceptions, conditions, restarts, or longjmp. Errors are **soft** — the REPL always stays alive.

This matches the bare-metal target: no OS, no stack unwinding, no signal handlers. The priority is **never hang, never silently corrupt**.

## Error Messages

| Error | Cause | Example |
|-------|-------|---------|
| `ERR:div-by-zero` | Division or modulo by zero | `(/ 42 0)`, `(% 10 0)` |
| `ERR:not-number` | Arithmetic on non-fixnum | `(+ "a" 1)`, `(* nil 5)` |
| `ERR:car-of-non-pair` | `car` on non-cons value | `(car 42)`, `(car nil)` |
| `ERR:cdr-of-non-pair` | `cdr` on non-cons value | `(cdr "hello")` |
| `ERR:unbound <sym>` | Symbol not in any environment | `foo-bar-baz` |
| `ERR:not-fn` | Calling a non-function | `(42 1 2)` |
| `ERR:set!-unbound <sym>` | `set!` on undefined variable | `(set! xyz 1)` |
| `OOM` | Heap exhausted (4096 cells) | Deep allocation without GC recovery |
| `STR-OOM` | String pool exhausted (2048 bytes) | Many string-append calls |
| `GC:roots` | GC root stack overflow (256) | Extremely deep nesting |

## Soft vs Hard Errors

**Soft errors** print a message, return `nil`, and the REPL continues:
- `ERR:div-by-zero`, `ERR:not-number`, `ERR:car-of-non-pair`, `ERR:cdr-of-non-pair`
- `ERR:unbound`, `ERR:not-fn`, `ERR:set!-unbound`

**Hard errors** halt the CPU (program stops, emulator exits):
- `OOM` — heap fully exhausted after GC
- `STR-OOM` — string pool full
- `GC:roots` — too many protected roots

## Cascading Errors

Errors return `nil`, which can trigger further errors downstream:

```lisp
(+ 1 (/ 10 0))
;; ERR:div-by-zero    ← inner / returns nil
;; ERR:not-number     ← outer + gets (+ 1 nil)
;; nil
```

This is intentional — each operation independently validates its inputs. The alternative (aborting the whole expression) would need longjmp or exceptions.

## Defensive Patterns

### Guard with predicates

```lisp
(define safe-div (lambda (a b)
  (if (= b 0) 'inf (/ a b))))

(define add-safe (lambda (a b)
  (if (and (number? a) (number? b))
    (+ a b)
    'type-error)))
```

### Check before car/cdr

```lisp
(define safe-car (lambda (x)
  (if (pair? x) (car x) nil)))
```

### Anaphoric lookup

```lisp
(awhen (assoc 'key data)
  (cdr it))  ; only runs if found
```

## What's NOT Checked

Some operations still produce garbage or undefined results without errors:

| Operation | Result |
|-----------|--------|
| `(string-length 42)` | Undefined (reads heap as if string) |
| `(string-append 1 2)` | Undefined |
| `(peek 999999)` | Reads unmapped memory (returns 0) |
| `(poke 0 42)` | Writes to code memory |
| Integer overflow | Silent wraparound (22-bit fixnum) |

Adding checks to every primitive would increase code size and slow execution. The current set covers the most common crashes and hangs.

## Comparison with Other Lisps

| Feature | tml24c | CL | Scheme | Clojure |
|---------|--------|-----|--------|---------|
| Error on wrong type | Print + nil | Condition | Error object | Exception |
| Recovery | REPL continues | Restarts | guard/handler | try/catch |
| Stack overflow | Undefined | Condition | Error | StackOverflow |
| Division by zero | ERR + nil | Condition | Error | ArithmeticException |
| Unbound variable | ERR + nil | Condition | Error | CompilerException |

## Future: Structured Error Handling

A `try`/`catch` or `guard` macro could be built if we add:
1. A global error flag (set by error primitives)
2. A `(error msg)` primitive that sets the flag and returns nil
3. A `(try expr fallback)` macro that checks the flag after eval

This would give Clojure-style error handling without longjmp:
```lisp
(try (/ 42 0) 'caught)  ;; => caught
```
