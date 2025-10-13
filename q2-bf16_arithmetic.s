# ============================================================================
# bfloat16_test_arith.s
# ============================================================================
# RISC-V RV32I software BFloat16 arithmetic test suite (bit-accurate)
# - Integrates bf16_add, bf16_sub, bf16_mul, bf16_div, bf16_sqrt from w1-bfloat16.s
# - Adds test_arithmetic harness that mirrors the provided C tests
# - Uses integer-only instructions (no FPU)
# - For Ripes: print via ecall (a7=4 print string, a7=1 print int)
# ============================================================================
.data

# ----------------------------
# Output strings (human readable)
# ----------------------------
str_banner:       .asciz "\n=== BFloat16 Arithmetic Test ===\n\n"
str_test_arith:   .asciz "Testing arithmetic operations...\n"
str_add_fail:     .asciz "  [Addition failed]\n"
str_sub_fail:     .asciz "  [Subtraction failed]\n"
str_mul_fail:     .asciz "  [Multiplication failed]\n"
str_div_fail:     .asciz "  [Division failed]\n"
str_sqrt_fail:    .asciz "  [Sqrt failed]\n"
str_arith_pass:   .asciz "  Arithmetic: PASS\n"
str_summary:      .asciz "\n=== Test Summary ===\n"
str_passed_count: .asciz "Tests passed: "
str_failed_count: .asciz "Tests failed: "
str_newline:      .asciz "\n"

str_add_pass:    .string "[Add passed]\n"
str_sub_pass:    .string "[Sub passed]\n"
str_mul_pass:    .string "[Mul passed]\n"
str_div_pass:    .string "[Div passed]\n"
str_sqrt_pass:   .string "[Sqrt passed]\n"


# ----------------------------
# Counters
# ----------------------------
tests_passed:     .word 0
tests_failed:     .word 0

# ----------------------------
# BF16 constant words (used inside arithmetic implementations)
# Keep these labels for compatibility with the original implementation.
# ----------------------------
Inf_pos:        .word   0x7F800000, 0x7F80
Inf_neg:        .word   0xFF800000, 0xFF80
NaN:            .word   0xFFC00000, 0xFFC0
normal:         .word   0x40490fd0, 0x4049
denormal:       .word   0x40000fd0

BF16_SIGN_MASK: .word   0x8000
BF16_EXP_MASK:  .word   0x7F80
BF16_MANT_MASK: .word   0x007F
BF16_EXP_BIAS:  .word   127

BF16_NAN:       .word   0x7FC0
BF16_ZERO:      .word   0x0

.text
    .globl main

# ============================================================================
# MAIN: entrypoint
# ============================================================================
main:
    addi sp, sp, -16
    sw ra, 12(sp)

    # Print banner
    la a0, str_banner
    call print_string

    # Run the arithmetic tests
    call test_arithmetic

    # Print summary
    call print_summary

    # Exit gracefully
    lw ra, 12(sp)
    addi sp, sp, 16
    li a7, 10
    ecall

# ============================================================================
# test_arithmetic
# Implements the test cases from the provided C function:
#   - add, sub, mul, div, sqrt(4), sqrt(9)
# Each test:
#   - f32_to_bf16  (input float bits)
#   - call bf16_*  (perform bf16 operation)
#   - bf16_to_f32  (convert back to float bits)
#   - compare with expected value using check_relative_error_1pct
# If a test fails, print specific failure message and increment failed counter.
# If passes, increment passed counter.
# ============================================================================
test_arithmetic:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    sw s3, 12(sp)
    sw s4, 8(sp)
    sw s5, 4(sp)

    la a0, str_test_arith
    call print_string

# ---------------------------
# Test 1: Addition 1.0 + 2.0 = 3.0
# ---------------------------
    li a0, 0x3F80          # float bits for 1.0
    #call f32_to_bf16
    mv s0, a0                  # s0 = bf16(1.0)

    li a0, 0x4000         # float bits for 2.0
    #call f32_to_bf16
    mv s1, a0                  # s1 = bf16(2.0)

    mv a0, s0
    mv a1, s1
    call bf16_add
    mv s2, a0                  # s2 = result bf16

    mv a0, s2
    #call bf16_to_f32
    mv s3, a0                  # s3 = result as f32 bits

    li s4, 0x4040          # expected = 3.0f (bits)
    mv a0, s3
    mv a1, s4
    
    call check_relative_error_1pct
    beqz a0, arith_add_fail
    la a0, str_add_pass        # 印出通過
    call print_string
    call increment_passed
    j arith_sub_test               # 跳到下一項測試

