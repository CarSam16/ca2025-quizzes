# ============================================================================
# UF8 Encoding/Decoding Implementation for RISC-V (RV32I)
# ============================================================================

.data
test_passed:        .word 1

str_passed:         .string "All tests passed!\n"
str_failed:         .string "Tests FAILED!\n"
str_error_prefix:   .string "Error at byte: "

.text
.globl main

# ============================================================================
# MAIN ENTRY
# ============================================================================
main:
    addi sp, sp, -16
    sw ra, 12(sp)
    
    call validate_roundtrip
    
    beqz a0, test_fail
    
    # Success path
    la a0, str_passed
    li a7, 4
    ecall
    li a0, 0
    j exit_program
    
test_fail:
    la a0, str_failed
    li a7, 4
    ecall
    li a0, 1
    
exit_program:
    lw ra, 12(sp)
    addi sp, sp, 16
    li a7, 10
    ecall

# ============================================================================
# VALIDATE_ROUNDTRIP: Test encoding and decoding for all 256 values
# ============================================================================
validate_roundtrip:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)           # s0 = iteration counter
    sw s1, 20(sp)           # s1 = current byte value
    sw s2, 16(sp)           # s2 = decoded result
    sw s3, 12(sp)           # s3 = re-encoded byte
    sw s4, 8(sp)            # s4 = last decoded value
    sw s5, 4(sp)            # s5 = pass/fail status
    
    li s0, 0                # Start from 0
    li s4, -1               # Initialize last value
    li s5, 1                # Assume success
    
validation_loop:
    li t0, 256
    bge s0, t0, validation_complete
    
    mv s1, s0
    
    # Decode current byte
    mv a0, s1
    call decode_uf8
    mv s2, a0
    
    # Re-encode the decoded value
    mv a0, s2
    call encode_uf8
    mv s3, a0
    
    # Verify roundtrip integrity
    bne s1, s3, roundtrip_fail
    
    # Verify monotonic property
    ble s2, s4, monotonic_fail
    
    mv s4, s2
    addi s0, s0, 1
    j validation_loop

roundtrip_fail:
    li s5, 0
    
    la a0, str_error_prefix
    li a7, 4
    ecall
    
    mv a0, s1
    li a7, 1
    ecall
    
    li a0, 10
    li a7, 11
    ecall
    
    mv s4, s2
    addi s0, s0, 1
    j validation_loop

monotonic_fail:
    li s5, 0
    
    la a0, str_error_prefix
    li a7, 4
    ecall
    
    mv a0, s0
    li a7, 1
    ecall
    
    li a0, 10
    li a7, 11
    ecall
    
    mv s4, s2
    addi s0, s0, 1
    j validation_loop

validation_complete:
    mv a0, s5
    
    lw s5, 4(sp)
    lw s4, 8(sp)
    lw s3, 12(sp)
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret


############################################
# COUNT_LEADING_ZEROS: Hardware-agnostic CLZ implementation
############################################
count_leading_zeros:
# Input: a0 = value to analyze
# Output: a0 = number of leading zero bits
# Uses binary search approach for efficiency
# t0 = n
# t1 = c
# t2 = x
# t3 = y
    
    addi    sp, sp, -4
    sw      ra, 0(sp)

    addi    t0, x0, 32
    addi    t1, x0, 16
    mv      t2, a0
clz_loop:
    srl     t3, t2, t1                      # y = x >> c
    beq     t3, x0, dont_found_one          # if (y==0), go to next half
    sub     t0, t0, t1                      # n = n - c
    mv      t2, t3                          # x = y
dont_found_one:
    srli    t1, t1, 1                       # c >> 1, search next half of x
    bne     t1, x0, clz_loop                # while c != 0, keep searching

    sub     a0, t0, t2                      # return (n - x)
    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret

