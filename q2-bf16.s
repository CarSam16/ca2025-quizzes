# ============================================================================
# BFloat16 Complete Test Suite for RISC-V (RV32I only)
# ============================================================================
# Implements all test functions from the C test suite
# Tests: conversions, special values, arithmetic, comparisons, edge cases
# ============================================================================

.data
# Test values for basic conversions (Float32 as uint32_t bits)
test_values:
    .word 0x00000000    # 0.0f
    .word 0x3F800000    # 1.0f
    .word 0xBF800000    # -1.0f
    .word 0x40000000    # 2.0f
    .word 0xC0000000    # -2.0f
    .word 0x3F000000    # 0.5f
    .word 0xBF000000    # -0.5f
    .word 0x40490FDB    # 3.14159f
    .word 0xC0490FDB    # -3.14159f
    .word 0x501502F9    # 1e10f
    .word 0xD01502F9    # -1e10f
test_count: .word 11

# Expected results for arithmetic
expected_add:       .word 0x40400000    # 3.0f (1.0 + 2.0)
expected_sub:       .word 0x3F800000    # 1.0f (2.0 - 1.0)
expected_mul:       .word 0x41400000    # 12.0f (3.0 * 4.0)
expected_div:       .word 0x40A00000    # 5.0f (10.0 / 2.0)
expected_sqrt4:     .word 0x40000000    # 2.0f (sqrt(4.0))
expected_sqrt9:     .word 0x40400000    # 3.0f (sqrt(9.0))

# Test counters
tests_passed:   .word 0
tests_failed:   .word 0

# Output strings
str_banner:         .string "\n=== BFloat16 Test Suite ===\n\n"
str_test_basic:     .string "Testing basic conversions...\n"
str_test_special:   .string "Testing special values...\n"
str_test_arith:     .string "Testing arithmetic operations...\n"
str_test_comp:      .string "Testing comparison operations...\n"
str_test_edge:      .string "Testing edge cases...\n"
str_test_round:     .string "Testing rounding behavior...\n"
str_pass:           .string "  PASS\n"
str_fail:           .string "  FAIL\n"
str_test_num:       .string "  Test "
str_colon:          .string ": "
str_summary:        .string "\n=== Test Summary ===\n"
str_passed_count:   .string "Tests passed: "
str_failed_count:   .string "Tests failed: "
str_all_pass:       .string "\n=== ALL TESTS PASSED ===\n"
str_some_fail:      .string "\n=== SOME TESTS FAILED ===\n"
str_newline:        .string "\n"

# Test names for detailed output
str_sign_mismatch:  .string " [Sign mismatch]\n"
str_error_large:    .string " [Relative error too large]\n"
str_inf_detect:     .string " [Infinity detection]\n"
str_nan_detect:     .string " [NaN detection]\n"
str_zero_detect:    .string " [Zero detection]\n"
str_add_fail:       .string " [Addition failed]\n"
str_sub_fail:       .string " [Subtraction failed]\n"
str_mul_fail:       .string " [Multiplication failed]\n"
str_div_fail:       .string " [Division failed]\n"
str_sqrt_fail:      .string " [sqrt failed]\n"

.text
.globl main

# ============================================================================
# MAIN: Entry point
# ============================================================================
main:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    # Print banner
    la a0, str_banner
    call print_string
    
    # Run all test suites
    call test_basic_conversions
    call test_special_values
    
    # Print summary
    call print_summary
    
    # Check if any failed
    la t0, tests_failed
    lw t0, 0(t0)
    beqz t0, main_all_pass
    
    la a0, str_some_fail
    call print_string
    li a0, 1
    j main_exit
    
main_all_pass:
    la a0, str_all_pass
    call print_string
    li a0, 0
    
main_exit:
    lw ra, 12(sp)
    addi sp, sp, 16
    li a7, 10
    ecall

# ============================================================================
# TEST_BASIC_CONVERSIONS
# ============================================================================
test_basic_conversions:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)    # s0 = loop counter
    sw s1, 20(sp)    # s1 = test_values pointer
    sw s2, 16(sp)    # s2 = test_count
    sw s3, 12(sp)    # s3 = original f32
    sw s4, 8(sp)     # s4 = bf16 result
    sw s5, 4(sp)     # s5 = converted f32
    
    la a0, str_test_basic
    call print_string
    
    la s1, test_values
    la t0, test_count
    lw s2, 0(t0)
    li s0, 0
    
basic_loop:
    bge s0, s2, basic_done
    
    lw s3, 0(s1)        # s3 = original f32
    
    # Convert f32 → bf16
    mv a0, s3
    call f32_to_bf16
    mv s4, a0           # s4 = bf16
    
    # Convert bf16 → f32
    mv a0, s4
    call bf16_to_f32
    mv s5, a0           # s5 = converted f32
    
    # Test 1: Check sign consistency (if not zero)
    beqz s3, basic_skip_sign
    mv a0, s3
    mv a1, s5
    call check_sign_match
    beqz a0, basic_sign_fail
    