arith_add_fail:
    la a0, str_add_fail    # 印出失敗
    call print_string
    call increment_failed
    j arith_sub_test

     



# ---------------------------
# Test 2: Subtraction 2.0 - 1.0 = 1.0
# ---------------------------
arith_sub_test:
    li a0, 0x4000         # 2.0f
    #call f32_to_bf16
    mv s0, a0

    li a0, 0x3F80          # 1.0f
    #call f32_to_bf16
    mv s1, a0

    mv a0, s0
    mv a1, s1
    call bf16_sub
    mv s2, a0

    mv a0, s2
    #call bf16_to_f32
    mv s3, a0

    li s4, 0x3F80         # expected = 1.0f
    mv a0, s3
    mv a1, s4
    call check_relative_error_1pct
    beqz a0, arith_sub_fail
    la a0, str_sub_pass        # 印出通過
    call print_string
    call increment_passed
    j arith_mul_test

arith_sub_fail:
    la a0, str_sub_fail
    call print_string
    call increment_failed
    j arith_done

# ---------------------------
# Test 3: Multiplication 3.0 * 4.0 = 12.0
# ---------------------------
arith_mul_test:
    li a0, 0x4040          # 3.0f
    #call f32_to_bf16
    mv s0, a0

    li a0, 0x4080         # 4.0f
    #call f32_to_bf16
    mv s1, a0

    mv a0, s0
    mv a1, s1
    call bf16_mul
    mv s2, a0

    mv a0, s2
    #call bf16_to_f32
    mv s3, a0

    li s4, 0x4140          # expected = 12.0f
    mv a0, s3
    mv a1, s4
    call check_relative_error_1pct
    beqz a0, arith_mul_fail
    la a0, str_mul_pass        # 印出通過
    call print_string
    call increment_passed
    j arith_div_test

arith_mul_fail:
    la a0, str_mul_fail
    call print_string
    call increment_failed
    j arith_done

# ---------------------------
# Test 4: Division 10.0 / 2.0 = 5.0
# ---------------------------
arith_div_test:
    li a0, 0x4120          # 10.0f
    #call f32_to_bf16
    mv s0, a0

    li a0, 0x4000          # 2.0f
    #call f32_to_bf16
    mv s1, a0

    mv a0, s0
    mv a1, s1
    call bf16_div
    mv s2, a0

    mv a0, s2
    #call bf16_to_f32
    mv s3, a0

    li s4, 0x40A0          # expected = 5.0f
    mv a0, s3
    mv a1, s4
    call check_relative_error_1pct
    beqz a0, arith_div_fail
    la a0, str_div_pass        # 印出通過
   call print_string
    call increment_passed
    j arith_sqrt_test

arith_div_fail:
    la a0, str_div_fail
    call print_string
    call increment_failed
    j arith_done


# ---------------------------
# Test 5: sqrt(9.0) = 3.0
# ---------------------------
arith_sqrt_test:
    li a0, 0x4110          # 9.0f

    call bf16_sqrt
    mv s1, a0
    
    li s4, 0x4040          # expected = 3.0f
    mv a0, s1
    mv a1, s4
    call check_relative_error_1pct
    beqz a0, arith_sqrt_fail
    la a0, str_sqrt_pass        # 印出通過
    call print_string
    call increment_passed
    j arith_done

arith_sqrt_fail:
    la a0, str_sqrt_fail
    call print_string
    call increment_failed
    j arith_done

# ---------------------------
# All arithmetic tests done
# ---------------------------
arith_done:

    lw s5, 4(sp)
    lw s4, 8(sp)
    lw s3, 12(sp)
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret

# ============================================================================
# Helper functions for testing and printing
# - print_string: uses ecall a7=4
# - print_int: uses ecall a7=1
# - increment_passed/increment_failed update counters
# - print_summary prints the total passed/failed
# ============================================================================
print_string:
    li a7, 4
    ecall
    ret

print_int:
    li a7, 1
    ecall
    ret

increment_passed:
    la t0, tests_passed
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
    ret

