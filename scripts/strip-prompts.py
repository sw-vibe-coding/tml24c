#!/usr/bin/env python3
"""Strip REPL prompts (> ) from output lines, skip blanks."""
import sys

for line in sys.stdin:
    line = line.lstrip("> ").rstrip()
    if line:
        print(line)
