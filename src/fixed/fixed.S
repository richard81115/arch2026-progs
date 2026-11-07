# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    addi    t0, x0, 0               # passes = 0
    beq     a1, x0, op1_done
op1_loop:
    and     t1, a0, a1              # carry bits
    xor     a0, a0, a1              # sum without carry
    slli    a1, t1, 1               # b = carry << 1
    addi    t0, t0, 1
    bne     a1, x0, op1_loop
op1_done:
    sw      t0, 0(a2)               # *n = passes
    ret
    .size   op1_asm, .-op1_asm

    .globl  op2_asm
    .type   op2_asm, @function
    .align  2
op2_asm:
    sub     a0, a0, a1
    ret
    .size   op2_asm, .-op2_asm

    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    and     t0, a0, a1
    xor     t1, a0, a1
    srli    t1, t1, 1
    add     a0, t0, t1
    ret
    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
q_mul_asm:
    addi    t0, a0, 0               # multiplicand, low word
    addi    t1, x0, 0               # multiplicand, high word
    addi    t2, a1, 0               # multiplier
    addi    t3, x0, 0               # product, low word
    addi    t4, x0, 0               # product, high word
    beq     t2, x0, qm_fix

qm_loop:
    andi    t5, t2, 1
    beq     t5, x0, qm_shift
    add     t3, t3, t0              # product += multiplicand
    sltu    t6, t3, t0              # carry out of the low word
    add     t4, t4, t1
    add     t4, t4, t6

qm_shift:
    srli    t6, t0, 31              # multiplicand <<= 1
    slli    t1, t1, 1
    or      t1, t1, t6
    slli    t0, t0, 1
    srli    t2, t2, 1
    bne     t2, x0, qm_loop

qm_fix:                             # signed correction of the high word
    bge     a0, x0, qm_fix_b
    sub     t4, t4, a1
qm_fix_b:
    bge     a1, x0, qm_round
    sub     t4, t4, a0

qm_round:
    lui     t5, 0x80                # 2^19, half a unit
    add     t3, t3, t5
    sltu    t6, t3, t5
    add     t4, t4, t6
    srli    t3, t3, 20              # bits 20..51 of the product
    slli    t4, t4, 12
    or      a0, t3, t4
    ret
    .size   q_mul_asm, .-q_mul_asm