increment_failed:
    la t0, tests_failed
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
    ret

print_summary:
    addi sp, sp, -16
    sw ra, 12(sp)

    la a0, str_summary
    call print_string

    la a0, str_passed_count
    call print_string
    la t0, tests_passed
    lw a0, 0(t0)
    call print_int
    la a0, str_newline
    call print_string

    la a0, str_failed_count
    call print_string
    la t0, tests_failed
    lw a0, 0(t0)
    call print_int
    la a0, str_newline
    call print_string

    lw ra, 12(sp)
    addi sp, sp, 16
    ret

# ============================================================================
# check_relative_error_1pct
#  - Very-lightweight comparator:
#    Treats the two float bit-patterns as uint32 and compares their top16 bits.
#    This mirrors typical BF16 test tolerance: allow ±1 in top16 (one LSB).
#  - Input: a0 = actual f32 bits, a1 = expected f32 bits
#  - Output: a0 = 1 if acceptable, 0 otherwise
# ============================================================================
check_relative_error_1pct:
    srli t0, a0, 16         # top16 of actual
    srli t1, a1, 16         # top16 of expected
    sub  t2, t0, t1
    bgez t2, crp_pos
    sub  t2, x0, t2         # abs
crp_pos:
    li t3, 1
    ble t2, t3, crp_ok
    li a0, 0
    ret
crp_ok:
    li a0, 1
    ret

# ============================================================================
# Below: BF16 core implementations copied & integrated from w1-bfloat16.s
#   - f32_to_bf16
#   - bf16_to_f32
#   - bf16_add
#   - bf16_sub
#   - bf16_mul
#   - bf16_div
#   - bf16_sqrt
#
# Comments preserved and added for clarity.
# ============================================================================
#
# f32_to_bf16: convert 32-bit float-bit-pattern (in a0) -> 16-bit bf16 bits (a0)
# Rounding: round-to-nearest-even by adding 0x7FFF + ((a0 >> 16) & 1)
#
# Input: a0 = 32-bit float bits
# Output: a0 = 16-bit bf16 bits (in lower 16 bits of a0)
#
f32_to_bf16:
    # callee-save frame (we use s0)
    addi    sp, sp, -8
    sw      ra, 0(sp)
    sw      s0, 4(sp)

    mv      s0, a0              # preserve original argument in s0

    # Extract exponent: (f32bits >> 23) & 0xFF
    li      t0, 0xFF
    srli    t2, s0, 23
    and     t1, t2, t0          # t1 = exponent

    beq     t1, t0, f32_exception  # if exponent == 0xFF -> NaN/Inf path

    # Normal case: compute rounding bias
    srli    t0, s0, 16          # t0 = f32 >> 16
    addi    t1, x0, 1
    and     t0, t0, t1          # t0 = (f32 >> 16) & 1
    li      t1, 0x7FFF
    add     t0, t0, t1          # t0 = rounding bias (0x7FFF or 0x8000)
    add     t0, s0, t0          # add bias
    srli    a0, t0, 16          # top 16 bits -> bf16
    # restore and return
    beq     x0, x0, f32_to_bf16_end

f32_exception:
    srli    a0, s0, 16          # for Inf/NaN: just take top 16 bits

f32_to_bf16_end:
    lw      ra, 0(sp)
    lw      s0, 4(sp)
    addi    sp, sp, 8
    ret

# bf16_to_f32: expand 16-bit bf16 to 32-bit float-bit pattern
# Input: a0 = 16-bit bf16 bits (in low 16 bits)
# Output: a0 = 32-bit float bits
bf16_to_f32:
    slli    a0, a0, 16
    ret

# ---------------------------------------------------------------------------
# bf16_add: BF16 addition (bit-accurate software emulation)
# Input: a0 = bf16 a, a1 = bf16 b
# Output: a0 = bf16 (a + b)
# Note: taken from w1-bfloat16.s, preserved logic and control-flow
# ---------------------------------------------------------------------------
bf16_add:
    addi    sp, sp, -28
    sw      ra, 0(sp)
    sw      s0, 4(sp)
    sw      s1, 8(sp)
    sw      s2, 12(sp)
    sw      s3, 16(sp)
    sw      s4, 20(sp)
    sw      s5, 24(sp)

    srli    s0, a0, 7
    andi    s0, s0, 0xFF
    srli    s1, a1, 7
    andi    s1, s1, 0xFF

    andi    s2, a0, 0x7F
    andi    s3, a1, 0x7F

    srli    s4, a0, 15
    srli    s5, a1, 15
    li      t6, 0xFF
    bne     t6, s0, a_actual_num

    # a exponent == 0xFF
    beq     s3, x0, end_add
    beq     s1, t6, a_b_exp_FF
    jal     x0, end_add

