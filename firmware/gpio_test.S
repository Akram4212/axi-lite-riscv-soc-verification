/*
 * RV32I full-SoC GPIO test
 *
 * Verifies:
 *   - GPIO direction register writes
 *   - GPIO output register writes
 *   - GPIO output SET register
 *   - GPIO output CLEAR register
 *   - Readback of DATA_OUT and DATA_DIR
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

    .equ GPIO_BASE,           0x10000000
    .equ GPIO_DATA_OUT,       0x00
    .equ GPIO_DATA_IN,        0x04
    .equ GPIO_DATA_DIR,       0x08
    .equ GPIO_DATA_OUT_SET,   0x0C
    .equ GPIO_DATA_OUT_CLR,   0x10

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
    li      t0, GPIO_BASE

    /* Configure the low nibble as outputs. */
    li      t1, 0xF
    sw      t1, GPIO_DATA_DIR(t0)

    lw      t2, GPIO_DATA_DIR(t0)
    bne     t2, t1, test_fail

    /* Direct write: 0x3. */
    li      t1, 0x3
    sw      t1, GPIO_DATA_OUT(t0)

    lw      t2, GPIO_DATA_OUT(t0)
    bne     t2, t1, test_fail

    /* SET bit 2: 0x3 -> 0x7. */
    li      t1, 0x4
    sw      t1, GPIO_DATA_OUT_SET(t0)

    lw      t2, GPIO_DATA_OUT(t0)
    li      t3, 0x7
    bne     t2, t3, test_fail

    /* CLEAR bit 1: 0x7 -> 0x5. */
    li      t1, 0x2
    sw      t1, GPIO_DATA_OUT_CLR(t0)

    lw      t2, GPIO_DATA_OUT(t0)
    li      t3, PASS_SIGNATURE
    bne     t2, t3, test_fail

    /* Zero writes to SET/CLR must leave DATA_OUT unchanged. */
    li      t1, 0
    sw      t1, GPIO_DATA_OUT_SET(t0)
    sw      t1, GPIO_DATA_OUT_CLR(t0)

    lw      t2, GPIO_DATA_OUT(t0)
    li      t3, PASS_SIGNATURE
    bne     t2, t3, test_fail

test_pass:
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
