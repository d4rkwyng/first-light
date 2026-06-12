/* Public interface for Mike Chambers' fake6502 (public domain).
 * The host must provide the memory bus: read6502/write6502. */
#ifndef FAKE6502_H
#define FAKE6502_H

#include <stdint.h>

/* CPU control */
extern void reset6502(void);
extern void step6502(void);
extern void exec6502(uint32_t tickcount);
extern void irq6502(void);
extern void nmi6502(void);
extern void hookexternal(void *funcptr);

/* CPU state (single global instance) */
extern uint16_t pc;
extern uint8_t sp, a, x, y, status;
extern uint32_t instructions;
extern uint32_t clockticks6502;

/* Swift 6 cannot touch C globals directly (strict concurrency); these
 * accessors keep the global behind a function call. */
static inline uint32_t fake6502_clockticks(void) { return clockticks6502; }
static inline uint16_t fake6502_pc(void) { return pc; }

/* Snapshot support: full register access for save/restore. */
static inline uint8_t fake6502_a(void) { return a; }
static inline uint8_t fake6502_x(void) { return x; }
static inline uint8_t fake6502_y(void) { return y; }
static inline uint8_t fake6502_sp(void) { return sp; }
static inline uint8_t fake6502_status(void) { return status; }
static inline void fake6502_restore(uint8_t a_, uint8_t x_, uint8_t y_,
                                    uint8_t sp_, uint8_t st_, uint16_t pc_) {
    a = a_; x = x_; y = y_; sp = sp_; status = st_; pc = pc_;
}

/* Host-provided memory bus */
extern uint8_t read6502(uint16_t address);
extern void write6502(uint16_t address, uint8_t value);

#endif