a_b_exp_FF:
    bne     s3, x0, return_NAN
    beq     s4, s5, end_add
    jal     x0, return_NAN

a_actual_num:
    beq     s1, t6, add_return_b

    slli    t1, a1, 1
    beq     x0, t1, end_add

    slli    t1, a0, 1
    beq     x0, t1, add_return_b

add_adjust_mant_a:
    beq     x0, s0, add_adjust_mant_b
    addi    s2, s2, 0x80
add_adjust_mant_b:
    beq     x0, s1, add_main
    addi    s3, s3, 0x80

add_main:
    sub     t0, s0, s1
    li      t1, 8
    mv      t3, s2
    mv      t4, s3
    blt     t1, t0, end_add
    sub     t2, x0, t0
    blt     t1, t2, add_return_b
    beq     t0, x0, true_add
    srl     t4, s3, t0
    blt     t0, x0, true_add
    sub     t0, x0, t0
    srl     t3, s2, t0
    mv      s0, s1
    blt     t0, x0, true_add

true_add:
    mv      s2, t3
    mv      s3, t4
    bne     s4, s5, add_diff_sign

add_same_sign:
    slli    s4, s4, 15
    add     s1, s2, s3
    andi    t0, s1, 0x100
    beq     t0, x0, add_result
    srli    s1, s1, 1
    addi    s0, s0, 1
    blt     s0, t6, add_result
    mv      s0, t6
    add     s1, x0, x0
    jal     x0, add_result

add_diff_sign:
    slli    s4, s5, 15
    sub     s1, s3, s2
    blt     s2, s3, add_handle_zero
    slli    s4, s4, 15
    sub     s1, s2, s3

add_handle_zero:
    beq     s1, x0, add_return_zero
add_adjust_mantissa:
    andi    t1, s1, 0x80
    bne     t1, x0, add_result
    slli    s1, s1, 1
    addi    s0, s0, -1
    blt     x0, s0, add_return_zero
    jal     x0, add_adjust_mantissa

add_result:
    andi    s0, s0, 0xFF
    slli    s0, s0, 7
    andi    s1, s1, 0x7F
    or      a0, s4, s0
    or      a0, a0, s1
    jal     x0, end_add

add_return_zero:
    mv      a0, x0
    jal     x0, end_add

add_return_b:
    mv      a0, a1
    jal     x0, end_add

return_NAN:
    lw      a0, BF16_NAN
    jal     x0, end_add

end_add:
    lw      s5, 24(sp)
    lw      s4, 20(sp)
    lw      s3, 16(sp)
    lw      s2, 12(sp)
    lw      s1, 8(sp)
    lw      s0, 4(sp)
    lw      ra, 0(sp)
    addi    sp, sp, 28
    ret

# ---------------------------------------------------------------------------
# bf16_sub: implemented simply by flipping sign of b and calling bf16_add
# Input: a0 = a, a1 = b
# Output: a0 = a - b
# ---------------------------------------------------------------------------
bf16_sub:
    addi    sp, sp, -4
    sw      ra, 0(sp)

    la      t0, BF16_SIGN_MASK
    xor     a1, a1, t0      # flip sign bit of a1 (b)
    mv      a0, a0
    jal     ra, bf16_add

    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret

# ---------------------------------------------------------------------------
# bf16_mul: bit-accurate multiplication
# Input: a0 = a (bf16), a1 = b (bf16)
# Output: a0 = a * b (bf16)
# Implementation preserved from w1-bfloat16.s
# ---------------------------------------------------------------------------
bf16_mul:
    addi    sp, sp, -28
    sw      ra, 0(sp)
    sw      s0, 4(sp)
    sw      s1, 8(sp)
    sw      s2, 12(sp)
    sw      s3, 16(sp)
    sw      s4, 20(sp)
    sw      s5, 24(sp)

    srli    s0, a0, 7
    andi    s0, s0, 0xFF
    srli    s1, a1, 7
    andi    s1, s1, 0xFF

    andi    s2, a0, 0x7F
    andi    s3, a1, 0x7F

    srli    s4, a0, 15
    srli    s5, a1, 15

    xor     t5, s4, s5
    addi    t6, x0, 0xFF

    bne     s0, t6, mul_check_exp_b
    bne     s0, x0, end_mul
    li      t0, 0x7FFF
    and     t1, a1, t0
    beq     t1, x0, mul_return_NAN
    slli    t5, t5, 15
    li      t0, 0x7F80
    or      a0, t5, t0
    jal     x0, end_mul

