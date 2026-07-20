/*
 * RV32I full-SoC timer test
 *
 * Verifies:
 *   - disabled timer count remains stable
 *   - COUNT register write/read behavior
 *   - CTRL.CLEAR clears COUNT and STATUS.MATCH
 *   - enabled timer count advances
 *   - COMPARE produces STATUS.MATCH
 *   - STATUS.MATCH supports write-one-to-clear
 *   - IRQ enable can be armed for the final pass condition
 *
 * PASS:
 *   GPIO direction[3:0] = 0xF
 *   GPIO output[3:0]    = 0x5
 *   Timer IRQ is left asserted
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
    .equ TIMER_COUNT,         0x04
    .equ TIMER_COMPARE,       0x08
    .equ TIMER_STATUS,        0x0C

    .equ TIMER_CTRL_ENABLE,   0x01
    .equ TIMER_CTRL_CLEAR,    0x02
    .equ TIMER_CTRL_IRQ_EN,   0x04
    .equ TIMER_ENABLE_IRQ,    0x05

    .equ STATUS_MATCH,        0x01
    .equ PASS_SIGNATURE,      0x05
    .equ FAIL_SIGNATURE,      0x0E
    .equ POLL_LIMIT,          1000

    .section .text.start
    .align 2
    .globl _start
    .type _start, @function

_start:
    li      t0, TIMER_BASE

    /* --------------------------------------------------------
     * Clear and disable the timer.
     * -------------------------------------------------------- */
    li      t1, TIMER_CTRL_CLEAR
    sw      t1, TIMER_CTRL(t0)

    lw      t2, TIMER_COUNT(t0)
    bne     t2, zero, test_fail

    lw      t2, TIMER_STATUS(t0)
    andi    t2, t2, STATUS_MATCH
    bne     t2, zero, test_fail

    /* --------------------------------------------------------
     * The count must remain stable while disabled.
     * -------------------------------------------------------- */
    lw      t2, TIMER_COUNT(t0)

    li      t3, 16
disabled_delay:
    addi    t3, t3, -1
    bne     t3, zero, disabled_delay

    lw      t4, TIMER_COUNT(t0)
    bne     t2, t4, test_fail

    /* --------------------------------------------------------
     * Verify COUNT write/read behavior while disabled.
     * -------------------------------------------------------- */
    li      t1, 3
    sw      t1, TIMER_COUNT(t0)

    lw      t2, TIMER_COUNT(t0)
    bne     t2, t1, test_fail

    /* CLEAR must restore COUNT and MATCH to zero. */
    li      t1, TIMER_CTRL_CLEAR
    sw      t1, TIMER_CTRL(t0)

    lw      t2, TIMER_COUNT(t0)
    bne     t2, zero, test_fail

    lw      t2, TIMER_STATUS(t0)
    andi    t2, t2, STATUS_MATCH
    bne     t2, zero, test_fail

    /* --------------------------------------------------------
     * Enable counting without IRQ and verify count advances.
     * -------------------------------------------------------- */
    li      t1, 40
    sw      t1, TIMER_COMPARE(t0)

    li      t1, TIMER_CTRL_ENABLE
    sw      t1, TIMER_CTRL(t0)

    li      t3, POLL_LIMIT
wait_for_count:
    lw      t2, TIMER_COUNT(t0)
    bne     t2, zero, count_advanced

    addi    t3, t3, -1
    bne     t3, zero, wait_for_count
    j       test_fail

count_advanced:
    /* --------------------------------------------------------
     * Wait for the compare match.
     * -------------------------------------------------------- */
    li      t3, POLL_LIMIT
wait_for_match:
    lw      t2, TIMER_STATUS(t0)
    andi    t2, t2, STATUS_MATCH
    bne     t2, zero, match_seen

    addi    t3, t3, -1
    bne     t3, zero, wait_for_match
    j       test_fail

match_seen:
    /* --------------------------------------------------------
     * Verify STATUS.MATCH write-one-to-clear.
     *
     * Disable first so the match cannot be regenerated while
     * the status-clear behavior is checked.
     * -------------------------------------------------------- */
    sw      zero, TIMER_CTRL(t0)

    li      t1, STATUS_MATCH
    sw      t1, TIMER_STATUS(t0)

    lw      t2, TIMER_STATUS(t0)
    andi    t2, t2, STATUS_MATCH
    bne     t2, zero, test_fail

    /* CLEAR must also clear the count after the completed run. */
    li      t1, TIMER_CTRL_CLEAR
    sw      t1, TIMER_CTRL(t0)

    lw      t2, TIMER_COUNT(t0)
    bne     t2, zero, test_fail

    /* --------------------------------------------------------
     * Final pass run: leave MATCH and IRQ asserted for cocotb.
     * -------------------------------------------------------- */
    li      t1, 10
    sw      t1, TIMER_COMPARE(t0)

    li      t1, TIMER_ENABLE_IRQ
    sw      t1, TIMER_CTRL(t0)

    li      t3, POLL_LIMIT
final_match_poll:
    lw      t2, TIMER_STATUS(t0)
    andi    t2, t2, STATUS_MATCH
    bne     t2, zero, test_pass

    addi    t3, t3, -1
    bne     t3, zero, final_match_poll
    j       test_fail

test_pass:
    li      t0, GPIO_BASE

    li      t1, 0xF
    sw      t1, GPIO_DATA_DIR(t0)

    li      t1, PASS_SIGNATURE
    sw      t1, GPIO_DATA_OUT(t0)

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
