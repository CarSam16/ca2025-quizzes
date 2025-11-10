    .data
    msg1:   .asciz ": produces value "
    msg2:   .asciz " but encodes back to "
    msg3:   .asciz ": value "
    msg4:   .asciz " <= previous_value "
    msg5:   .asciz "All tests passed.\n"
    msg6:   .asciz "Some tests failed.\n"
    newline:   .asciz "\n"
    .align 2
    .text
    .globl main
main:
    jal ra, test # start to test
    beq a0, x0, Not_pass # fail
    la a0, msg5 # print msg5 when passing
    li a7, 4
    ecall
    li a7, 93         # ecall: exit
    li a0, 0 # exit code is 0, successful
    ecall
Not_pass:
    la a0, msg6 # print msg6 when not passing
    li a7, 4
    ecall
    li a7, 93         # ecall: exit
    li a0, 1 # exit code is 1, not successful
    ecall
test:
    addi sp, sp, -4
    sw ra, 0(sp) # because test need to call other function
    addi s0, x0, -1 # previous_value
    li s1, 1 # passed, 1 means true, 0 means false
    li s2, 0 # f1, counter from 0 to 255
    li s3, 256 # counter's end
For_2:
    add a0, s2, x0 # prepare a0 for uf8_decode
    jal ra, uf8_decode
    add s4, a0, x0 # value (return value from uf8_decode)
    add a0, s4, x0 # prepare a0 for uf8_encode
    jal ra, uf8_encode
    add s5, a0, x0 # fl2 (return value from uf8_encode)
test_if_1:
    beq s2, s5, test_if_2
    mv a0, s2       # print s2(f1)
    li a7, 34        # (RARS) print integer in hex
    ecall
    la a0, msg1 # print msg1
    li a7, 4
    ecall
    mv a0, s4 # print value 
    li a7, 1
    ecall
    la a0, msg2 # print msg2
    li a7, 4
    ecall
    mv a0, s5       # prepare to print fl2(s5)'s hexdecimal
    li a7, 34        # (RARS) print integer in hex
    ecall
    la a0, newline # print newline
    li a7, 4
    ecall
    li s1, 0 # passed = false
test_if_2:
    blt s0, s4, after_if
    mv a0, s2       # print s2(f1)
    li a7, 34        # (RARS) print integer in hex
    ecall
    la a0, msg3 # print msg1
    li a7, 4
    ecall
    mv a0, s4 # print value 
    li a7, 1
    ecall
    la a0, msg4 # print msg2
    li a7, 4
    ecall
    mv a0, s0       # prepare to print s0(previous_value)'s hexdecimal
    li a7, 34        # (RARS) print integer in hex
    ecall
    la a0, newline # print newline
    li a7, 4
    ecall
    li s1, 0 # passed = false
after_if:
    mv s0, s4
    addi s2, s2, 1
    blt s2, s3, For_2
    mv a0, s1 # return passed
    lw ra, 0(sp)
    addi sp, sp, 4
    jr ra   # jump to ra

# Function: clz
# Arguments:
#   a0 = x (input)
# Return:
#   a0 = n - x
# Temporaries:
#   t0 = n
#   t1 = c
#   t2 = y

CLZ_myfunction:
     li t0, 32  # n
     li t1, 16  # c
do_while:
     srl t2, a0, t1  #  y = x >> c
     bnez t2, if_loop  # if (y != 0) -> go to if_loop
     srli t1, t1, 1  # c >>= 1
     beqz t1, end_loop   # if (c == 0) break
     j do_while  # continue loop
if_loop:
     sub t0, t0, t1  # n -= c
     add a0, t2, x0  # x = y
     srli t1, t1, 1  # c >>= 1
     beqz t1, end_loop  # if (c == 0) break
     j do_while  # loop again
end_loop:
     sub a0, t0, a0
     jr ra
 
 ################### uf8 decode #######################
 # input uf8 value : a0
 # output uint32 value : a0
 
 uf8_decode:
      andi t1, a0, 0x0f  # mantissa = fl & 0x0f
      srli t2, a0, 4  # exponent = fl >> 4
      li t3, 15
      sub t3, t3, t2  # t3 = (15 - exponent)
      li t4, 0x7FFF
      srl t3, t4, t3  # t3 = (0x7FFF >> (15 - exponent))
      slli t3, t3, 4  # t3 = (0x7FFF >> (15 - exponent)) << 4;
      sll t1, t1, t2  # t1 = offset = (mantissa << exponent)
      add a0, t1, t3  # (mantissa << exponent) + offset
      jr ra
 
 ################# uf8 encode #########################
 # input uint32 : a0
 # output uf8 : a0
 
 uf8_encode:
      # callee save 
      addi sp, sp, -8
      sw ra, 0(sp)  #  used to call CLZ function
      sw s0, 4(sp)
      add s0, a0, x0  # s0 keep original value
      #  /* Use CLZ for fast exponent calculation */
      li t0, 16
      blt s0, t0, end_encode
      
      jal ra, CLZ_myfunction  # call CLZ
      li t0, 31
      sub t0, t0, a0  # msb = 31 - lz, lz is in a0
      li a1, 0  # exp
      li a2, 0  # overflow
      
      li t1, 5
      blt t0, t1, find_exact_exp
      li t1, 4
      sub a1, t0, t1
      li t1, 15
      blt a1, t1, cal_overflow
      li a1, 15

 cal_overflow:
      li t1, 0
      cal_overflow_loop:
      bge t1, a1, adjust_loop
      slli a2, a2, 1
      addi a2, a2, 16  # # overflow = (overflow << 1) + 16
      addi t1, t1, 1  # counter ++
      j cal_overflow_loop
      
 adjust_loop:
     bltz a1, find_exact_exp
     bge s0, a2, find_exact_exp
     addi t2, a2, -16
     srli a2, t2, 1
     addi a1, a1, -1
     j adjust_loop
     

find_exact_exp:
     li t1, 15
     bge a1, t1, end_encode
     slli t2, a2, 1
     addi t2, t2, 16
     blt s0, t2, end_encode
     add a2, t2, x0
     addi a1, a1, 1
     j find_exact_exp
      
end_encode:
      sub t2, s0, a2
      srl t2, t2, a1
      slli a1, a1, 4
      or a0, a1, t2
      
return:
     lw s0, 4(sp)
     lw ra, 0(sp)
     addi sp, sp, 8
     jr ra
 
