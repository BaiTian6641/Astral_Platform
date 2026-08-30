/* SPDX-License-Identifier: MIT */
/*
 * main.c — bmc-fw v0 skeleton: boot + lifecycle state-machine idle spin.
 *
 * E1-BMC2 checkpoint (ethereal-plan/subsystems/S05 §3 Phase-1 #2):
 * "UART 启动; 状态机空转; FW 自更新演示" — UART boot + lifecycle FSM skeleton.
 *
 * The v0 skeleton boots, drives UART0, prints a banner, runs the region
 * lifecycle state machine through a no-op IDLE->CONFIGURED->RUNNING->IDLE
 * cycle against the (still-empty) region table, prints a heartbeat, and parks.
 * Real deploy (verify->allocate->OCC) lands with E1-RUN2 on this skeleton.
 *
 * G1: no dynamic memory (static state only). Bare-metal rv32imc.
 *
 * Plan-Ref: ethereal-plan/subsystems/S05-BMC与EMRI-mFSM.md §2.2 (lifecycle),
 *           ethereal-plan/components/C05-BMC组件.md §4.2 (lifecycle FSM).
 */
#include "drivers/uart.h"

/* Region lifecycle states (C05 §4.2). v0: no hardware side-effects. */
typedef enum {
    REGION_EMPTY = 0,   /* no image loaded */
    REGION_LOADED,      /* image verified + written to OCC, not started */
    REGION_RUNNING,     /* image running */
} region_state_e;

/* Region descriptor (static table; regions are build-time, ADR-004). */
typedef struct {
    region_state_e state;
    uint32_t       image_id;    /* v0: placeholder (0 = none) */
} region_t;

#define MAX_REGIONS 2           /* v0 fixed (ADR-004 build-time) */
static region_t g_regions[MAX_REGIONS];

/* lifecycle transitions (v0 skeleton: pure state machine, no HW yet) */
static void region_load(region_t *r, uint32_t image_id)
{
    if (r->state == REGION_EMPTY) {
        r->image_id = image_id;
        r->state    = REGION_LOADED;
    }
}
static void region_start(region_t *r)
{
    if (r->state == REGION_LOADED) {
        r->state = REGION_RUNNING;
    }
}
static void region_stop(region_t *r)
{
    if (r->state == REGION_RUNNING) {
        r->state    = REGION_EMPTY;
        r->image_id = 0;
    }
}

int main(void)
{
    uart_init();
    uart_puts("bmc-fw v0 skeleton boot OK\n");
    uart_puts("EMRI MAGIC=0x45544852 lifecycle: ");

    /* Skeleton lifecycle spin: drive region 0 through one full cycle. */
    region_load(&g_regions[0], /*image_id=*/1u);
    uart_puts("L");                       /* LOADED */
    region_start(&g_regions[0]);
    uart_puts("R");                       /* RUNNING */
    region_stop(&g_regions[0]);
    uart_puts("S");                       /* stopped -> EMPTY */

    uart_puts(" done state=");
    uart_puthex32((uint32_t)g_regions[0].state);   /* expect REGION_EMPTY=0 */
    uart_puts("\n");
    uart_puts("bmc-fw v0 idle spin\n");
    return 0;   /* crt0 parks in wfi loop */
}
