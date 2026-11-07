# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
    lui     t1, 0x7f800             # exponent mask 0x7F800000
    and     t0, a0, t1
    beq     t0, t1, f32_done        # Inf or NaN: keep the top half
    srli    t2, a0, 16
    andi    t2, t2, 1               # bit 16 breaks ties to even
    lui     t3, 0x8
    addi    t3, t3, -1              # 0x7FFF
    add     a0, a0, t3
    add     a0, a0, t2
f32_done:
    srli    a0, a0, 16
    ret
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2
bf16_mul_asm:
    xor     t0, a0, a1
    srli    t0, t0, 15
    slli    t0, t0, 15              # sign of the product
    srli    t1, a0, 7
    andi    t1, t1, 0xFF            # ea
    srli    t2, a1, 7
    andi    t2, t2, 0xFF            # eb
    andi    t3, a0, 0x7F            # ma
    andi    t4, a1, 0x7F            # mb
    addi    t5, x0, 0xFF

    beq     t1, t5, mul_a_special   # a first, then b
    beq     t2, t5, mul_b_special

    slli    a4, a0, 17              # a is a zero of either sign
    beq     a4, x0, mul_ret_zero
    slli    a4, a1, 17
    beq     a4, x0, mul_ret_zero

    addi    a2, x0, 0               # exponent adjustment
    bne     t1, x0, mul_a_norm
mul_a_den:                          # shift the leading one up
    slli    t3, t3, 1
    addi    a2, a2, -1
    andi    a4, t3, 0x80
    beq     a4, x0, mul_a_den
    addi    t1, x0, 1
    jal     x0, mul_b_check
mul_a_norm:
    ori     t3, t3, 0x80            # implicit one
mul_b_check:
    bne     t2, x0, mul_b_norm
mul_b_den:
    slli    t4, t4, 1
    addi    a2, a2, -1
    andi    a4, t4, 0x80
    beq     a4, x0, mul_b_den
    addi    t2, x0, 1
    jal     x0, mul_mult
mul_b_norm:
    ori     t4, t4, 0x80

mul_mult:                           # a3 = t3 * t4 by shift and add
    addi    a3, x0, 0
mul_loop:
    andi    a4, t4, 1
    beq     a4, x0, mul_skip
    add     a3, a3, t3
mul_skip:
    slli    t3, t3, 1
    srli    t4, t4, 1
    bne     t4, x0, mul_loop

    add     a2, a2, t1
    add     a2, a2, t2
    addi    a2, a2, -127            # biased result exponent

    srli    a4, a3, 15
    beq     a4, x0, mul_low
    srli    a5, a3, 8               # product in [2, 4)
    andi    a5, a5, 0x7F
    addi    a2, a2, 1
    jal     x0, mul_range
mul_low:
    srli    a5, a3, 7               # product in [1, 2)
    andi    a5, a5, 0x7F

mul_range:
    bge     a2, t5, mul_ret_inf
    blt     x0, a2, mul_pack
    addi    a4, x0, -6
    blt     a2, a4, mul_ret_zero
    addi    a4, x0, 1
    sub     a4, a4, a2
    srl     a5, a5, a4              # denormal result
    addi    a2, x0, 0

mul_pack:
    slli    a2, a2, 7
    or      a0, t0, a2
    or      a0, a0, a5
    ret

mul_a_special:
    beq     t3, x0, mul_a_inf
    ret                             # a is NaN
mul_a_inf:
    slli    a4, a1, 17
    beq     a4, x0, mul_ret_nan     # Inf times zero
    jal     x0, mul_ret_inf

mul_b_special:
    beq     t4, x0, mul_b_inf
    addi    a0, a1, 0               # b is NaN
    ret
mul_b_inf:
    slli    a4, a0, 17
    beq     a4, x0, mul_ret_nan
    jal     x0, mul_ret_inf

mul_ret_nan:
    lui     a0, 0x8
    addi    a0, a0, -64             # 0x7FC0
    ret
mul_ret_inf:
    lui     a4, 0x8
    addi    a4, a4, -128            # 0x7F80
    or      a0, t0, a4
    ret
mul_ret_zero:
    addi    a0, t0, 0
    ret
    .size   bf16_mul_asm, .-bf16_mul_asm

    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2

bf16_sqrt_asm:
    srli t0, a0, 7
    andi t0, t0, 0xFF
    andi t1, a0, 0x7F

    addi t5, x0, 0xFF
    beq  t0, t5, sq_special
    slli a4, a0, 17
    beq  a4, x0, sq_ret_zero
    srli a4, a0, 15
    bne  a4, x0, sq_ret_nan
    beq  t0, x0, sq_ret_zero

    ori  t1, t1, 0x80
    andi a4, t0, 1
    bne  a4, x0, sq_even
    slli t1, t1, 1

sq_even:
    addi t2, t0, 127
    srli t2, t2, 1

    addi t1, t1, 1
    slli t1, t1, 7
    addi t1, t1, -1

    addi t3, x0, 0
    lui  t4, 0x4

sq_loop:
    add  a4, t3, t4
    bltu t1, a4, sq_no
    sub  t1, t1, a4
    srli t3, t3, 1
    add  t3, t3, t4
    jal  x0, sq_next

sq_no:
    srli t3, t3, 1

sq_next:
    srli t4, t4, 2
    bne  t4, x0, sq_loop

    slli t2, t2, 7
    andi t3, t3, 0x7F
    or   a0, t2, t3
    ret

sq_special:
    beq  t1, x0, sq_inf
    ret
sq_inf:
    srli a4, a0, 15
    bne  a4, x0, sq_ret_nan
    ret

sq_ret_nan:
    lui  a0, 0x8
    addi a0, a0, -64
    ret

sq_ret_zero:
    addi a0, x0, 0
    ret
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm

