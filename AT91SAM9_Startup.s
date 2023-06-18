/*****************************************************************************
 * Copyright (c) 2009 Rowley Associates Limited.                             *
 *                                                                           *
 * This file may be distributed under the terms of the License Agreement     *
 * provided with this software.                                              *
 *                                                                           *
 * THIS FILE IS PROVIDED AS IS WITH NO WARRANTY OF ANY KIND, INCLUDING THE   *
 * WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. *
 *****************************************************************************/

/*****************************************************************************
 *                           Preprocessor Definitions
 *                           ------------------------
 *
 * VECTORED_IRQ_INTERRUPTS
 *
 *   Enable vectored IRQ interrupts. If defined, the PC register will be loaded
 *   with the contents of the AIC_IVR register on an IRQ exception.
 *
 * STARTUP_FROM_RESET
 *
 *   If defined, the program will startup from power-on/reset. If not defined
 *   the program will just loop endlessly from power-on/reset.
 *
 *   This definition is not defined by default on this target because the
 *   debugger is unable to reset this target and maintain control of it over the
 *   JTAG interface. The advantage of doing this is that it allows the debugger
 *   to reset the CPU and run programs from a known reset CPU state on each run.
 *   It also acts as a safety net if you accidently download a program in FLASH
 *   that crashes and prevents the debugger from taking control over JTAG
 *   rendering the target unusable over JTAG. The obvious disadvantage of doing
 *   this is that your application will not startup without the debugger.
 *
 *   We advise that on this target you keep STARTUP_FROM_RESET undefined whilst
 *   you are developing and only define STARTUP_FROM_RESET when development is
 *   complete.
 *
 * NO_DBG_HANDLER
 *
 *   If defined, a debug handler is not used to service the dabort and pabort
 *   exceptions.
 *
 * NO_WATCHDOG_DISABLE
 *
 *   If defined, the watchdog will not be disabled.
 *
 * NO_USER_RESET
 *
 *   If defined, user reset will not be enabled.
 *
 * NO_PROTECTION_MODE
 *   
 *   If defined, AIC protection mode will not be enabled. AIC protection
 *   mode allows the AIC_IVR register to be accessed by the debugger (for
 *   example through the memory or register window). With protection mode
 *   disabled accesses of the AIC_IVR register by the debugger are likely
 *   to disrupt interrupt behaviour.
 *
 * NO_SRAM_VECTORS
 *
 *   If defined, exception vectors are not copied into internal SRAM. Exception
 *   vectors are copied to SRAM to enable modification and make use of the remap 
 *   capability of the chip.
 *
 * __FLASH_BUILD
 *
 *   If defined, the code is assumed to be executing from NOR flash and as such
 *   a bootloader will not have run. In this case the function init_sdram_pll 
 *   will be called with the stack pointer set to the top of internal SRAM.
 *
 * ITCM_SIZE, DTCM_SIZE
 *
 *   If defined, these will set up the sizes and addresses of the ITCM and DTCM
 *   respectively. Valid values are TCM_SIZE_16K, TCM_SIZE_32K, and TCM_SIZE_64K.
 *
 * NO_CACHE_ENABLE
 *
 *   If not defined, the I and D caches are enabled.
 *
 * NO_ICACHE_ENABLE
 *
 *   If not defined (and NO_CACHE_ENABLE not defined), the I cache is enabled.
 *
 *                           Linker Symbols
 *                           --------------
 *
 * __SRAM_segment_start__, __SRAM_segment_end__
 *
 * The start and end address of internal SRAM.
 *
 * __SDRAM_segment_start__, __SDRAM_segment_end__
 *
 * The start and end addresses of SDRAM
 *
 * __ITCM_segment_start__, __DTCM_segment_start__
 *
 * The start of the ITCM and DTCM segments
 *
 * __FLASH_segment_start__, __FLASH_segment_end
 *
 * The start and end addresses of external Flash
 *
 * __reserved_mmu_start__
 *
 * The start of the MMU Translation Table base
 *   
 *
 *****************************************************************************/

//#define NO_CACHE_ENABLE 1
//#define NO_ICACHE_ENABLE 1
//#define NO_USER_RESET 1
//#define NO_WATCHDOG_DISABLE 1
//#define VECTORED_IRQ_INTERRUPTS 1

#include <targets/AT91SAM9.h>

#define TCM_SIZE_16K 0x5
#define TCM_SIZE_32K 0x6
#define TCM_SIZE_64K 0x7
#if defined(ITCM_SIZE) && (ITCM_SIZE!=TCM_SIZE_16K) && (ITCM_SIZE!=TCM_SIZE_32K) && (ITCM_SIZE!=TCM_SIZE_64K)
#error invalid ITCM_SIZE
#endif
#if defined(DTCM_SIZE) && (DTCM_SIZE!=TCM_SIZE_16K) && (DTCM_SIZE!=TCM_SIZE_32K) && (DTCM_SIZE!=TCM_SIZE_64K)
#error invalid DTCM_SIZE
#endif
  
 // Exception Vectors
  .section .vectors, "ax"
  .code 32
  .align 0
  .global _vectors
  .global reset_handler
