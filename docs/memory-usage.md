# Memory Usage

## COR24 Address Space

```
0x000000 ┌──────────────────────────────┐
         │  Code (assembled from .s)    │ ~60 KB
         ├──────────────────────────────┤
         │  Static Data                 │ ~400 KB
         │                              │
         │  heap_car[32768]     96 KB   │  car of each cons/extended cell
         │  heap_cdr[32768]     96 KB   │  cdr of each cons/extended cell
         │  heap_mark[32768]    96 KB   │  GC mark flag (1 int per cell)
         │  str_pool[8192]       8 KB   │  string character data
         │  name_pool[4096]      4 KB   │  symbol name characters
         │  sym_name_off[512]    1 KB   │  symbol → name_pool offsets
         │  gc_roots[256]      768 B    │  explicit GC root stack
         │  globals (env, counters)     │  global_env, heap_next, etc.
         ├──────────────────────────────┤
         │  FREE                        │ ~540 KB unused
         │                              │
0x0FFFFF └──────────────────────────────┘
         │  (unmapped, 14 MB gap)       │
0xFEE000 ┌──────────────────────────────┐
         │  EBR (8 KB)                  │
         │    Stack grows ↓ from SP     │
         │    C locals, function frames │
0xFEEC00 │    ← initial SP (default)    │
0xFEFFFF └──────────────────────────────┘
0xFF0000 ┌──────────────────────────────┐
         │  I/O Registers (64 KB)       │
         │  0xFF0000  LED / Switch      │
         │  0xFF0010  Interrupt enable  │
         │  0xFF0100  UART data         │
         │  0xFF0101  UART status       │
0xFFFFFF └──────────────────────────────┘
```

## Memory Regions

### SRAM (0x000000–0x0FFFFF, 1 MB)

All code and data live here. The tc24r compiler places code at low addresses, static arrays above that. The upper portion is free.

| Contents | Size | Notes |
|----------|------|-------|
| Assembled code | ~60 KB | Varies by prelude choice |
| Heap arrays (car + cdr + mark) | ~288 KB | 32,768 cells × 3 arrays × 3 bytes |
| String pool | 8 KB | Append-only character storage |
| Symbol table | 5 KB | 512 symbols, 4 KB name storage |
| Other globals | ~1 KB | gc_roots, counters, pointers |
| **Free** | **~540 KB** | Available for larger heap or vectors |

### EBR Stack (0xFEE000–0xFEFFFF, 8 KB)

Fast embedded block RAM used for the C call stack. SP starts at 0xFEEC00 (3 KB usable by default, 8 KB with `--stack-kilobytes 8`).

The stack holds:
- Function call frames (saved fp, r1, r2 = 9 bytes each)
- Local variables (`char line[1024]` in REPL = 1 KB)
- Intermediate values during eval

The conservative GC scans this region for heap pointers.

### I/O Space (0xFF0000–0xFFFFFF, 64 KB)

Memory-mapped peripherals. Only 4 registers are active:

| Address | Register | Read | Write |
|---------|----------|------|-------|
| 0xFF0000 | LED/Switch | Switch state | LED state |
| 0xFF0010 | IntEnable | Interrupt mask | Interrupt mask |
| 0xFF0100 | UART Data | RX byte | TX byte |
| 0xFF0101 | UART Status | RX ready, CTS, TX busy | Control |

## The Heap

The heap is where all Lisp data lives. It's a pair of parallel arrays indexed by cell number:

```
Cell 0:    heap_car[0] = ...    heap_cdr[0] = ...
Cell 1:    heap_car[1] = ...    heap_cdr[1] = ...
...
Cell 32767: heap_car[32767]     heap_cdr[32767]
```

Each cell stores two 24-bit values (car and cdr). A cell can be:

| Type | car | cdr | Example |
|------|-----|-----|---------|
| **Cons pair** | first element | rest of list | `(1 . (2 . nil))` = list `(1 2)` |
| **Closure** | ETYPE_CLOSURE | `(params . (body . env))` | `(lambda (x) (+ x 1))` |
| **Macro** | ETYPE_MACRO | `(params . (body . env))` | `(defmacro when ...)` |
| **Primitive** | ETYPE_PRIMITIVE | function ID | `+`, `car`, `display` |
| **String** | ETYPE_STRING | packed offset+length | `"hello"` → data in str_pool |
| **Free** | NIL_VAL | next free cell | GC free list linkage |