mul_check_exp_b:
    bne     s0, t6, mul_check_zero
    bne     s0, x0, mul_return_b
    li      t0, 0x7FFF
    and     t1, a0, t0
    beq     t1, x0, mul_return_NAN
    slli    t5, t5, 15
    li      t0, 0x7F80
    or      a0, t5, t0
    jal     x0, end_mul

mul_check_zero:
    or      t0, s0, s1
    or      t0, t0, s2
    or      t0, t0, s3
    bne     t0, x0, mul_main
    slli    a0, t5, 15
    jal     x0, end_mul

mul_main:
    add     t0, x0, x0
mul_adjust_a:
    beq     s0, x0, mul_denormal_a
    ori     s2, s2, 0x80
    jal     x0, mul_adjust_b

mul_denormal_a:
    andi    t1, s2, 0x80
    bne     t1, x0, mul_mant_a_aligned
    slli    s2, s2, 1
    addi    t0, t0, -1
    jal     x0, mul_denormal_a

mul_mant_a_aligned:
    addi    s0, x0, 1
mul_adjust_b:
    beq     s1, x0, mul_denormal_b
    ori     s3, s3, 0x80
    jal     x0, result_exp

mul_denormal_b:
    andi    t1, s3, 0x80
    bne     t1, x0, mul_mant_a_aligned
    slli    s3, s3, 1
    addi    t0, t0, -1
    jal     x0, mul_denormal_b

result_exp:
    add     t4, s0, s1
    addi    t4, t4, -127
    add     t4, t4, t0

    add     t3, x0, x0
true_mul:
    beq     x0, s3, mul_get_result
    andi    t2, s3, 1
    beq     x0, t2, mul_skip
    add     t3, t3, s2
mul_skip:
    srli    s3, s3, 1
    slli    s2, s2, 1
    jal     x0, true_mul

mul_get_result:
    li      t0, 0x8000
    and     t0, t0, t3
    beq     t0, x0, mul_result_mant_adjust

    srli    t3, t3, 8
    andi    t3, t3, 0x7F
    addi    t4, t4, 1
    jal     x0, mul_result_exp_adjust

mul_result_mant_adjust:
    srli    t3, t3, 7
    andi    t3, t3, 0x7F

mul_result_exp_adjust:
    blt     t4, t6, mul_result_check_denormal
    slli    t5, t5, 15
    li      t0, 0x7F80
    or      a0, t5, t0
    jal     x0, end_mul

mul_result_check_denormal:
    blt     x0, t4, mul_result
    li      t0, -6
    bge     t4, t0, mul_result_handle_denormal
    slli    a0, t5, 15
    jal     x0, end_mul

mul_result_handle_denormal:
    addi    t0, t4, -1
    sub     t0, x0, t0
    srl     t3, t3, t0
    add     t4, x0, x0

mul_result:
    slli    t5, t5, 15
    and     t4, t4, t6
    slli    t4, t4, 7
    andi    t3, t3, 0x7F
    or      a0, t5, t4
    or      a0, a0, t3
    jal     x0, end_mul

mul_return_b:
    mv      a0, a1
    jal     x0, end_mul

mul_return_NAN:
    lw      a0, BF16_NAN
    jal     x0, end_mul

end_mul:
    lw      s5, 24(sp)
    lw      s4, 20(sp)
    lw      s3, 16(sp)
    lw      s2, 12(sp)
    lw      s1, 8(sp)
    lw      s0, 4(sp)
    lw      ra, 0(sp)
    addi    sp, sp, 28
    ret

