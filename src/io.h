#pragma once

/* io.h -- UART I/O for COR24-TB */

#define UART_DATA   0xFF0100
#define UART_STATUS 0xFF0101

void putc_uart(int ch) {
    /* Bounded TX busy wait — prevents infinite spin if emulator
     * doesn't tick UART between instructions (e.g., WASM batch mode).
     * 100 iterations is enough for the 10-cycle TX busy default. */
    int tries = 100;
    while ((*(char *)UART_STATUS & 0x80) && tries > 0) {
        tries = tries - 1;
    }
    *(char *)UART_DATA = ch;
}

void puts_str(char *s) {
    while (*s) {
        putc_uart(*s);
        s = s + 1;
    }
}

int getc_uart() {
    while (!(*(char *)UART_STATUS & 0x01)) {}  /* bit 0: RX data ready */
    return *(char *)UART_DATA;
}

void halt() {
    asm("_user_halt:");
    asm("bra _user_halt");
}

int read_line(char *buf, int max) {
    int i = 0;
    int depth = 0;   /* paren nesting depth */
    int in_str = 0;  /* inside a string literal */
    while (i < max - 1) {
        int ch = getc_uart();
        if (ch == 4) {
            /* Ctrl-D: EOF */
            return -1;
        }
        if (ch == '\n' || ch == '\r') {
            /* Only break when parens are balanced */
            if (depth <= 0) break;
            /* Inside unbalanced parens: treat newline as space */
            buf[i] = ' ';
            i = i + 1;
            continue;
        }
        buf[i] = ch;
        i = i + 1;
        /* Track paren depth (ignore parens inside strings) */
        if (ch == 34) { in_str = 1 - in_str; }
        if (!in_str) {
            if (ch == '(') { depth = depth + 1; }
            if (ch == ')') { depth = depth - 1; }
        }
    }
    buf[i] = 0;
    return i;
}

void print_int(int n) {
    if (n < 0) {
        putc_uart(45);
        n = 0 - n;
    }
    if (n == 0) {
        putc_uart(48);
        return;
    }
    char buf[8];
    int i = 0;
    while (n > 0) {
        buf[i] = 48 + n % 10;
        n = n / 10;
        i = i + 1;
    }
    while (i > 0) {
        i = i - 1;
        putc_uart(buf[i]);
    }
}
