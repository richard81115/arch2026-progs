# rubik_solve_asm: hand-written RV32I solver.
#
# int rubik_solve_asm(const char *state, char *out, size_t cap)
#   a0, a1, a2 -> a0
#
# Iterative deepening with the permutation and orientation distances, ending
# in a binary search of the states within five moves (rubik_data.S).
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/trubik.c.

    .section .rodata
    .align  2
rs_perm_off:
    .word   0, 10080, 20160         # face * 5040 * 2
rs_ori_off:
    .word   0, 1458, 2916           # face * 729 * 2
rs_factorial:
    .half   720, 120, 24, 6, 2, 1, 1
rs_face_letter:
    .byte   'R', 'B', 'D'
rs_turn_suffix:
    .byte   ' ', '2', '\''

    .bss
    .align  1
rs_level_p: .space 24
rs_level_o: .space 24
rs_chain_p: .space 24
rs_chain_o: .space 24
rs_face:    .space 12
rs_turn:    .space 12
rs_prev:    .space 12
rs_path:    .space 12

    .text
    .globl  rubik_solve_asm
    .type   rubik_solve_asm, @function
    .align  2
rubik_solve_asm:
    addi    sp, sp, -64
    sw      ra, 48(sp)
    sw      s0, 44(sp)
    sw      s1, 40(sp)
    sw      s2, 36(sp)
    sw      s3, 32(sp)
    sw      s4, 28(sp)
    sw      s5, 24(sp)
    sw      s6, 20(sp)
    sw      s7, 16(sp)
    sw      s8, 12(sp)
    sw      s9, 8(sp)
    sw      s10, 4(sp)
    sw      s11, 0(sp)
    addi    s0, a1, 0               # out
    addi    s1, a2, 0               # cap

    # ---- (1) validate ----
    addi    t0, x0, 0
    addi    t2, x0, 14
rs_len:
    add     t1, a0, t0
    lbu     t1, 0(t1)
    beq     t1, x0, rs_invalid
    addi    t0, t0, 1
    blt     t0, t2, rs_len
    lbu     t1, 14(a0)
    bne     t1, x0, rs_invalid

    addi    t3, x0, 0               # seen cubies
    addi    t0, x0, 0
    addi    t2, x0, 7
rs_perm:
    add     t1, a0, t0
    lbu     t1, 0(t1)
    addi    t1, t1, -49             # '1' -> 0
    bgeu    t1, t2, rs_invalid
    addi    t4, x0, 1
    sll     t4, t4, t1
    and     t5, t3, t4
    bne     t5, x0, rs_invalid
    or      t3, t3, t4
    addi    t0, t0, 1
    blt     t0, t2, rs_perm

    addi    t3, x0, 0               # orientation sum modulo 3
    addi    t2, x0, 14
    addi    t4, x0, 3
rs_ori:
    add     t1, a0, t0
    lbu     t1, 0(t1)
    addi    t1, t1, -49
    bgeu    t1, t4, rs_invalid
    add     t3, t3, t1
    bltu    t3, t4, rs_ori_skip
    sub     t3, t3, t4
rs_ori_skip:
    addi    t0, t0, 1
    blt     t0, t2, rs_ori
    bne     t3, x0, rs_invalid

    # ---- (2) parse: s2 = permutation rank, s3 = orientation rank ----
    addi    s2, x0, 0
    addi    t0, x0, 0
    la      t5, rs_factorial
rs_p_outer:
    add     t1, a0, t0
    lbu     t1, 0(t1)
    slli    t6, t0, 1
    add     t6, t5, t6
    lhu     t6, 0(t6)
    addi    t2, t0, 1
rs_p_inner:
    addi    t4, x0, 7
    bge     t2, t4, rs_p_next
    add     t3, a0, t2
    lbu     t3, 0(t3)
    bgeu    t3, t1, rs_p_skip
    add     s2, s2, t6
rs_p_skip:
    addi    t2, t2, 1
    jal     x0, rs_p_inner
rs_p_next:
    addi    t0, t0, 1
    addi    t4, x0, 6
    blt     t0, t4, rs_p_outer

    addi    s3, x0, 0
    addi    t0, x0, 7
rs_o_loop:
    add     t1, a0, t0
    lbu     t1, 0(t1)
    addi    t1, t1, -49
    slli    t3, s3, 1
    add     s3, s3, t3
    add     s3, s3, t1
    addi    t0, t0, 1
    addi    t4, x0, 13
    blt     t0, t4, rs_o_loop

    # ---- (3) search ----
    la      s8, rubik_perm_move
    la      s9, rubik_orient_move
    la      s10, rubik_perm_dist
    la      s11, rubik_orient_dist

    addi    a3, s2, 0               # the start state may be within five moves
    addi    a4, s3, 0
    slli    a0, a3, 10
    or      a0, a0, a4
    jal     ra, rs_near_find
    addi    t0, x0, -1
    beq     a0, t0, rs_start_search
    srli    s7, a0, 4
    andi    s7, s7, 7
    addi    a5, x0, 0
    jal     x0, rs_finish

