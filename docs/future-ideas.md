# Future Ideas

Speculative features beyond the current roadmap. These range from practical near-term additions to ambitious research projects.

## JIT Compiler

Compile hot Lisp functions to COR24 assembly at runtime instead of interpreting them. The tml24c compiler (`src/compile.h`) already translates Lisp to COR24 assembly text — a JIT would emit machine code bytes directly into SRAM and jump to them.

| Aspect | Details |
|--------|---------|
| **Approach** | Detect frequently-called closures, compile body to native code, cache result |
| **Speedup** | 10-100x for tight numeric loops (eliminate eval dispatch overhead) |
| **Complexity** | Large (~500+ lines). Need: assembler in C, register allocator, call convention bridge |
| **Memory** | JIT code in SRAM (shared with heap). Need code/heap boundary management |
| **Prerequisites** | Flat vectors (for code buffers), instruction counter for hotspot detection |
| **Incremental path** | Start with AOT: `(compile expr)` returns a callable native function. JIT = AOT + caching |

The existing `compile.h` emits assembly text to UART. A JIT variant would emit binary opcodes into a SRAM buffer and return a function pointer wrapped as a primitive.

## Expanded Scheme Support

See `docs/scheme-todo-items.md` for the detailed inventory. Key items not yet covered:

### letrec (high priority)

Self-referencing local bindings. Expand to `let` + `set!`:

```lisp
(letrec ((fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1)))))))
  (fact 5))
;; expands to:
(let ((fact nil))
  (set! fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1))))))
  (fact 5))
```

### Named let (Scheme loop idiom)

```lisp
(let loop ((i 0) (acc 0))
  (if (= i 10) acc
    (loop (+ i 1) (+ acc i))))
```

Expands to `letrec` with a self-calling lambda.

### R7RS library system (ambitious)

Module system with `define-library`, `import`, `export`. Would require:
- Namespace separation (currently single global namespace)
- File loading mechanism (currently UART-only)
- Dependency resolution

Not practical on bare-metal COR24 but could work with a host-side preprocessor that concatenates library files.

## Continuations

### First-class continuations (call/cc)

The holy grail of Scheme. `call/cc` captures the current execution state as a function that, when called, resumes from that point.

| Challenge | COR24 Difficulty |
|-----------|-----------------|
| Capture C stack | Must copy 3-8 KB of EBR stack |
| Restore stack | Must overwrite current stack with saved copy |
| Multiple returns | A continuation can be called many times |
| Stack safety | GC must scan saved stacks |
| Memory | Each captured continuation = ~3-8 KB |

**Verdict:** Extremely difficult on COR24. The EBR is only 3-8 KB and copying it is expensive. A limited form (escape-only continuations, no re-entry) is more feasible.

### Delimited continuations (shift/reset)

More practical than full `call/cc`. Only captures a portion of the stack (between `reset` and `shift`). Used for:
- Cooperative multitasking
- Generators/iterators
- Exception handling

Still requires stack copying but smaller segments. Medium-large effort.

### Coroutines via trampolining (already feasible)

The `trampoline` pattern already enables cooperative multitasking without real continuations:

```lisp
(define task-a (lambda () (begin (display "A") (lambda () (task-b)))))
(define task-b (lambda () (begin (display "B") (lambda () (task-a)))))
(trampoline task-a)  ;; ABABAB...
```

This is how bottles2.l24 implements mutual recursion. It's not call/cc but covers many use cases.

## Inline C / Assembly

Allow Lisp code to call hand-written C or COR24 assembly. Two levels:

### Level 1: Foreign Function Interface (FFI)

Register C functions as Lisp primitives at compile time. Already works — every `register_prim` call does this. The extension point: a mechanism to add new primitives without modifying `eval.h`.

Possible approach: a `prelude-ffi.h` that defines custom C functions and registers them:

```c
// In prelude-ffi.h:
int my_fast_hash(int args) {
    int val = FIXNUM_VAL(car(args));
    return MAKE_FIXNUM(val * 2654435761 >> 10);  // Knuth hash
}

void load_prelude() {
    register_prim("fast-hash", PRIM_CUSTOM_0);
    // ...
}
```

### Level 2: Inline assembly in Lisp (ambitious)

A `(asm "instruction")` form that emits COR24 instructions into a code buffer and executes them. Would need:
- SRAM code buffer allocation
- Assembler in C (or subset)
- Call/return bridge between interpreted and native code
- GC awareness (native code may hold heap references)

```lisp
;; Hypothetical:
(define fast-add (asm-fn (a b)
  "lw r0, 9(fp)"
  "lw r1, 12(fp)"
  "add r0, r1"
  "jmp (r1)"))
```

This is essentially a minimal JIT. Large effort but would enable performance-critical inner loops.

### Level 3: Dynamic code generation (research)

Combine `eval` + `compile` to generate and execute native code at runtime:

```lisp
;; Generate a specialized function
(define make-multiplier (lambda (n)
  (compile `(lambda (x) (* x ,n)))))

(define times-7 (make-multiplier 7))
(times-7 6)  ;; => 42, running native COR24 code
```

The existing `compile.h` produces assembly text. A binary version would produce executable code in SRAM. This bridges interpreted flexibility with native performance.

## Other Ideas

### Debugger / Stepper

A `(step expr)` form that evaluates one sub-expression at a time, printing each step:

```lisp
(step (+ (* 2 3) 4))
;; STEP: (* 2 3) => 6
;; STEP: (+ 6 4) => 10
;; => 10
```

Requires hooking into the eval loop with a step-mode flag. Medium effort.

### Profiler

Count function calls and heap allocations per function:

```lisp
(profile (map square (range 100)))
;; map: 100 calls, 200 cells allocated
;; square: 100 calls, 0 cells allocated
;; range-helper: 100 calls, 100 cells allocated
```

Requires wrapping closure application with counters. Medium effort.

### Pattern Matching

Destructuring `match` macro (like Clojure's `core.match` or ML pattern matching):

```lisp
(match expr
  ((? number?) (display "a number"))
  ((a . b)     (begin (display "pair: ") (display a)))
  ('nil        (display "empty")))
```

Implementable as a macro expanding to nested `cond`/`if` with type checks. Medium effort, high usability impact.

### Persistent Data Structures

See `docs/futures.md` for detailed analysis of flat vectors, persistent vectors (HAMT), and hash maps. Summary: flat vectors are medium effort and immediately useful; persistent structures are large effort but enable Clojure-style programming.

### WebAssembly Target

Instead of COR24, compile tml24c to WASM for browser execution without the COR24 emulator. Would require a different C compiler (emscripten) and WASM-specific I/O. The Lisp evaluator itself is portable C — the COR24-specific parts are just I/O and inline assembly.
