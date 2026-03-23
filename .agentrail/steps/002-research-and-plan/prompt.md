Read docs/research.txt (3000 lines of Lisp design research for COR24).

Study the COR24 toolchain:
- ~/github/sw-embed/cor24-rs -- COR24 assembler and emulator (read its README, ISA docs)
- ~/github/sw-vibe-coding/tc24r -- Tiny COR24 compiler in Rust (read its README, architecture)

Then create these documentation files:

1. docs/architecture.md -- System overview: components (reader, evaluator, compiler, GC, runtime), memory model (24-bit address space, heap layout, stack), how they connect. Component diagram.

2. docs/prd.md -- Product requirements: target demos (anaphoric macros, list processing, arithmetic, strings), constraints (COR24 24-bit ISA, embedded-class memory), success criteria.

3. docs/design.md -- Detailed design: data representation (tagged values in 24-bit words), cell layout, environment structure, closure representation, GC algorithm (mark-sweep), special forms list, macro expansion strategy.

4. docs/plan.md -- Phased implementation plan with concrete steps. Phase 1: reader/evaluator in C. Phase 2: core library in Lisp. Phase 3: compiler to COR24 assembly. Phase 4: integration and demos.

5. docs/stats.md -- COR24 ISA summary relevant to Lisp: instruction set, register count, addressing modes, memory size, what operations are native vs need runtime support.
