; timer.s -- Timer stub module (loaded at 0x5000)
; Prints "TMR" via uart-putc at 0x1000, then returns.

_timer_op:
        push    fp
        push    r2
        push    r1
        mov     fp,sp
        ; Print 'T' (84*4=336)
        la      r0,336
        push    r0
        la      r0,#x1000
        jal     r1,(r0)
        add     sp,3
        ; Print 'M' (77*4=308)
        la      r0,308
        push    r0
        la      r0,#x1000
        jal     r1,(r0)
        add     sp,3
        ; Print 'R' (82*4=328)
        la      r0,328
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