rs_start_search:                    # bound = max(h, 6)
    add     t0, s10, s2
    lbu     t0, 0(t0)
    add     t1, s11, s3
    lbu     t1, 0(t1)
    addi    s4, t0, 0
    bgeu    s4, t1, rs_init_bound
    addi    s4, t1, 0
rs_init_bound:
    addi    t0, x0, 6
    bge     s4, t0, rs_bound_loop
    addi    s4, t0, 0

rs_bound_loop:
    addi    s5, x0, 255             # next bound
    la      t0, rs_level_p
    sh      s2, 0(t0)
    la      t0, rs_chain_p
    sh      s2, 0(t0)
    la      t0, rs_level_o
    sh      s3, 0(t0)
    la      t0, rs_chain_o
    sh      s3, 0(t0)
    addi    t1, x0, 3
    la      t0, rs_prev
    sb      t1, 0(t0)
    la      t0, rs_face
    sb      x0, 0(t0)
    la      t0, rs_turn
    sb      x0, 0(t0)
    addi    s6, x0, 0               # depth

rs_node:
    la      t1, rs_face
    add     t1, t1, s6
    lbu     t0, 0(t1)
    addi    t2, x0, 3
    blt     t0, t2, rs_expand
    bne     s6, x0, rs_backtrack
    addi    s4, s5, 0               # pass failed: raise the bound
    jal     x0, rs_bound_loop
rs_backtrack:
    addi    s6, s6, -1
    jal     x0, rs_node

rs_expand:                          # t0 = face
    slli    t4, s6, 1
    la      t3, rs_chain_p
    add     t3, t3, t4
    lhu     t1, 0(t3)
    la      t3, rs_chain_o
    add     t3, t3, t4
    lhu     t2, 0(t3)

    slli    t3, t0, 2
    la      t4, rs_perm_off
    add     t4, t4, t3
    lw      t4, 0(t4)
    add     t4, s8, t4
    slli    t3, t1, 1
    add     t4, t4, t3
    lhu     a3, 0(t4)               # np

    slli    t3, t0, 2
    la      t4, rs_ori_off
    add     t4, t4, t3
    lw      t4, 0(t4)
    add     t4, s9, t4
    slli    t3, t2, 1
    add     t4, t4, t3
    lhu     a4, 0(t4)               # no

    slli    t4, s6, 1
    la      t3, rs_chain_p
    add     t3, t3, t4
    sh      a3, 0(t3)
    la      t3, rs_chain_o
    add     t3, t3, t4
    sh      a4, 0(t3)

    la      t1, rs_turn
    add     t1, t1, s6
    lbu     t2, 0(t1)
    slli    t3, t0, 1
    add     t3, t3, t0
    add     t3, t3, t2              # move = face * 3 + turn
    la      t4, rs_path
    add     t4, t4, s6
    sb      t3, 0(t4)

    addi    t2, t2, 1
    addi    t3, x0, 3
    bne     t2, t3, rs_exp_turn_save

    addi    t3, t0, 1               # next face, skipping the previous one
    la      t4, rs_prev
    add     t4, t4, s6
    lbu     t4, 0(t4)
    bne     t3, t4, rs_exp_face_ok
    addi    t3, t3, 1
rs_exp_face_ok:
    la      t4, rs_face
    add     t4, t4, s6
    sb      t3, 0(t4)
    sb      x0, 0(t1)
    slli    t4, s6, 1
    la      t3, rs_level_p
    add     t3, t3, t4
    lhu     t2, 0(t3)
    la      t3, rs_chain_p
    add     t3, t3, t4
    sh      t2, 0(t3)
    la      t3, rs_level_o
    add     t3, t3, t4
    lhu     t2, 0(t3)
    la      t3, rs_chain_o
    add     t3, t3, t4
    sh      t2, 0(t3)
    jal     x0, rs_exp_done_turn
rs_exp_turn_save:
    sb      t2, 0(t1)

rs_exp_done_turn:
    addi    a6, t0, 0               # face of this child
    addi    a5, s6, 1               # g

    add     t1, s10, a3
    lbu     t1, 0(t1)
    add     t2, s11, a4
    lbu     t2, 0(t2)
    bgeu    t1, t2, rs_exp_f
    addi    t1, t2, 0
rs_exp_f:
    add     t1, t1, a5              # f = g + h
    bge     s4, t1, rs_exp_check_near
    bge     t1, s5, rs_exp_node_jump
    addi    s5, t1, 0
rs_exp_node_jump:
    jal     x0, rs_node