### Values that DON'T use heap cells

Not everything allocates. These are tagged immediate values stored in 24 bits:

| Type | Tag bits | Payload | Heap? |
|------|----------|---------|-------|
| Fixnum | `00` | 22-bit signed integer | No |
| Symbol | `10` | symbol table index | No (name in name_pool) |
| `nil` | `10` | index 0 | No |
| `t` | `10` | index 1 | No |

Fixnums and symbols are free — they don't consume heap cells. Only cons pairs, closures, macros, and strings use heap cells.

## Where the Lisp Environment Lives

`global_env` is a C global variable (3 bytes in SRAM) holding a tagged pointer to a heap cell. The value is an **association list** — a chain of cons cells:

```
global_env → cell 500
  cell 500: car = cell 501 (binding)    cdr = cell 498 (rest of env)
  cell 501: car = symbol '+'            cdr = cell 502 (primitive object)
  cell 502: car = ETYPE_PRIMITIVE       cdr = fixnum 0 (PRIM_ADD)

  cell 498: car = cell 499 (binding)    cdr = cell 496 (rest of env)
  cell 499: car = symbol '-'            cdr = cell 500 (primitive object)
  ...continues for all ~50-90 bindings...
  ...eventually cdr = nil
```

Each binding consumes 2-3 heap cells: one for the alist node `(binding . rest)`, one for the binding pair `(symbol . value)`, and possibly more for the value (closures need 3 cells).

### Local environments

When a function is called, `env_bind` creates new alist nodes prepended to the closure's captured environment:

```
;; (define add5 (lambda (x) (+ x 5)))
;; (add5 10)

During eval of (+ x 5):
  env → cell 700: car = cell 701    cdr = <closure's captured env>
  cell 701: car = symbol 'x'        cdr = fixnum 10

  Looking up 'x': walk the alist, find (x . 10), return 10.
  Looking up '+': not in local env, fall through to global_env, find it.
```

Local environments are temporary — they exist on the heap during function execution and become garbage when the function returns (unless captured by a closure).

## GC and Memory Lifecycle

### Allocation

`cons` calls `alloc_cell()` which:
1. Checks the free list (recycled cells from previous GC)
2. If empty, bumps `heap_next` (fresh cell from unused heap)
3. If heap full, triggers `gc_collect()` then retries the free list
4. If still full: `PANIC:OOM`

### Collection

`gc_collect()`:
1. Clears all marks
2. Marks from `global_env` (walks entire alist, marks all reachable cells)
3. Marks from `gc_roots[]` (explicit protection for temporaries)
4. **Scans C stack** (conservative: any word that looks like a tagged heap pointer)
5. Sweeps: unmarked cells go onto the free list

### What GC does NOT reclaim

| Resource | Reclaimed? | Notes |
|----------|-----------|-------|
| Heap cells | Yes | Mark-sweep frees unreachable cells |
| String pool bytes | **No** | Append-only; dead strings waste pool space |
| Symbol names | **No** | Interned forever; symbol count only grows |
| Stack space | N/A | Managed by C call/return |

## Typical Usage

| Prelude | Heap cells used | String pool | Symbols |
|---------|----------------|-------------|---------|
| minimal | ~200 | ~0 | ~50 |
| standard | ~1,100 | ~200 | ~100 |
| full | ~1,800 | ~400 | ~140 |
| scheme | ~1,200 | ~200 | ~110 |

With a 32,768-cell heap, even the full prelude leaves ~30,000 cells free for user programs. Each cons pair, closure, or string uses 1-3 cells.

## Configuration

All sizes are `#define` constants in header files:

| Constant | File | Default | Meaning |
|----------|------|---------|---------|
| `HEAP_SIZE` | tml.h | 32768 | Total heap cells |
| `STR_POOL_SIZE` | string.h | 8192 | String data bytes |
| `MAX_SYMBOLS` | symbol.h | 512 | Maximum interned symbols |
| `NAME_POOL_SIZE` | symbol.h | 4096 | Symbol name storage bytes |
| `MAX_GC_ROOTS` | gc.h | 256 | Explicit GC root stack |

To change: edit the constant, rebuild (`just clean && just build`).