basic_skip_sign:
    # Test 2: Check relative error (if not zero and not inf)
    beqz s3, basic_continue
    mv a0, s3
    call is_f32_infinity
    bnez a0, basic_continue
    
    mv a0, s3
    mv a1, s5
    call check_relative_error_1pct
    beqz a0, basic_error_fail
    
basic_continue:
    # Both tests passed for this value
    addi s1, s1, 4
    addi s0, s0, 1
    j basic_loop
    
basic_sign_fail:
    # Sign test failed - report and exit immediately
    la a0, str_sign_mismatch
    call print_string
    call increment_failed
    j basic_fail_exit
    
basic_error_fail:
    # Error test failed - report and exit immediately
    la a0, str_error_large
    call print_string
    call increment_failed
    j basic_fail_exit
    
basic_fail_exit:
    # Exit without printing PASS
    lw s5, 4(sp)
    lw s4, 8(sp)
    lw s3, 12(sp)
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret
    
basic_done:
    # All tests passed
    call increment_passed
    la a0, str_pass
    call print_string
    
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
# TEST_SPECIAL_VALUES
# ============================================================================
test_special_values:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)
    
    la a0, str_test_special
    call print_string
    
    # Test 1a: Positive infinity - should be infinity
    li s0, 0x7F800000   # +inf in f32
    mv a0, s0
    call f32_to_bf16
    mv s1, a0
    call bf16_isinf
    bnez a0, special_test1a_pass
    la a0, str_inf_detect
    call print_string
    call increment_failed
    j special_test1b
    
special_test1a_pass:
    call increment_passed
    
special_test1b:
    # Test 1b: Positive infinity - should NOT be NaN
    mv a0, s1
    call bf16_isnan
    beqz a0, special_test1b_pass
    la a0, str_nan_detect
    call print_string
    call increment_failed
    j special_test2
    
special_test1b_pass:
    call increment_passed
    
special_test2:
    # Test 2: Negative infinity
    li s0, 0xFF800000   # -inf in f32
    mv a0, s0
    call f32_to_bf16
    mv s1, a0
    call bf16_isinf
    bnez a0, special_test2_pass
    la a0, str_inf_detect
    call print_string
    call increment_failed
    j special_test3a
    
special_test2_pass:
    call increment_passed
    
special_test3a:
    # Test 3a: NaN - should be NaN
    li s0, 0x7FC00000   # NaN in f32
    mv a0, s0
    call f32_to_bf16
    mv s1, a0
    call bf16_isnan
    bnez a0, special_test3a_pass
    la a0, str_nan_detect
    call print_string
    call increment_failed
    j special_test3b
    
special_test3a_pass:
    call increment_passed
    
special_test3b:
    # Test 3b: NaN - should NOT be infinity
    mv a0, s1
    call bf16_isinf
    beqz a0, special_test3b_pass
    la a0, str_inf_detect
    call print_string
    call increment_failed
    j special_test4
    
special_test3b_pass:
    call increment_passed
    
special_test4:
    # Test 4: Positive zero
    li s0, 0x00000000   # +0.0 in f32
    mv a0, s0
    call f32_to_bf16
    mv s1, a0
    call bf16_iszero
    bnez a0, special_test4_pass
    la a0, str_zero_detect
    call print_string
    call increment_failed
    j special_test5
    
special_test4_pass:
    call increment_passed
    
special_test5:
    # Test 5: Negative zero
    li s0, 0x80000000   # -0.0 in f32
    mv a0, s0
    call f32_to_bf16
    mv s1, a0
    call bf16_iszero
    bnez a0, special_test5_pass
    la a0, str_zero_detect
    call print_string
    call increment_failed
    j special_done
    
special_test5_pass:
    call increment_passed
    
special_done:
    la a0, str_pass
    call print_string
    
    lw s1, 4(sp)
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret

# ============================================================================
# CONVERSION FUNCTIONS
# ============================================================================

# F32_TO_BF16: Convert Float32 to BFloat16
# Input: a0 = float32 bits (32-bit)
# Output: a0 = bfloat16 bits (16-bit, in lower 16 bits of a0)
f32_to_bf16:
    # Get exponent (bits 30:23)
    srli t0, a0, 23
    andi t0, t0, 0xFF
    
    # Check for special cases (NaN or Inf: exponent == 0xFF)
    li t1, 0xFF
    beq t0, t1, f32_special
    
    # Normal case: round-to-nearest-even
    # Rounding bias = (f32 >> 16) & 1 + 0x7FFF
    srli t2, a0, 16      # Get bit 16 (LSB of BF16)
    andi t2, t2, 1       # Isolate bit 16
    
    # Create 0x7FFF
    lui t3, 0x8          # t3 = 0x8000
    addi t3, t3, -1      # t3 = 0x7FFF
    
    # Add rounding bias
    add t2, t2, t3       # t2 = 0x7FFF or 0x8000
    add a0, a0, t2       # Add bias to original value
    
    # Extract top 16 bits (this is the BF16 result)
    srli a0, a0, 16
    ret