rs_exp_check_near:
    sub     t2, s4, a5              # moves left within the bound
    addi    t3, x0, 5
    blt     t3, t2, rs_descend

    addi    a7, t2, 0
    slli    a0, a3, 10
    or      a0, a0, a4
    jal     ra, rs_near_find
    addi    t0, x0, -1
    bne     a0, t0, rs_exp_near_hit
    addi    t1, x0, 6
    jal     x0, rs_exp_near_eval
rs_exp_near_hit:
    srli    t1, a0, 4
    andi    t1, t1, 7
rs_exp_near_eval:
    blt     a7, t1, rs_exp_near_fail
    add     s7, a5, t1              # solution length
    jal     x0, rs_finish
rs_exp_near_fail:
    add     t1, t1, a5
    bge     t1, s5, rs_exp_no_s5
    addi    s5, t1, 0
rs_exp_no_s5:
    jal     x0, rs_node

rs_descend:
    addi    s6, a5, 0
    slli    t0, s6, 1
    la      t1, rs_level_p
    add     t1, t1, t0
    sh      a3, 0(t1)
    la      t1, rs_chain_p
    add     t1, t1, t0
    sh      a3, 0(t1)
    la      t1, rs_level_o
    add     t1, t1, t0
    sh      a4, 0(t1)
    la      t1, rs_chain_o
    add     t1, t1, t0
    sh      a4, 0(t1)
    la      t1, rs_prev
    add     t1, t1, s6
    sb      a6, 0(t1)
    sltiu   t2, a6, 1               # first face: 1 after face 0, else 0
    la      t1, rs_face
    add     t1, t1, s6
    sb      t2, 0(t1)
    la      t1, rs_turn
    add     t1, t1, s6
    sb      x0, 0(t1)
    jal     x0, rs_node

rs_finish:                          # a3, a4 = state, a0 = entry, a5 = index
    srli    t0, a0, 4
    andi    t0, t0, 7
    beq     t0, x0, rs_output
    andi    t1, a0, 15
    la      t6, rs_path
    add     t6, t6, a5
    sb      t1, 0(t6)
    addi    a5, a5, 1

    addi    t2, x0, 0
    addi    t6, x0, 3
    blt     t1, t6, rs_fin_face_done
    sub     t1, t1, t6
    addi    t2, x0, 1
    blt     t1, t6, rs_fin_face_done
    sub     t1, t1, t6
    addi    t2, x0, 2
rs_fin_face_done:
    slli    t0, t2, 2
    la      t3, rs_perm_off
    add     t3, t3, t0
    lw      t3, 0(t3)
    add     t3, s8, t3
    la      t4, rs_ori_off
    add     t4, t4, t0
    lw      t4, 0(t4)
    add     t4, s9, t4
rs_fin_apply_loop:                  # turn + 1 quarter turns
    slli    t5, a3, 1
    add     t5, t3, t5
    lhu     a3, 0(t5)
    slli    t5, a4, 1
    add     t5, t4, t5
    lhu     a4, 0(t5)
    addi    t1, t1, -1
    bge     t1, x0, rs_fin_apply_loop
    slli    a0, a3, 10
    or      a0, a0, a4
    jal     ra, rs_near_find
    jal     x0, rs_finish

    # ---- (4) output ----
rs_output:                          # s7 = moves, path[] filled
    bne     s7, x0, rs_calc_need
    addi    t1, x0, 1
    jal     x0, rs_check
rs_calc_need:                       # 2n plus one per suffix
    slli    t1, s7, 1
    addi    t0, x0, 0
rs_need_loop:
    la      t2, rs_path
    add     t2, t2, t0
    lbu     t2, 0(t2)
    addi    t3, x0, 3
    blt     t2, t3, rs_need_turn_done
    sub     t2, t2, t3
    blt     t2, t3, rs_need_turn_done
    sub     t2, t2, t3
rs_need_turn_done:
    beq     t2, x0, rs_need_skip
    addi    t1, t1, 1
rs_need_skip:
    addi    t0, t0, 1
    blt     t0, s7, rs_need_loop

rs_check:
    bgeu    s1, t1, rs_write_start
    beq     s1, x0, rs_cap_zero
    sb      x0, 0(s0)
rs_cap_zero:
    addi    a0, x0, -2
    jal     x0, rs_return

rs_write_start:
    addi    t0, x0, 0
    addi    t2, s0, 0
rs_write_loop:
    bge     t0, s7, rs_write_end
    beq     t0, x0, rs_w_nospace
    addi    t3, x0, 32              # ' '
    sb      t3, 0(t2)
    addi    t2, t2, 1
