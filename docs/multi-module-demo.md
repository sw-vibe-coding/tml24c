# Multi-Module Programs

How to compile and link multiple modules into one COR24 program.
Each module is assembled at a different base address and loaded
into memory by the emulator.

## Concept

```
demos/multi/main.l24   (Lisp)  →  compile  →  build/main.s    →  loaded at 0x0000
demos/multi/uart.s     (asm)   →  assemble →  build/uart.bin  →  loaded at 0x1000
```

The main program references the UART module by its known base address:

```scheme
;; Wire uart-putc from module at 0x1000
(define putc (asm "        la   r0,#x1000"))
```

The UART module is a handwritten .s file with its entry point at the
first byte. When loaded at 0x1000, calling address 0x1000 enters
`uart-putc` directly.

## Running the Demo

### Quick run

```bash
just demo-multi
```

Output:
```
UART output: Hi!
CPU halted (self-branch detected)
```

### Step by step

#### 1. Assemble the UART module at 0x1000

```bash
cor24-run --assemble demos/multi/uart.s build/uart.bin build/uart.lst --base-addr 0x1000
```

Check the listing to see entry point addresses:

```bash
cat build/uart.lst
```

```
                    _uart_putc:
1000: 80             push    fp
1001: 7F             push    r2
...
```

#### 2. Compile the main program

```bash
just compile demos/multi/main.l24
```

Note how the compiler emits `la r0,#x1000` for the `putc` binding —
this is the raw address of `uart-putc` in the UART module.

#### 3. Run with both modules loaded

```bash
cor24-run --run build/main.s \
    --load-binary build/uart.bin@0x1000 \
    --speed 0 -n 10000000
```

#### 4. Debug with dump and trace

```bash
cor24-run --run build/main.s \
    --load-binary build/uart.bin@0x1000 \
    --speed 0 -n 10000000 --dump --trace 50
```

## How It Works

### Module layout

The UART module (`demos/multi/uart.s`) is a handwritten .s file:

```asm
_uart_putc:
        push    fp       ; standard ABI prologue
        push    r2
        push    r1
        mov     fp,sp
        lw      r0,9(fp) ; arg: tagged fixnum
        lc      r1,2
        sra     r0,r1    ; untag (shift right 2)
        la      r1,#xFF0100
        sb      r0,0(r1) ; write to UART TX
        lw      r0,9(fp) ; return the char
        mov     sp,fp    ; standard ABI epilogue
        pop     r1
        pop     r2
        pop     fp
        jmp     (r1)
```

It follows the COR24 ABI so the compiler-generated code can call it
like any other function. The key convention:

- Arguments are tagged fixnums (shifted left 2 bits)
- The callee must untag (`sra r0,r1` where r1=2) before using raw values
- Return value in r0 (tagged)

### Main program

The main program (`demos/multi/main.l24`) is compiled Lisp:

```scheme
(define putc (asm "        la   r0,#x1000"))
(putc 72)    ; 'H'
(putc 105)   ; 'i'
(putc 33)    ; '!'
(putc 10)    ; newline
(asm "_halt:"
     "        bra _halt")
```

The `(asm "        la   r0,#x1000")` inside `define` loads the UART
module's entry address into r0. The compiler stores this as the value
of `putc`. When `(putc 72)` is called, the compiler:

1. Tags 72 as fixnum: 72 << 2 = 288
2. Pushes 288 on the stack
3. Loads `putc`'s value (0x1000) into r0
4. Calls `jal r1,(r0)` — jumps to the UART module

### Memory map

```
0x000000  main.s     (compiled Lisp — _cmain entry)
   ...
0x001000  uart.bin   (assembled service module)
   ...
0xFEE000  Stack      (8 KB EBR, grows downward)
0xFF0000  I/O        (LED, button, UART, interrupt)
```

## Writing Your Own Modules

### Service module (.s file)

Write a .s file with the entry point at the first label:

```asm
; mymodule.s — loaded at 0x2000
_my_function:
        push    fp
        push    r2
        push    r1
        mov     fp,sp
        ; ... your code, args at fp+9, fp+12, ...
        ; ... result in r0 ...
        mov     sp,fp
        pop     r1
        pop     r2
        pop     fp
        jmp     (r1)
```

Assemble at the target address:

```bash
cor24-run --assemble mymodule.s build/mymodule.bin build/mymodule.lst --base-addr 0x2000
```

### Multiple entry points

Use a jump table at the module base:

```asm
; Each entry: la (4 bytes) + jmp (1 byte) = 5 bytes
; Entry 0 at base+0, entry 1 at base+5, entry 2 at base+10, ...
        la      r0,_func_a
        jmp     (r0)
        la      r0,_func_b
        jmp     (r0)

_func_a:
        ; ...
        jmp     (r1)

_func_b:
        ; ...
        jmp     (r1)
```

Reference from Lisp:

```scheme
(define func-a (asm "        la   r0,#x2000"))  ; base + 0
(define func-b (asm "        la   r0,#x2005"))  ; base + 5
```

### Calling from the main program

```scheme
(define my-fn (asm "        la   r0,#x2000"))
(my-fn 42)
```

### Loading multiple modules

```bash
cor24-run --run build/main.s \
    --load-binary build/uart.bin@0x1000 \
    --load-binary build/spi.bin@0x2000 \
    --load-binary build/i2c.bin@0x3000 \
    --speed 0 -n 10000000
```

## Limitations

- **Hardcoded addresses**: the main program must know each module's
  base address at compile time. No dynamic linking.
- **No symbol sharing**: modules can't reference each other's labels.
  Cross-module calls use fixed addresses.
- **Manual coordination**: you choose base addresses and ensure modules
  don't overlap.
- **Service modules are handwritten .s**: the compiler wraps everything
  in a `_cmain` prologue, so compiled .l24 files can't be used as
  service modules directly. Use .s for service modules, .l24 for the
  main program.

## Future: Simple Linker

A build step could automate address assignment and cross-module
references:

```bash
just link main.l24 uart.l24 spi.l24
```

This would:
1. Compile each .l24 to .s
2. Assign base addresses (avoiding overlaps)
3. Extract exported labels from .lst files
4. Patch cross-references
5. Produce coordinated .bin files or one merged binary
