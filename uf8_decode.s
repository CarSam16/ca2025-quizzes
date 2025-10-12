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
