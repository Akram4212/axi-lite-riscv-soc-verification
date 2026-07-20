/*
 * RV32I AXI-Lite SoC firmware smoke test
 *
 * Memory map:
 *   RAM          0x0000_0000 - 0x0000_0FFF
 *   GPIO         0x1000_0000 - 0x1000_0FFF
 *   Timer        0x1000_1000 - 0x1000_1FFF
 *
 * Expected result:
 *   GPIO direction[3:0] = 0xF
 *   GPIO output[3:0]    = 0x5
 *   Timer compare       = 10
 *   Timer IRQ/status    = asserted
 *   Core executes EBREAK
 */

    .option norvc

    .equ GPIO_BASE,          0x10000000
    .equ GPIO_DATA_OUT,     0x00
    .equ GPIO_DATA_DIR,     0x08

    .equ TIMER_BASE,         0x10001000
    .equ TIMER_CTRL,        0x00
    .equ TIMER_COMPARE,     0x08
    .equ TIMER_STATUS,      0x0C

    .equ TIMER_CTRL_ENABLE,  0x01
    .equ TIMER_CTRL_IRQ_EN,  0x04

    .section .text.start
    .align 2
    .globl _start
    .type _start, @function

_start:
    /* Configure GPIO[3:0] as outputs. */
    lui     t0, %hi(GPIO_BASE)
    addi    t0, t0, %lo(GPIO_BASE)

    addi    t1, zero, 15
    sw      t1, GPIO_DATA_DIR(t0)

    /* Drive GPIO[3:0] with 0x5. */
    addi    t2, zero, 5
    sw      t2, GPIO_DATA_OUT(t0)

    /* Configure timer compare value. */
    lui     t3, %hi(TIMER_BASE)
    addi    t3, t3, %lo(TIMER_BASE)

    addi    t4, zero, 10
    sw      t4, TIMER_COMPARE(t3)

    /* Enable timer and timer interrupt generation. */
    addi    t5, zero, TIMER_CTRL_ENABLE | TIMER_CTRL_IRQ_EN
    sw      t5, TIMER_CTRL(t3)

poll_timer:
    lw      t6, TIMER_STATUS(t3)
    andi    t6, t6, 1
    beq     t6, zero, poll_timer

    /* The current core treats EBREAK as a halt condition. */
    ebreak

halt_loop:
    jal     zero, halt_loop

    .size _start, . - _start
