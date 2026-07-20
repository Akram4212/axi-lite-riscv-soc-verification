/*
 * RV32I full-SoC branch and control-flow test
 *
 * Verifies:
 *   - BEQ and BNE, taken and not taken
 *   - BLT and BGE signed comparisons
 *   - BLTU and BGEU unsigned comparisons
 *   - backward branches through a counted loop
 *   - JAL subroutine call and JALR return
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
    /* --------------------------------------------------------
     * BEQ: taken and not taken
     * -------------------------------------------------------- */
    li      t0, 7
    li      t1, 7
    beq     t0, t1, beq_taken_ok
    j       test_fail

beq_taken_ok:
    li      t1, 8
    beq     t0, t1, test_fail

    /* --------------------------------------------------------
     * BNE: taken and not taken
     * -------------------------------------------------------- */
    bne     t0, t1, bne_taken_ok
    j       test_fail

bne_taken_ok:
    li      t1, 7
    bne     t0, t1, test_fail

    /* --------------------------------------------------------
     * Signed BLT/BGE
     * -------------------------------------------------------- */
    li      t0, -5
    li      t1, 3

    blt     t0, t1, blt_taken_ok
    j       test_fail

blt_taken_ok:
    bge     t0, t1, test_fail
    bge     t1, t0, bge_taken_ok
    j       test_fail

bge_taken_ok:
    blt     t1, t0, test_fail

    /* --------------------------------------------------------
     * Unsigned BLTU/BGEU
     *
     * 0xFFFF_FFFF is greater than 1 when interpreted unsigned.
     * -------------------------------------------------------- */
    li      t0, -1
    li      t1, 1

    bltu    t0, t1, test_fail
    bgeu    t0, t1, bgeu_taken_ok
    j       test_fail

bgeu_taken_ok:
    bltu    t1, t0, bltu_taken_ok
    j       test_fail

bltu_taken_ok:
    bgeu    t1, t0, test_fail

    /* --------------------------------------------------------
     * Backward branch loop.
     *
     * Sum 1 + 2 + ... + 10 and expect 55.
     * -------------------------------------------------------- */
    li      t0, 1
    li      t1, 11
    li      t2, 0

sum_loop:
    add     t2, t2, t0
    addi    t0, t0, 1
    blt     t0, t1, sum_loop

    li      t3, 55
    bne     t2, t3, test_fail

    /* --------------------------------------------------------
     * JAL call and JALR return.
     * -------------------------------------------------------- */
    li      a0, 21
    jal     ra, double_value

    li      t0, 42
    bne     a0, t0, test_fail

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

double_value:
    add     a0, a0, a0
    jalr    zero, 0(ra)

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
