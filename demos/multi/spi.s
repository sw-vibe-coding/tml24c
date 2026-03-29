; spi.s -- SPI stub module (loaded at 0x2000)
; Prints "SPI" via uart-putc at 0x1000, then returns.

_spi_xfer:
        push    fp
        push    r2
        push    r1
        mov     fp,sp
        ; Print 'S' (83*4=332)
        la      r0,332
        push    r0
        la      r0,#x1000
        jal     r1,(r0)
        add     sp,3
        ; Print 'P' (80*4=320)
        la      r0,320
        push    r0
        la      r0,#x1000
        jal     r1,(r0)
        add     sp,3
        ; Print 'I' (73*4=292)
        la      r0,292
        push    r0
        la      r0,#x1000
        jal     r1,(r0)
        add     sp,3
        ; Print '\n' (10*4=40)
        lc      r0,40
        push    r0
        la      r0,#x1000
        jal     r1,(r0)
        add     sp,3
        ; return
        mov     sp,fp
        pop     r1
        pop     r2
        pop     fp
        jmp     (r1)
