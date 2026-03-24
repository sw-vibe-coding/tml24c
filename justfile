# tml24c -- Tiny Macro Lisp for COR24

set quiet

tc24r := "tc24r"
cor24_run := "cor24-run"

# Build the test binary (with compiler + test suite)
build:
    mkdir -p build
    {{tc24r}} src/main.c -o build/tml24c.s

# Build the REPL with compiled-in prelude (legacy)
build-repl:
    mkdir -p build
    {{tc24r}} src/repl.c -o build/repl.s

# Build the bare REPL (no prelude — loaded from .l24 files)
build-bare:
    mkdir -p build
    {{tc24r}} src/repl-bare.c -o build/repl-bare.s

# Interactive REPL with compiled-in prelude (Ctrl-] to exit)
run: build-repl
    {{cor24_run}} --run build/repl.s --terminal --echo --speed 0

# REPL with selectable prelude: just repl tiny|standard|full
repl prelude="standard": build-bare
    #!/usr/bin/env bash
    case "{{prelude}}" in
        tiny)     cat prelude/tiny.l24 ;;
        standard) grep -v '^;;' prelude/standard.l24 ;;
        full)     grep -v '^;;' prelude/standard.l24; grep -v '^;;' prelude/full.l24 ;;
        *)        echo "Unknown prelude: {{prelude}}"; exit 1 ;;
    esac | {{cor24_run}} --run build/repl-bare.s --terminal --echo --speed 0

# Evaluate a .l24 file (compiled-in standard prelude)
eval file: build-repl
    #!/usr/bin/env bash
    grep -v '^;;' "{{file}}" | {{cor24_run}} --run build/repl.s --terminal --speed 0 -n 500000000 2>&1 | \
        grep -v -E '^Assembled |Executed [0-9]+ instructions|^\[CPU'

# Evaluate with bare REPL + file-based prelude (slower, flexible)
eval-bare file prelude="standard": build-bare
    #!/usr/bin/env bash
    case "{{prelude}}" in
        tiny)     cat prelude/tiny.l24 ;;
        standard) grep -v '^;;' prelude/standard.l24 ;;
        full)     grep -v '^;;' prelude/standard.l24; grep -v '^;;' prelude/full.l24 ;;
        *)        echo "Unknown prelude: {{prelude}}"; exit 1 ;;
    esac > /tmp/tml24c-prelude.tmp
    { cat /tmp/tml24c-prelude.tmp; grep -v '^;;' "{{file}}"; } | \
        {{cor24_run}} --run build/repl-bare.s --terminal --speed 0 -n 500000000 2>&1 | \
        grep -v -E '^Assembled |Executed [0-9]+ instructions|^\[CPU'

# Run all test suites
test: build
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running tml24c tests..."
    echo "" | {{cor24_run}} --run build/tml24c.s --terminal --speed 0 -n 50000000 2>&1 | \
        grep -E '^(scaffold|reader|eval|gc|compile) ok$' | sort -u > build/test-results.txt
    expected=5
    got=$(wc -l < build/test-results.txt | tr -d ' ')
    if [ "$got" -eq "$expected" ]; then
        echo "All $expected test suites passed."
        cat build/test-results.txt
    else
        echo "FAIL: $got/$expected test suites passed:"
        cat build/test-results.txt
        exit 1
    fi

# Blink D2 LED demo (Ctrl-] to exit)
demo-blink: build-bare
    { grep -v '^;;' prelude/standard.l24; grep -v '^;;' demos/blink.l24; } | \
        {{cor24_run}} --run build/repl-bare.s --terminal --speed 500000

# 99 Bottles of Beer demos
demo-bottles: build-bare
    { grep -v '^;;' prelude/standard.l24; grep -v '^;;' demos/bottles.l24; } | \
        {{cor24_run}} --run build/repl-bare.s --terminal --speed 0 -n 500000000

demo-bottles2: build-bare
    { grep -v '^;;' prelude/standard.l24; grep -v '^;;' prelude/full.l24; grep -v '^;;' demos/bottles2.l24; } | \
        {{cor24_run}} --run build/repl-bare.s --terminal --speed 0 -n 500000000

demo-bottles4: build-bare
    { grep -v '^;;' prelude/standard.l24; grep -v '^;;' demos/bottles4.l24; } | \
        {{cor24_run}} --run build/repl-bare.s --terminal --speed 0 -n 500000000

# Clean build artifacts
clean:
    rm -rf build
