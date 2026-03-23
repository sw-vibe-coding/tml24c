# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Tiny Macro Lisp (tml24c): a minimal Lisp-1 with lexical scope, unhygienic defmacro, closures, and mark-sweep GC. Compiles to COR24 24-bit RISC assembly.

## Workflow -- AgentRail

This project uses [AgentRail](https://github.com/sw-vibe-coding/agentrail-rs) for saga-based workflow management with skill-guided prompting.

**At the START of every session**, run:
```bash
agentrail next
```
This shows: the plan, all steps, your current step's prompt, relevant skill docs (procedures, failure modes), and past successful trajectories.

**At the END of every session** (after committing code), run:
```bash
agentrail complete --summary "what you accomplished" \
  --reward 1 \
  --actions "tools and approach used" \
  --next-slug <next-step-slug> \
  --next-prompt "instructions for next step" \
  --next-task-type <task-type>
```

If the step failed: `--reward -1 --failure-mode "what went wrong"`

If the saga is done: `--done` instead of `--next-*` flags.

**Available task types** (from agentrail-domain-coding):
- `c-project-init` -- C project setup with Makefile and -Wall -Werror
- `c-compile-fix` -- Fix C compiler warnings without suppressing
- `lisp-define-form` -- Define Lisp special forms and macros
- `pre-commit` -- Quality gates before committing

## Related Projects

- `~/github/sw-embed/cor24-rs` -- COR24 assembler and emulator (Rust)
- `~/github/sw-vibe-coding/tc24r` -- Tiny COR24 compiler (Rust)
- `~/github/sw-vibe-coding/agentrail-domain-coding` -- Coding skills domain

## Build

```bash
make          # build
make clean    # clean
```

Compiler flags: `-Wall -Wextra -Werror -std=c11`

## Development

- Pre-commit: `make clean && make` (zero warnings required)
- Never suppress warnings with #pragma or by removing -Werror
- TDD where possible: write test, make it fail, implement, verify
- Read docs/research.txt for Lisp design decisions