############################################
# DECODE_UF8: Convert UF8 byte to integer
############################################
# Input: a0 = UF8 encoded byte
# Output: a0 = decoded integer value [0, 1015792]
# t0 = mantissa
# t1 = exponent
# t2 = offset
decode_uf8:
    addi    sp, sp, -4
    sw      ra, 0(sp)

    andi    t0, a0, 0x0F                    # (m)antissa = fl & 0x0f;
    srli    t1, a0, 4                       # (e)xponent = fl >> 4 = fl/16
    li      t2, 0x7FFF
    addi    t3, t1, -15                     # t3 = exponent -15
    sub     t3, x0, t3                      # t3 = 15 - exponent
    srl     t2, t2, t3                      # offset = 0x7FFF >> 15 - exponent
    slli    t2, t2, 4                       # offset = 0x7FFF * 2^(15-e) * 16

    sll     a0, t0, t1
    add     a0, a0, t2

    lw      ra, 0(sp)
    addi    sp, sp, 4
    ret

############################################
# ENCODE_UF8: Convert integer to UF8 byte
############################################
# Input: a0 = integer value [0, 1015792]
# Output: a0 = UF8 encoded byte
###
# s0 = value
# s1 = exponent
# s2 = overflow 
# s3 = mantissa
encode_uf8:
    # callee save
    addi    sp, sp, -20
    sw      ra, 0(sp)
    sw      s0, 4(sp)
    sw      s1, 8(sp)
    sw      s2, 12(sp)
    sw      s3, 16(sp)
# initailization
    mv      s0, a0                  # s0 = value
    add     s1, x0, x0              # s1 = exponent = 0
    add     s2, x0, x0              # s2 = overflow = 0
# value < 16, don't need to encode
    addi    t0, x0, 16
    blt     s0, t0, find_exact_exp  # return a0 = value
# find msb from clz
    # a0 = value
    jal     ra, count_leading_zeros # a0 = clz(value)
    addi    t0, x0, 31              # t0 = 31
    sub     t0, t0, a0              # t0 = msb = 31 - lz
    addi    t1, x0, 5               # t1 = 5
    blt     t0, t1, find_exact_exp  # msb < 5, don't need estimate
exp_estimate:
    # rule of thumb
    add     s1, x0, t0              # s1 exponent = msb
    addi    s1, s1, -4              # s1 exponent = msb - 4
    addi    t0, t0, 15              # t0 = 15
    bge     t0, s1, cal_overflow    # exponent <= 15, jump
    addi    s1, s1, 15
    # Calculate overflow for estimated exponent
    # t0 = e
    # s2 = overflow starts from 0
cal_overflow:
    add     t0, x0, x0              # e = 0
overflow_loop:
    bge     t0, s1, adjust_est      # e < exponent then keep looping, else adjust estimation
    slli    s2, s2, 1               # overflow << 1
    addi    s2, s2, 16
end_overflow_loop:
    addi    t0, t0, 1               # e++
    jal     x0, overflow_loop       # go back to for loop

adjust_est:
    bge     x0, s1, find_exact_exp  # exponent <= 0, end adjust
    bge     s0, s2, find_exact_exp  # value >= overflow, end adjust
    addi    s2, s2, -16
    srli    s2, s2, 1               # overflow = (overflow - 16) >> 1
    addi    s1, s1, -1              # exponent --
    jal     x0, adjust_est

find_exact_exp:
    # t0 = 15
    # t1 = next overflow
    addi    t0, x0, 15
    bge     s1, t0, encode_result   # while (exponent < 15), exp >= 15 jump
    slli    t1, s2, 1               #
    addi    t1, t1, 16              # next_overflow = (overflow << 1) + 16
    blt     s0, t1, encode_result   # if (value < next_overflow), break
    add     s2, x0, t1              # overflow = next_overflow
    addi    s1, s1, 1               # exponent ++
    jal     x0, find_exact_exp

encode_result:
    sub     s3, s0, s2              # mantissa = (value - overflow)
    srl     s3, s3, s1              # mantissa = (value - overflow) >> exponent
    slli    a0, s1, 4
    or      a0, a0, s3              # return (exponent << 4) | mantissa

end_encode:
# retrieve ra and callee save
    lw      s3, 16(sp)
    lw      s2, 12(sp)
    lw      s1, 8(sp)
    lw      s0, 4(sp)
    lw      ra, 0(sp)
    addi    sp, sp, 20
    ret