rs_w_nospace:
    la      t3, rs_path
    add     t3, t3, t0
    lbu     t4, 0(t3)
    addi    t3, x0, 0
    addi    t5, x0, 3
    blt     t4, t5, rs_wf_done
    sub     t4, t4, t5
    addi    t3, x0, 1
    blt     t4, t5, rs_wf_done
    sub     t4, t4, t5
    addi    t3, x0, 2
rs_wf_done:
    la      t5, rs_face_letter
    add     t5, t5, t3
    lbu     t5, 0(t5)
    sb      t5, 0(t2)
    addi    t2, t2, 1
    beq     t4, x0, rs_w_noturn
    la      t5, rs_turn_suffix
    add     t5, t5, t4
    lbu     t5, 0(t5)
    sb      t5, 0(t2)
    addi    t2, t2, 1
rs_w_noturn:
    addi    t0, t0, 1
    jal     x0, rs_write_loop
rs_write_end:
    sb      x0, 0(t2)
    addi    a0, s7, 0
    jal     x0, rs_return

rs_invalid:
    addi    a0, x0, -1
rs_return:
    lw      s11, 0(sp)
    lw      s10, 4(sp)
    lw      s9, 8(sp)
    lw      s8, 12(sp)
    lw      s7, 16(sp)
    lw      s6, 20(sp)
    lw      s5, 24(sp)
    lw      s4, 28(sp)
    lw      s3, 32(sp)
    lw      s2, 36(sp)
    lw      s1, 40(sp)
    lw      s0, 44(sp)
    lw      ra, 48(sp)
    addi    sp, sp, 64
    ret
    .size   rubik_solve_asm, .-rubik_solve_asm

# rs_near_find: search rubik_near_table for a key without a loop.
#   a0 = key -> a0 = entry, or -1 when absent. Uses t0 to t3 only.
# t2 points at table[p]; every entry before p is below target = key << 7.
# The first step is 4032 entries, which leaves 8192 = 2^13 for the rest.
    .type   rs_near_find, @function
    .align  2
rs_near_find:
    slli    t0, a0, 7               # target
    la      t2, rubik_near_table

    li      t3, 16124               # step 4032
    add     t3, t2, t3
    lw      t1, 0(t3)
    bgeu    t1, t0, rs_nf_skip0
    addi    t2, t3, 4
rs_nf_skip0:
    li      t3, 16380               # step 4096
    add     t3, t2, t3
    lw      t1, 0(t3)
    bgeu    t1, t0, rs_nf_skip1
    addi    t2, t3, 4
rs_nf_skip1:
    li      t3, 8188                # step 2048
    add     t3, t2, t3
    lw      t1, 0(t3)
    bgeu    t1, t0, rs_nf_skip2
    addi    t2, t3, 4
rs_nf_skip2:
    li      t3, 4092                # step 1024
    add     t3, t2, t3
    lw      t1, 0(t3)
    bgeu    t1, t0, rs_nf_skip3
    addi    t2, t3, 4
rs_nf_skip3:
    addi    t3, t2, 2044            # step 512
    lw      t1, 0(t3)
    bgeu    t1, t0, rs_nf_skip4
    addi    t2, t3, 4
rs_nf_skip4:
    lw      t1, 1020(t2)            # step 256
    bgeu    t1, t0, rs_nf_skip5
    addi    t2, t2, 1024
rs_nf_skip5:
    lw      t1, 508(t2)             # step 128
    bgeu    t1, t0, rs_nf_skip6
    addi    t2, t2, 512
rs_nf_skip6:
    lw      t1, 252(t2)             # step 64
    bgeu    t1, t0, rs_nf_skip7
    addi    t2, t2, 256
rs_nf_skip7:
    lw      t1, 124(t2)             # step 32
    bgeu    t1, t0, rs_nf_skip8
    addi    t2, t2, 128
rs_nf_skip8:
    lw      t1, 60(t2)              # step 16
    bgeu    t1, t0, rs_nf_skip9
    addi    t2, t2, 64
rs_nf_skip9:
    lw      t1, 28(t2)              # step 8
    bgeu    t1, t0, rs_nf_skip10
    addi    t2, t2, 32
rs_nf_skip10:
    lw      t1, 12(t2)              # step 4
    bgeu    t1, t0, rs_nf_skip11
    addi    t2, t2, 16
rs_nf_skip11:
    lw      t1, 4(t2)               # step 2
    bgeu    t1, t0, rs_nf_skip12
    addi    t2, t2, 8
rs_nf_skip12:
    lw      t1, 0(t2)               # step 1
    bgeu    t1, t0, rs_nf_skip13
    addi    t2, t2, 4
rs_nf_skip13:
    lw      t1, 0(t2)               # first entry not below target
    srli    t3, t1, 7
    bne     t3, a0, rs_nf_miss
    addi    a0, t1, 0
    ret
rs_nf_miss:
    addi    a0, x0, -1
    ret
    .size   rs_near_find, .-rs_near_find