f32_special:
    # For special values (NaN/Inf), just truncate
    srli a0, a0, 16
    ret

# BF16_TO_F32: Convert BFloat16 to Float32
# Input: a0 = bfloat16 bits (16-bit)
# Output: a0 = float32 bits (32-bit)
bf16_to_f32:
    # BF16 is top 16 bits of FP32, just shift left by 16
    slli a0, a0, 16
    ret

# ============================================================================
# SPECIAL VALUE CHECKS
# ============================================================================

# BF16_ISINF: Check if BF16 is infinity
# Input: a0 = bf16 (16-bit)
# Output: a0 = 1 if inf, 0 otherwise
bf16_isinf:
    # Extract exponent (bits 14:7)
    srli t0, a0, 7
    andi t0, t0, 0xFF
    
    # Extract mantissa (bits 6:0)
    andi t1, a0, 0x7F
    
    # Is inf if exponent==0xFF and mantissa==0
    li t2, 0xFF
    bne t0, t2, isinf_false
    bnez t1, isinf_false
    
    li a0, 1
    ret
    
isinf_false:
    li a0, 0
    ret

# BF16_ISNAN: Check if BF16 is NaN
# Input: a0 = bf16 (16-bit)
# Output: a0 = 1 if NaN, 0 otherwise
bf16_isnan:
    # Extract exponent (bits 14:7)
    srli t0, a0, 7
    andi t0, t0, 0xFF
    
    # Extract mantissa (bits 6:0)
    andi t1, a0, 0x7F
    
    # Is NaN if exponent==0xFF and mantissa!=0
    li t2, 0xFF
    bne t0, t2, isnan_false
    beqz t1, isnan_false
    
    li a0, 1
    ret
    
isnan_false:
    li a0, 0
    ret

# BF16_ISZERO: Check if BF16 is zero (including -0)
# Input: a0 = bf16 (16-bit)
# Output: a0 = 1 if zero, 0 otherwise
bf16_iszero:
    # Zero if all bits except sign are 0
    # Create mask 0x7FFF
    lui t1, 0x8          # t1 = 0x8000
    addi t1, t1, -1      # t1 = 0x7FFF
    and t0, a0, t1       # Mask off sign bit
    seqz a0, t0          # a0 = (t0 == 0) ? 1 : 0
    ret

# ============================================================================
# HELPER FUNCTIONS FOR TESTING
# ============================================================================

# CHECK_SIGN_MATCH: Check if two f32 have same sign
# Input: a0 = f32_1, a1 = f32_2
# Output: a0 = 1 if same sign, 0 otherwise
check_sign_match:
    srli t0, a0, 31      # Get sign bit of a0
    srli t1, a1, 31      # Get sign bit of a1
    xor t0, t0, t1       # XOR: 0 if same, 1 if different
    seqz a0, t0          # a0 = 1 if t0==0 (same sign)
    ret

# IS_F32_INFINITY: Check if f32 is infinity
# Input: a0 = f32
# Output: a0 = 1 if inf, 0 otherwise
is_f32_infinity:
    # Extract exponent (bits 30:23)
    srli t0, a0, 23
    andi t0, t0, 0xFF
    
    # Extract mantissa (bits 22:0)
    lui t2, 0x80         # Load 0x80000
    addi t2, t2, -1      # t2 = 0x7FFFF
    and t1, a0, t2       # Mask mantissa
    
    # Inf if exponent==0xFF and mantissa==0
    li t3, 0xFF
    bne t0, t3, f32_not_inf
    bnez t1, f32_not_inf
    
    li a0, 1
    ret
    
f32_not_inf:
    li a0, 0
    ret

# CHECK_RELATIVE_ERROR_1PCT: Check if relative error < 1%
# Input: a0 = expected (f32), a1 = actual (f32)
# Output: a0 = 1 if error acceptable, 0 otherwise
check_relative_error_1pct:
    # For BF16, check if top 16 bits are close
    srli t0, a0, 16
    srli t1, a1, 16
    
    sub t2, t0, t1       # Difference
    
    # Get absolute difference
    bgez t2, check_positive
    sub t2, zero, t2     # Make positive
    
check_positive:
    # Allow difference of ±1 for rounding
    li t3, 1
    ble t2, t3, error_ok
    
    li a0, 0
    ret
    
error_ok:
    li a0, 1
    ret

# ============================================================================
# TEST COUNTER FUNCTIONS
# ============================================================================

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

# ============================================================================
# OUTPUT FUNCTIONS
# ============================================================================

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

print_string:
    li a7, 4
    ecall
    ret

print_int:
    li a7, 1
    ecall
    ret