_vectors:
#ifdef STARTUP_FROM_RESET
  ldr pc, [pc, #reset_handler_address - . - 8]  /* reset */
#else
  b .                                           /* reset - infinite loop */
#endif
  ldr pc, [pc, #undef_handler_address - . - 8]
  ldr pc, [pc, #swi_handler_address - . - 8]
  ldr pc, [pc, #pabort_handler_address - . - 8]
  ldr pc, [pc, #dabort_handler_address - . - 8]
  nop
#ifdef VECTORED_IRQ_INTERRUPTS
  ldr pc, [pc, #-0xF20]                         /* irq */
#else
  ldr pc, [pc, #irq_handler_address - . - 8]    /* irq */
#endif
  ldr pc, [pc, #fiq_handler_address - . - 8]

reset_handler_address:
  .word reset_handler
undef_handler_address:
  .word undef_handler
swi_handler_address:
  .word swi_handler
#ifndef NO_DBG_HANDLER
pabort_handler_address:
  .word dbg_pabort_handler
dabort_handler_address:
  .word dbg_dabort_handler
#else
pabort_handler_address:
  .word pabort_handler
dabort_handler_address:
  .word dabort_handler
#endif
irq_handler_address:
  .word irq_handler
fiq_handler_address:
  .word fiq_handler

  .section .init, "ax"
  .code 32
  .align 0

/******************************************************************************
 *                                                                            *
 * Default exception handlers                                                 *
 *                                                                            *
 ******************************************************************************/
reset_handler:

#ifdef __FLASH_BUILD
  ldr sp, =__SRAM_segment_end__
  bl init_sdram_pll
#else
  // Something else has done the above
#endif
        
#ifdef ITCM_SIZE
  /* Setup the ITCM memory to be located at ITCM_START_ADDRESS */
  ldr r0, =__ITCM_segment_start__
  orr r0, r0, #(ITCM_SIZE<<2)|1
  mcr p15, 0, r0, c9, c1, 1
#endif

#ifdef DTCM_SIZE
  /* Setup the DTCM memory to be located at DTCM_START_ADDRESS */
  ldr r0, =__DTCM_segment_start__
  orr r0, r0, #(DTCM_SIZE<<2)|1
  mcr p15, 0, r0, c9, c1, 0
#endif

#if defined(ITCM_SIZE)||defined(DTCM_SIZE)
  ldr r0, =MATRIX_BASE+MATRIX_TCR_OFFSET
  ldr r1, =(DTCM_SIZE<<4)|(ITCM_SIZE)
  str r1, [r0]
#endif

#ifndef NO_SRAM_VECTORS
  /* Copy exception vectors into Internal SRAM */
  ldr r0, =__SRAM_segment_start__
  ldr r1, =_vectors
  ldmia r1!, {r2-r9}
  stmia r0!, {r2-r9}
  ldmia r1!, {r2-r8}
  stmia r0!, {r2-r8}
#endif

#ifndef NO_WATCHDOG_DISABLE
#if __TARGET_PROCESSOR==AT91RM9200 
#else
  /* Disable Watchdog */
  ldr r1, =WDT_BASE
  ldr r0, =WDT_MR_WDDIS
  str r0, [r1, #WDT_MR_OFFSET]
#endif
#endif
  
#ifndef NO_USER_RESET
#if __TARGET_PROCESSOR==AT91RM9200 
#else
  /* Enable user reset */
  ldr r1, =RSTC_BASE
  ldr r0, =0xA5000001
  str r0, [r1, #RSTC_MR_OFFSET]
#endif
#endif

#ifndef NO_PROTECTION_MODE
  /* Enable protect mode */
  ldr r1, =AIC_BASE
  ldr r0, =0x00000001
  str r0, [r1, #AIC_DCR_OFFSET]
#endif

#ifndef NO_CACHE_ENABLE
#if defined(__FLASH_BUILD) && (__TARGET_PROCESSOR==AT91SAM9XE512 || __TARGET_PROCESSOR==AT91SAM9XE256 || __TARGET_PROCESSOR==AT91SAM9XE128)
  /* Set the translation table base address */
  ldr r0, =mmu_translation_table
  mcr p15, 0, r0, c2, c0, 0          /* Write to TTB register */
  /* Setup the domain access control so accesses are not checked */
  ldr r0, =0xFFFFFFFF
  mcr p15, 0, r0, c3, c0, 0          /* Write to domain access control register */
  /* Enable the MMU and caches */
  mrc p15, 0, r0, c1, c0, 0          /* Read MMU control register */
  orr r0, r0, #0x00001000            /* Enable ICache */
  orr r0, r0, #0x00000007            /* Enable DCache, MMU and alignment fault */  
  mcr p15, 0, r0, c1, c0, 0          /* Write MMU control register */
  nop
  nop
#else
  /* Set the translation table base address */
  ldr r0, =__reserved_mmu_start__
  mcr p15, 0, r0, c2, c0, 0          /* Write to TTB register */

  /* Setup the domain access control so accesses are not checked */
  ldr r0, =0xFFFFFFFF
  mcr p15, 0, r0, c3, c0, 0          /* Write to domain access control register */

  /* Create translation table */
  ldr r0, =__reserved_mmu_start__
  bl libarm_mmu_flat_initialise_level_1_table

  /* Make SRAM cacheable */
  ldr r0, =__reserved_mmu_start__
  ldr r1, =__SRAM_segment_start__
  ldr r2, =__SRAM_segment_end__ 
  sub r2, r2, r1
  cmp r2, #0x00100000
  movle r2, #0x00100000
  ldr r4, =libarm_mmu_flat_set_level_1_cacheable_region
  mov lr, pc
  bx r4

#ifdef __FLASH_BUILD
  /* Make FLASH cacheable */
  ldr r0, =__reserved_mmu_start__
  ldr r1, =__FLASH_segment_start__
  ldr r2, =__FLASH_segment_end__ 
  sub r2, r2, r1
  cmp r2, #0x00100000
  movle r2, #0x00100000
  ldr r4, =libarm_mmu_flat_set_level_1_cacheable_region
  mov lr, pc
  bx r4
#endif

  /* Make the SDRAM cacheable */
  ldr r0, =__reserved_mmu_start__
  ldr r1, =__SDRAM_segment_start__ 
  ldr r2, =__SDRAM_segment_end__
  sub r2, r2, r1
  bl libarm_mmu_flat_set_level_1_cacheable_region

  /* Enable the MMU and caches */
  mrc p15, 0, r0, c1, c0, 0          /* Read MMU control register */
  orr r0, r0, #0x00001000            /* Enable ICache */
  orr r0, r0, #0x00000007            /* Enable DCache, MMU and alignment fault */  
#if __TARGET_PROCESSOR==AT91RM9200 
  orr r0, r0, #0xC0000000            /* Enable asynchronous clocking */
#endif
  mcr p15, 0, r0, c1, c0, 0          /* Write MMU control register */
  nop
  nop
#endif
#elif !defined(NO_ICACHE_ENABLE)
  mrc p15, 0, r0, c1, c0, 0          /* Read MMU control register */
  orr r0, r0, #0x00001000            /* Enable ICache */ 
  mcr p15, 0, r0, c1, c0, 0          /* Write MMU control register */
  nop
  nop
#endif

  /****************************************************************************
   * Jump to the default C runtime startup code.                              *
   ****************************************************************************/

  b _start

/* Default clock/memory configuration for a flash build
*/

#if defined(__FLASH_BUILD)
init_sdram_pll:
  // Enable the main oscillator
  ldr r1, =PMC_BASE
  ldr r0, =0x801
  str r0, [r1, #CKGR_MOR_OFFSET]
1:
  ldr r0, [r1, #CKGR_MCFR_OFFSET]
  tst r0, #CKGR_MCFR_MAINRDY
  beq 1b

  ldr r1, =PMC_BASE
  ldr r0, =1
  str r0, [r1, #PMC_MCKR_OFFSET]

  // Set Flash wait states and remap SRAM to address zero
#if __TARGET_PROCESSOR==AT91SAM9XE512 || __TARGET_PROCESSOR==AT91SAM9XE256 || __TARGET_PROCESSOR==AT91SAM9XE128
  ldr r1, =EEFC_BASE
  ldr r0, =0x200
  str r0, [r1, #EEFC_FMR_OFFSET]

  ldr r1, =MATRIX_BASE
  ldr r0, =0x3
  str r0, [r1, #MATRIX_MRCR_OFFSET]  
#endif
  bx lr

  .weak init_sdram_pll
#endif

/******************************************************************************
 *                                                                            *
 * Default exception handlers                                                 *
 * These are declared weak symbols so they can be redefined in user code.     * 
 *                                                                            *
 ******************************************************************************/

undef_handler:
  b undef_handler
  
swi_handler:
  b swi_handler
  
pabort_handler:
  b pabort_handler
  
dabort_handler:
  b dabort_handler
  
irq_handler:
  b irq_handler
  
fiq_handler:
  b fiq_handler

  .weak undef_handler, swi_handler, pabort_handler, dabort_handler, irq_handler, fiq_handler

#if defined(__FLASH_BUILD) && (__TARGET_PROCESSOR==AT91SAM9XE512 || __TARGET_PROCESSOR==AT91SAM9XE256 || __TARGET_PROCESSOR==AT91SAM9XE128)
#include "AT91SAM9XE_mmu_tt.s"
#endif
