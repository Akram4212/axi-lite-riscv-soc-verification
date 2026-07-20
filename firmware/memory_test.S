/*
 * RV32I full-SoC memory test
 *
 * Verifies word, byte, and halfword memory accesses.
 *
 * PASS:
 *   GPIO direction[3:0] = 0xF
 *   GPIO output[3:0]    = 0x5
 *   Timer IRQ is raised
 *   EBREAK halts the core
 *
 * FAIL:
 *   GPIO direction[3:0] = 0xF
 *   GPIO output[3:0]    = 0xE
 *   EBREAK halts the core
 */

    .option norvc

    .equ TEST_RAM_BASE,       0x00000200

    .equ GPIO_BASE,           0x10000000
    .equ GPIO_DATA_OUT,       0x00
    .equ GPIO_DATA_DIR,       0x08

    .equ TIMER_BASE,          0x10001000
    .equ TIMER_CTRL,          0x00
    .equ TIMER_COMPARE,       0x08
    .equ TIMER_STATUS,        0x0C

    .equ TIMER_ENABLE_IRQ,    0x05
    .equ PASS_SIGNATURE,      0x05
    .equ FAIL_SIGNATURE,      0x0E

    .section .text.start
    .align 2
    .globl _start
    .type _start, @function

_start:
    li      t0, TEST_RAM_BASE

    /* Full-word store/load checks. */
    li      t1, 0x12345678
    sw      t1, 0(t0)

    li      t1, 0xA5A55A5A
    sw      t1, 4(t0)

    li      t1, -1
    sw      t1, 8(t0)

    sw      zero, 12(t0)

    lw      t2, 0(t0)
    li      t3, 0x12345678
    bne     t2, t3, test_fail

    lw      t2, 4(t0)
    li      t3, 0xA5A55A5A
    bne     t2, t3, test_fail

    lw      t2, 8(t0)
    li      t3, -1
    bne     t2, t3, test_fail

    lw      t2, 12(t0)
    bne     t2, zero, test_fail

    /* Byte and halfword write-strobe checks. */
    li      t1, 0x11223344
    sw      t1, 16(t0)

    li      t1, 0xAA
    sb      t1, 17(t0)

    lw      t2, 16(t0)
    li      t3, 0x1122AA44
    bne     t2, t3, test_fail

    li      t1, 0xBEEF
    sh      t1, 18(t0)

    lw      t2, 16(t0)
    li      t3, 0xBEEFAA44
    bne     t2, t3, test_fail

    /* Signed and unsigned load checks. */
    li      t1, 0x80
    sb      t1, 16(t0)

    lb      t2, 16(t0)
    li      t3, -128
    bne     t2, t3, test_fail

    lbu     t2, 16(t0)
    li      t3, 0x80
    bne     t2, t3, test_fail

    lh      t2, 18(t0)
    li      t3, 0xFFFFBEEF
    bne     t2, t3, test_fail

    lhu     t2, 18(t0)
    li      t3, 0x0000BEEF
    bne     t2, t3, test_fail

test_pass:
    li      t0, GPIO_BASE
    li      t1, 0xF
    sw      t1, GPIO_DATA_DIR(t0)

    li      t1, PASS_SIGNATURE
    sw      t1, GPIO_DATA_OUT(t0)

    li      t0, TIMER_BASE
    li      t1, 10
    sw      t1, TIMER_COMPARE(t0)

    li      t1, TIMER_ENABLE_IRQ
    sw      t1, TIMER_CTRL(t0)

poll_timer:
    lw      t2, TIMER_STATUS(t0)
    andi    t2, t2, 1
    beq     t2, zero, poll_timer

    ebreak

test_fail:
    li      t0, GPIO_BASE
    li      t1, 0xF
    sw      t1, GPIO_DATA_DIR(t0)

    li      t1, FAIL_SIGNATURE
    sw      t1, GPIO_DATA_OUT(t0)

    ebreak

halt_loop:
    jal     zero, halt_loop

    .size _start, . - _start
