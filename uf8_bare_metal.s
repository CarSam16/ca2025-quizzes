    .data
msg1:   .asciz ": produces value "
msg2:   .asciz " but encodes back to "
msg3:   .asciz ": value "
msg4:   .asciz " <= previous_value "
msg5:   .asciz "All tests passed.\n"
msg6:   .asciz "Some tests failed.\n"
newline: .asciz "\n"

    .align 2
    .text
    .globl main

main:
    jal ra, test        # start test
    j hang              # 程式結束後跳到 hang（不要 RARS syscall）

# --------------------- test function ---------------------
test:
    addi sp, sp, -4
    sw ra, 0(sp)
    addi s0, x0, -1
    li s1, 1
    li s2, 0
    li s3, 256

For_2:
    add a0, s2, x0
    jal ra, uf8_decode
    add s4, a0, x0
    add a0, s4, x0
    jal ra, uf8_encode
    add s5, a0, x0

    # 檢查是否通過
    beq s2, s5, test_if_2
    li s1, 0
test_if_2:
    blt s0, s4, after_if
after_if:
    mv s0, s4
    addi s2, s2, 1
    blt s2, s3, For_2

    mv a0, s1
    lw ra, 0(sp)
    addi sp, sp, 4
    jr ra

# --------------------- CLZ ---------------------
CLZ_myfunction:
    li t0, 32
    li t1, 16
do_while:
    srl t2, a0, t1
    bnez t2, if_loop
    srli t1, t1, 1
    beqz t1, end_loop
    j do_while
if_loop:
    sub t0, t0, t1
    add a0, t2, x0
    srli t1, t1, 1
    beqz t1, end_loop
    j do_while
end_loop:
    sub a0, t0, a0
    jr ra

# --------------------- uf8 decode ---------------------
uf8_decode:
    andi t1, a0, 0x0f
    srli t2, a0, 4
    li t3, 15
    sub t3, t3, t2
    li t4, 0x7FFF
    srl t3, t4, t3
    slli t3, t3, 4
    sll t1, t1, t2
    add a0, t1, t3
    jr ra

# --------------------- uf8 encode ---------------------
uf8_encode:
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s0, 4(sp)
    add s0, a0, x0
    li t0, 16
    blt s0, t0, end_encode
    jal ra, CLZ_myfunction
    li t0, 31
    sub t0, t0, a0
    li a1, 0
    li a2, 0
end_encode:
    sub t2, s0, a2
    srl t2, t2, a1
    slli a1, a1, 4
    or a0, a1, t2
    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 8
    jr ra