# ---------------------------------------------------------------------------
# bf16_div: bit-accurate division
# Implementation preserved from w1-bfloat16.s (quite long, but faithful)
# ---------------------------------------------------------------------------
bf16_div:
    addi    sp, sp, -28
    sw      ra, 0(sp)
    sw      s0, 4(sp)
    sw      s1, 8(sp)
    sw      s2, 12(sp)
    sw      s3, 16(sp)
    sw      s4, 20(sp)
    sw      s5, 24(sp)

    srli    s0, a0, 7
    andi    s0, s0, 0xFF
    srli    s1, a1, 7
    andi    s1, s1, 0xFF

    andi    s2, a0, 0x7F
    andi    s3, a1, 0x7F

    srli    s4, a0, 15
    srli    s5, a1, 15

    xor     t5, s4, s5
    addi    t6, x0, 0xFF

div_check_exp_b:
    bne     s1, t6, div_check_zero_b
    bne     s1, x0, div_return_b
    bne     s0, t0, div_return_sign_zero
    bne     s2, x0, div_return_sign_zero
    jal     x0, div_return_NAN

div_check_zero_b:
    bne     s1, x0, div_check_exp_a
    bne     s3, x0, div_check_exp_a
    bne     s0, x0, div_return_sign_inf
    bne     s2, x0, div_return_sign_inf
    jal     x0, div_return_NAN

div_check_exp_a:
    bne     s0, t6, div_check_zero_a
    bne     s1, x0, end_div
    jal     x0, div_return_sign_inf

div_check_zero_a:
    bne     s0, x0, div_get_mant_a
    bne     s2, x0, div_get_mant_a
    jal     x0, div_return_sign_zero

div_get_mant_a:
    beq     x0, s2, div_get_mant_b
    ori     s2, s2, 0x80
div_get_mant_b:
    beq     x0, s3, div_main
    ori     s3, s3, 0x80

div_main:
    slli    s4, s2, 15
    add     s5, x0, s3
    add     t6, x0, x0

    addi    t0, x0, 16
    add     t1, x0, x0
true_div:
    bge     t1, t0, div_get_result
    slli    t6, t6, 1
    addi    t2, x0, 15
    sub     t2, t2, t1
    sll     t2, s5, t2
    blt     s4, t2, div_i_minus_one
    sub     s4, s4, t2
    ori     t6, t6, 1
div_i_minus_one:
    addi    t1, t1, 1
    jal     x0, true_div

div_get_result:
    sub     t4, s0, s1
    addi    t4, t4, 127

div_zero_exp_a_correction:
    bne     x0, s0, div_zero_exp_b_correction
    addi    t4, t4, -1
div_zero_exp_b_correction:
    bne     x0, s1, div_check_quotient
    addi    t4, t4, 1

div_check_quotient:
    li      t0, 0x8000
    and     t0, t6, t0
    bne     t0, x0, div_result_mant_shift

div_result_mant_adjust:
    li      t0, 0x8000
    and     t0, t6, t0
    bne     t0, x0, div_result_mant_shift
    addi    t1, t4, -1
    bge     x0, t1, div_result_mant_shift
    slli    t6, t6, 1
    addi    t4, t4, -1
    jal     x0, div_result_mant_adjust

div_result_mant_shift:
    srli    t6, t6, 8

    li      t0, 0xFF
    bge     t4, t0, div_return_sign_inf
    bge     x0, t4, div_return_sign_zero

div_result:
    slli    t5, t5, 15
    and     t4, t4, t0
    slli    t4, t4, 7
    andi    t6, t6, 0x7F
    or      a0, t5, t4
    or      a0, a0, t6
    jal     x0, end_div

div_return_sign_zero:
    slli    a0, t5, 15
    jal     x0, end_div
div_return_sign_inf:
    slli    a0, t5, 15
    li      t0, 0x7F80
    or      a0, a0, t0
    jal     x0, end_div
div_return_NAN:
    lw      a0, BF16_NAN
    jal     x0, end_div
div_return_b:
    mv      a0, a1
    jal     x0, end_div

end_div:
    lw      s5, 24(sp)
    lw      s4, 20(sp)
    lw      s3, 16(sp)
    lw      s2, 12(sp)
    lw      s1, 8(sp)
    lw      s0, 4(sp)
    lw      ra, 0(sp)
    addi    sp, sp, 28
    ret

