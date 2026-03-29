; i2c.s -- I2C stub module (loaded at 0x3000)
; Prints "I2C" via uart-putc at 0x1000, then returns.

_i2c_xfer:
        push    fp
        push    r2
        push    r1
        mov     fp,sp
        ; Print 'I' (73*4=292)
        la      r0,292
        push    r0
        la      r0,#x1000
        jal     r1,(r0)
        add     sp,3
        ; Print '2' (50*4=200)
        la      r0,200
        push    r0
        la      r0,#x1000
        jal     r1,(r0)
        add     sp,3
        ; Print 'C' (67*4=268)
        la      r0,268
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
