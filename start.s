/* start.S — bare-metal startup code */
    .section .text.entry
    .globl _start

_start:
    la sp, _stack_top       # 設定堆疊指標

    # 清空 BSS
    la a0, _sbss
    la a1, _ebss
1:  bge a0, a1, 2f
    sw zero, 0(a0)
    addi a0, a0, 4
    j 1b
2:
    call main

hang:
    j hang                # 程式結束後無限迴圈
