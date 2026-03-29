; uart.s -- UART service module (loaded at 0x1000)
;
; Entry point: 0x1000 = uart-putc(ch)
; ABI: tagged fixnum arg on stack, standard prologue/epilogue

_uart_putc:
        push    fp
        push    r2
        push    r1
        mov     fp,sp
        lw      r0,9(fp)       ; arg: tagged fixnum
        lc      r1,2
        sra     r0,r1          ; untag
        la      r1,#xFF0100    ; UART data register
        sb      r0,0(r1)       ; write byte
        lw      r0,9(fp)       ; return the char (tagged)
        mov     sp,fp
        pop     r1
        pop     r2
        pop     fp
        jmp     (r1)
