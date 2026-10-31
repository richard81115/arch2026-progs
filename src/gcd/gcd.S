# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tgcd.c.

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2
gcd_u32_asm:
    beq     a0, x0, ret_b
    beq     a1, x0, ret_a
    addi    t0, x0, 0               # k = 0

shared_twos:
    or      t1, a0, a1
    andi    t1, t1, 1
    bnez    t1, make_a_odd
    srli    a0, a0, 1
    srli    a1, a1, 1
    addi    t0, t0, 1
    j       shared_twos

make_a_odd:
    andi    t1, a0, 1
    bnez    t1, loop
    srli    a0, a0, 1
    j       make_a_odd

loop:
    andi    t1, a1, 1
    beqz    t1, b_loop

loop_continue:
    bgeu    a1, a0, a_not_greater
    sub     a0, a0, a1

a_loop:
    srli    a0, a0, 1
    andi    t1, a0, 1
    beqz    t1, a_loop
    j       loop_continue

a_not_greater:
    sub     a1, a1, a0
    beqz    a1, done

b_loop:
    srli    a1, a1, 1
    andi    t1, a1, 1
    beqz    t1, b_loop
    j       loop_continue

done:
    sll     a0, a0, t0
    ret

ret_b:
    mv      a0, a1

ret_a:
    ret
    .size   gcd_u32_asm, .-gcd_u32_asm