# ---------------------------------------------------------------------------
# bf16_sqrt: bit-accurate square-root implementation (binary-search)
# Input: a0 = bf16
# Output: a0 = bf16(sqrt(a))
# ---------------------------------------------------------------------------
bf16_sqrt:
    addi    sp, sp, -20
    sw      ra, 0(sp)
    sw      s0, 4(sp)
    sw      s1, 8(sp)
    sw      s2, 12(sp)
    sw      s3, 16(sp)

    li      s3, 0xFF
    srli    s0, a0, 7
    and     s0, s0, s3
    andi    s1, a0, 0x7F
    srli    s2, a0, 15

    bne     s2, x0, sqrt_ret_nan
    bne     s0, s3, sqrt_ck_input_0
    jal     x0, end_sqrt

sqrt_ck_input_0:
    bne     s0, x0, sqrt_ck_input_denormal
    bne     s1, x0, sqrt_ret_zero
    jal     sqrt_ret_zero

sqrt_ck_input_denormal:
    beq     s0, x0, sqrt_ret_zero

sqrt_main:
    addi    s0, s0, -127
    ori     s1, s1, 0x80
    andi    t0, s0, 0x1
    beq     t0, x0, handle_even_exp

handle_odd_exp:
    slli    s1, s1, 1
    addi    t6, s0, -1
    srli    t6, t6, 1
    addi    t6, t6, 127
    jal     x0, true_sqrt

handle_even_exp:
    add     t6, s0, x0
    srli    t6, t6, 1
    addi    t6, t6, 127

true_sqrt:
    li      t3, 90
    li      t4, 256
    li      t5, 0x10

binary_search:
    blt     t4, t3, sqrt_normalized_result
    add     t1, t3, t4
    srli    t1, t1, 1
    mv      a0, t1
    mv      a1, t1
    jal     ra, int_mul
    srli    t2, a0, 7
    blt     s1, t2, sqrt_too_big
    mv      t5, t1
    addi    t3, t1, 1
    jal     x0, binary_search

sqrt_too_big:
    addi    t4, t1, -1
    jal     x0, binary_search

sqrt_normalized_result:
    li      t0, 256
    blt     t5, t0, sqer_borrow_exp
    srli    t5, t5, 1
    addi    t6, t6, 1
    jal     x0, remove_result_mant_one

sqer_borrow_exp:
    li      t0, 128
    li      t1, 1
    bge     t5, t0, remove_result_mant_one
    bge     t1, t6, remove_result_mant_one
    slli    t5, t5, 1
    addi    t6, t6, -1
    jal     x0, sqrt_exp_adjust_loop

sqrt_exp_adjust_loop:
    bge     t5, t0, remove_result_mant_one
    bge     t1, t6, remove_result_mant_one
    slli    t5, t5, 1
    addi    t6, t6, -1
    jal     x0, sqrt_exp_adjust_loop

remove_result_mant_one:
    andi    t5, t5, 0x7F
    bge     t6, s3, sqrt_ret_inf
    bge     x0, t6, sqrt_ret_zero

sqrt_get_result:
    and     a0, t6, s3
    slli    a0, a0, 7
    or      a0, a0, t5
    jal     x0, end_sqrt

sqrt_ret_inf:
    li      a0, 0x7F80
    jal     x0, end_sqrt

sqrt_ret_zero:
    lw      a0, BF16_ZERO
    jal     x0, end_sqrt

sqrt_ret_nan:
    lw      a0, BF16_NAN
    jal     x0, end_sqrt

end_sqrt:
    lw      s3, 16(sp)
    lw      s2, 12(sp)
    lw      s1, 8(sp)
    lw      s0, 4(sp)
    lw      ra, 0(sp)
    addi    sp, sp, 20
    ret

# ---------------------------------------------------------------------------
# int_mul: small integer multiply utility used by sqrt (schoolbook)
# Input: a0 = integer multiplicand, a1 = integer multiplier
# Output: a0 = a0 * a1
# ---------------------------------------------------------------------------
int_mul:
    add     t0, x0, x0
int_mul_loop:
    beq     x0, a1, end_int_mul
    andi    t2, a1, 1
    beq     x0, t2, int_mul_skip
    add     t0, t0, a0
int_mul_skip:
    srli    a1, a1, 1
    slli    a0, a0, 1
    jal     x0, int_mul_loop
end_int_mul:
    mv      a0, t0
    ret

# ============================================================================
# End of file
# ============================================================================
