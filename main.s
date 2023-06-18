#include <targets/AT91SAM9.h>
#define ETH_PINS (PIOA_PDR_P12_MASK|PIOA_PDR_P13_MASK|PIOA_PDR_P14_MASK|PIOA_PDR_P15_MASK|PIOA_PDR_P16_MASK| PIOA_PDR_P17_MASK| PIOA_PDR_P18_MASK|PIOA_PDR_P19_MASK|PIOA_PDR_P20_MASK|PIOA_PDR_P21_MASK) // |PIOA_PDR_P23_MASK|PIOA_PDR_P24_MASK|PIOA_PDR_P25_MASK|PIOA_PDR_P26_MASK|PIOA_PDR_P28_MASK)
#define ETHB_PINS (/* PIOA_PDR_P10_MASK|PIOA_PDR_P11_MASK| */ PIOA_PDR_P22_MASK|PIOA_PDR_P23_MASK|PIOA_PDR_P24_MASK|PIOA_PDR_P25_MASK|PIOA_PDR_P26_MASK|PIOA_PDR_P27_MASK|PIOA_PDR_P28_MASK|PIOA_PDR_P29_MASK)
#define DBGU_PINS (PIOB_PDR_P14_MASK|PIOB_PDR_P15_MASK)
#define DELAY 0xfffff
#define AT91_RSTC_KEY (0xa5 << 24)
#define MAC_LOW 0x1a1a1a00
#define MAC_HIGH 0x0000001a
#define ETH_BUFFERS_RX 1024
#define ETH_BUFFERS_TX 1024
#define PHY_ADDR 0x1c

  .code 32
  .global main
  .text

main:

  bl enable_mainck

  bl enable_plla

  bl select_plla

  ldr r0, =(PMC_PCER_EMAC_MASK | PMC_PCER_PIOA_MASK | PMC_PCER_PIOB_MASK| PMC_PCER_SYSC_MASK)
  bl enable_peripheral_clocks
  



  //-------------------------------------PIOA disable pullups, for eth reset initial state

  // Disable pullup on eth pins

  ldr r0,=PIOA_BASE
  ldr r1,=ETH_PINS
  str r1,[r0, #PIOA_PUDR_OFFSET]



  //-------------------------------------Reset using reset controller

  ldr r0,=RSTC_BASE
  ldr r1,=(AT91_RSTC_KEY | (0xd << RSTC_MR_ERSTL_BIT) | RSTC_MR_URSTEN_MASK)
  str r1, [r0, #RSTC_MR_OFFSET]
  ldr r1,=(AT91_RSTC_KEY |RSTC_CR_EXTRST_MASK)
  str r1, [r0, #RSTC_CR_OFFSET]

1:                                // Wait for NRST to come back down
  ldr r1, [r0, #RSTC_SR_OFFSET]
  tst r1, #RSTC_SR_NRSTL_MASK
  beq 1b

  bl delay


  // Re-enable pullup on eth pins

  ldr r0,=PIOA_BASE
  ldr r1,=ETH_PINS
  str r1,[r0, #PIOA_PUER_OFFSET]


  //-------------------------------------Enabling Eth pins on PIOA


  // Disable IO for eth pins

  ldr r0,=PIOA_BASE
  ldr r1,=ETH_PINS
  str r1,[r0, #PIOA_PDR_OFFSET]

  ldr r0,=PIOA_BASE
  ldr r1,=ETHB_PINS
  str r1,[r0, #PIOB_PDR_OFFSET]

  // Select periphal A on eth pins

  ldr r0,=PIOA_BASE
  ldr r1,=ETH_PINS
  str r1,[r0, #PIOA_ASR_OFFSET]

  // Select periphal B on eth pins

  ldr r0,=PIOA_BASE
  ldr r1,=ETHB_PINS
  str r1,[r0, #PIOA_BSR_OFFSET]




  //-------------------------------------Enabling DBGU pins on PIOB

  // Disable IO for eth pins

  ldr r0,=PIOB_BASE
  ldr r1,=DBGU_PINS
  str r1,[r0, #PIOB_PDR_OFFSET]

  // Disable pullup on eth pins

  ldr r0,=PIOB_BASE
  ldr r1,=DBGU_PINS
  str r1,[r0, #PIOA_PUDR_OFFSET]
  
  // Select periphal A on eth pins

  ldr r0,=PIOB_BASE
  ldr r1,=DBGU_PINS
  str r1,[r0, #PIOB_ASR_OFFSET]






  //-------------------------------------DBGU Transmit enable

  // Baud rate gen from 90MHz to 115200
  ldr r0,=DBGU_BASE
  ldr r1,=0x00000030            // 90MHz / 115200 / 16 = 49. 0x30
  str r1,[r0, #DBGU_BRGR_OFFSET]


  ldr r1,=(1 << DBGU_CR_TXEN_BIT)
  str r1,[r0, #DBGU_CR_OFFSET]


  ldr r1,=(1 << DBGU_MR_PAR_BIT)
  str r1,[r0, #DBGU_MR_OFFSET]






  //-------------------------------------Transmit Hello World

  ldr r0, =helloworld
  bl dbgu_puts

  ldr r0, =registeris
  bl dbgu_puts

  ldr r0, =0x1234abcd
  bl dbgu_print_reg








  //-------------------------------------Buffer management
  // Initialize rxbuffer
  ldr r0,=rxbuffer
  add r1,r0, #(ETH_BUFFERS_RX * 128)
  ldr r2,=0x0
  bl memory_set

  // Initialize txbuffer
  ldr r0,=txbuffer
  add r1,r0, #(ETH_BUFFERS_TX * 128)
  ldr r2,=0x0
  bl memory_set

  // Initialize rxbufferlist

  ldr r0,=rxbufferlist
  ldr r1,=ETH_BUFFERS_RX
  ldr r2,=rxbuffer
  bl initialize_eth_buffer

  // Initialize txbufferlist

  ldr r0,=txbufferlist
  ldr r1,=ETH_BUFFERS_TX
  ldr r2,=txbuffer
  bl initialize_eth_buffer

  
  
  // Receive bufferlist pointer
  ldr r1,=EMAC_BASE
  ldr r0,=rxbufferlist
  str r0,[r1, #EMAC_RBQP_OFFSET]
  
  // Transmit bufferlist pointer
  ldr r1,=EMAC_BASE
  ldr r0,=txbufferlist
  str r0,[r1, #EMAC_TBQP_OFFSET]



  //-------------------------------------Network control reg NCR NCFGR
   


  /*
  orr r0,r0,#EMAC_NCR_TSTART_MASK       // Transmit Start
  str r0,[r1, #EMAC_NCR_OFFSET]
  */

   // Network config reg
  ldr r1,=EMAC_BASE
  ldr r0,=(0x3 << EMAC_NCFGR_CLK_BIT)   | EMAC_NCFGR_SPD_MASK| EMAC_NCFGR_FD_MASK | EMAC_NCFGR_NBC_MASK // | EMAC_NCFGR_CAF_MASK 
  str r0,[r1, #EMAC_NCFGR_OFFSET]

/*
  // Check network status
  ldr r1,=EMAC_BASE
  ldr r0,[r1, #EMAC_NSR_OFFSET]
  mov r1,r0
  */




  // PIOA_PSR
  ldr r1,=PIOA_BASE
  ldr r0,[r1, #PIOA_PSR_OFFSET]
  mov r5,r0

  // PIOA_PUSR
  ldr r1,=PIOA_BASE
  ldr r0,[r1, #PIOA_PUSR_OFFSET]
  mov r6,r0

  // PIOA_ABSR
  ldr r1,=PIOA_BASE
  ldr r0,[r1, #PIOA_ABSR_OFFSET]
  mov r7,r0



  





  // PIOA_PER enable
  ldr r5,=PIOA_BASE
  ldr r6,=PIOA_PER_P6_MASK
  str r6,[r5, #PIOA_PER_OFFSET]

  // PIOA_OER output enable
  str r6,[r5, #PIOA_OER_OFFSET]


  // Find valid PHY addr

  ldr r11, =PHY_ADDR
  ldr r12,=phy_addr
  str r11,[r12]

  /*
1:
  ldr r0,=str_reg
  bl dbgu_puts
  mov r0,r11
  bl dbgu_print_reg       // Display phy_addr

  ldr r0,=str_data
  bl dbgu_puts

  mov r0, #0x11            // REG PHY_ID1 
  bl phy_read
  bl dbgu_print_reg       // Display reg PHY_ID1 output from the given phy_addr

  subs r11, #1
  bne 1b
*/

  bl mac_init
  bl phy_init

  bl phy_autoneg

  bl phy_activate



/*
// DEBUG
  ldr r0,=phy_addr
  mov r1,#0x0
  str r1,[r0]
*/
repeat:
/*
  // DEBUG
  ldr r0,=phy_addr
  ldr r1,[r0]
  add r1,r1,#1
  str r1,[r0]
*/


  str r6,[r5, #PIOA_CODR_OFFSET] // clear LED
  bl delay


  str r6,[r5, #PIOA_SODR_OFFSET] // set LED
  bl delay




  ldr r0,=helloworld
  bl dbgu_puts


  ldr r0,=str_pmc_pcsr
  bl dbgu_puts

  ldr r1,=PMC_BASE
  ldr r0,[r1,#PMC_PCSR_OFFSET]  // Peripherl Clock Status Reg
  bl dbgu_print_reg


  ldr r0,=str_ckgr_pllar
  bl dbgu_puts  

  ldr r1,=PMC_BASE
  ldr r0,[r1,#CKGR_PLLAR_OFFSET]  // Clock Generator PLLA R
  bl dbgu_print_reg


  ldr r0,=str_dbgu_cidr
  bl dbgu_puts  

  ldr r1,=DBGU_BASE
  ldr r0,[r1,#DBGU_CIDR_OFFSET]  // DBGU Chip ID R
  bl dbgu_print_reg


  ldr r0,=str_pioa_psr
  bl dbgu_puts  

  ldr r1,=PIOA_BASE
  ldr r0,[r1,#PIOA_PSR_OFFSET]  // PIOA Peripheral Status R
  bl dbgu_print_reg


  ldr r0,=str_piob_psr
  bl dbgu_puts  

  ldr r1,=PIOB_BASE
  ldr r0,[r1,#PIOB_PSR_OFFSET]  // PIOB Peripheral Status R
  bl dbgu_print_reg


  ldr r0,=str_emac_ncr
  bl dbgu_puts  

  ldr r1,=EMAC_BASE
  ldr r0,[r1,#EMAC_NCR_OFFSET]  // EMAC Network Ctrl R
  bl dbgu_print_reg


  ldr r0,=str_emac_ncfgr
  bl dbgu_puts  

  ldr r1,=EMAC_BASE
  ldr r0,[r1,#EMAC_NCFGR_OFFSET]  // EMAC Network Cfg R
  bl dbgu_print_reg


  ldr r0,=str_emac_nsr
  bl dbgu_puts  

  ldr r1,=EMAC_BASE
  ldr r0,[r1,#EMAC_NSR_OFFSET]  // EMAC Network Status R
  bl dbgu_print_reg


  ldr r0,=str_emac_rbqp
  bl dbgu_puts  

  ldr r1,=EMAC_BASE
  ldr r0,[r1,#EMAC_RBQP_OFFSET]  // EMAC RX buffer queue pointer R
  bl dbgu_print_reg


  ldr r0,=str_emac_tbqp
  bl dbgu_puts  

  ldr r1,=EMAC_BASE
  ldr r0,[r1,#EMAC_TBQP_OFFSET]  // EMAC TX buffer queue pointer R
  bl dbgu_print_reg


  ldr r0,=str_emac_man
  bl dbgu_puts  

  ldr r1,=EMAC_BASE
  ldr r0,[r1,#EMAC_MAN_OFFSET]  // EMAC PHY Maint R
  bl dbgu_print_reg


  ldr r0,=str_emac_usrio
  bl dbgu_puts  

  ldr r1,=EMAC_BASE
  ldr r0,[r1,#EMAC_USRIO_OFFSET]  // EMAC IO cfg R
  bl dbgu_print_reg


  ldr r0,=str_emac_rsr
  bl dbgu_puts  

  ldr r1,=EMAC_BASE
  ldr r0,[r1,#EMAC_RSR_OFFSET]  // EMAC RX status
  bl dbgu_print_reg


  ldr r0,=str_phy_control
  bl dbgu_puts  

  mov r0,#0
  bl phy_read
  bl dbgu_print_reg 


  ldr r0,=str_phy_status
  bl dbgu_puts  

  mov r0,#1
  bl phy_read 
  bl dbgu_print_reg


  ldr r0,=str_phy_autoneg
  bl dbgu_puts  

  mov r0,#4
  bl phy_read 
  bl dbgu_print_reg


  ldr r0,=str_phy_anlpar
  bl dbgu_puts  

  mov r0,#5
  bl phy_read   
  bl dbgu_print_reg


  ldr r0,=str_phy_specific
  bl dbgu_puts  
  
  mov r0,#0x10
  bl phy_read   
  bl dbgu_print_reg


  ldr r0,=str_phy_specific_cfg
  bl dbgu_puts  
  
  mov r0,#0x14
  bl phy_read   
  bl dbgu_print_reg


  ldr r0,=str_phy_dscsr
  bl dbgu_puts  
  
  mov r0,#0x11
  bl phy_read   
  bl dbgu_print_reg


 

  b repeat
//end--------------------------------------------------------------------------------------------------------------------------

// FUNCTIONS








enable_mainck:  //------------------------------------Enable the main oscillator 18.432MHz
  stmfd sp!,{r0,r1,lr}
  
  ldr r1, =PMC_BASE
  ldr r0, =(0x8 << CKGR_MOR_OSCOUNT_BIT) | (0x1 << CKGR_MOR_MOSCEN_BIT) // old: 0x801
  str r0, [r1, #CKGR_MOR_OFFSET]

  // Wait for Main OSC lock MOSCS
1:
  ldr r0, [r1, #PMC_SR_OFFSET]
  tst r0,#0x1
  beq 1b
  ldmfd sp!,{r0,r1,pc}



enable_plla:    //-------------------------------------Configuring PLLA for 180MHz
  stmfd sp!,{r0,r1,lr}
  
  //  OUTA is 10 for 180MHz freq range
  //  PLLACOUNT 0x3f
  //  MULA 624 0x270(multiplier adds 1)
  //  DIVA 64 0x40
  // 18.432 x 625 / 64 = 180MHz
  ldr r1, =PMC_BASE
  ldr r0, =((1 << 29) |(0x270 << CKGR_PLLAR_MULA_BIT) | (0x3f << CKGR_PLLAR_PLLACOUNT_BIT)|(0x2 << CKGR_PLLAR_OUTA_BIT)|(0x40 << CKGR_PLLAR_DIVA_BIT))
  str r0, [r1, #CKGR_PLLAR_OFFSET]


  // Wait for LOCKA for PLLA
1:
  ldr r0, [r1, #PMC_SR_OFFSET]
  tst r0, #PMC_SR_LOCKA_MASK
  beq 1b
  ldmfd sp!,{r0,r1,pc}




select_plla:    //--------------------------------------Selecting PLLA
  stmfd sp!,{r0,r1,lr}
  ldr r1, =PMC_BASE
  ldr r0, =(0x2 << PMC_MCKR_CSS_BIT) | (0x0 << PMC_MCKR_PRES_BIT)|(0x1 << PMC_MCKR_MDIV_BIT) // Select PLLA + DIV by 2
  str r0, [r1, #PMC_MCKR_OFFSET]
  // Wait for MCKRDY
1:
  ldr r0, [r1, #PMC_SR_OFFSET]
  tst r0,#PMC_IDR_MCKRDY_MASK
  beq 1b
  ldmfd sp!,{r0,r1,pc}




enable_peripheral_clocks:     //-------------------------------------Enabling peripheral clocks
  stmfd sp!,{r0,r1,lr}
  ldr r1, =PMC_BASE  
  str r0, [r1, #PMC_PCER_OFFSET]
  ldmfd sp!,{r0,r1,pc}

















phy_init:
  stmfd sp!,{r0,r1,lr}

 // Check PHY
  ldr r1,=EMAC_BASE
  

 // bl enable_mpe
  mov r0,#0x0
  bl phy_read
  orr r1, r0, #0x8000                 // RESET


  mov r0,#0x0
  bl phy_write    



  mov r0,#0x15      // Interrupt REG MDINTR
  bl phy_read
  orr r0, #0x0f00   // Disable Interrupts
  ldr r1, =0xffff
  and r1,r0,r1 // Sanitize

  mov r0,#0x15
  bl phy_write


  ldmfd sp!,{r0,r1,pc}







mac_init:
  //-------------------------------------Ethernet MAC set
  stmfd sp!,{r0,r1,lr}
  ldr r1,=EMAC_BASE
  ldr r0,=MAC_LOW
  str r0,[r1, #EMAC_SA1B_OFFSET]
  ldr r0,=MAC_HIGH
  str r0,[r1, #EMAC_SA1T_OFFSET]


    
  ldr r0,=(EMAC_USRIO_RMII_MASK | EMAC_USRIO_CLKEN_MASK)    // Enable RMII and CLK
  str r0,[r1,#EMAC_USRIO_OFFSET]

  bl wait_nsr_idle


  ldmfd sp!,{r0,r1,pc}









phy_autoneg:
  stmfd sp!,{r0,r1,r2,lr}

  mov r0, #0x0      // Read BMCR
  bl phy_read

  bic r0, #0x1000    // Disable Autonegotiate
  orr r1, r0, #0x0400    // Isolate
  mov r0,#0x0

  bl phy_write

  mov r0, #0x0      // Extra BMCR Read
  bl phy_read

  ldr r1, =0x01e1   // Capabilities //81e1?
  mov r0, #0x4      // ANAR
  
  bl phy_write

  mov r0, #0x0
  bl phy_read

  mov r0, #0x0
  orr r1, r0, #0x3100  // Disable Isolate
  mov r2, r1

  bl phy_write

  mov r0, #0x0
  bl phy_read

  orr r1, r0, #0x0200   // Restart Autoneg
 // bic r1, r1, #0x0400   // Disable Isolate

  mov r0, #0x0
  bl phy_write

  mov r0,#0x1
  bl phy_read           // Read Status

  ldmfd sp!,{r0,r1,r2,pc}




  
phy_activate:
  //-------------------------------------Disable loopback and start TX and RX
  stmfd sp!,{r0,r1,lr}
  ldr r1,=EMAC_BASE
  ldr r0,[r1, #EMAC_NCR_OFFSET]                           // Read current state

  bic r0, r0, #(EMAC_NCR_TE_MASK | EMAC_NCR_RE_MASK)        // Disable RX TX
  str r0,[r1, #EMAC_NCR_OFFSET]
  bl wait_nsr_idle

  bic r0,r0, #(EMAC_NCR_LB_MASK|EMAC_NCR_LLB_MASK)         // Disable loopback
  str r0,[r1, #EMAC_NCR_OFFSET]
  bl wait_nsr_idle

  orr r0,r0, #( EMAC_NCR_TE_MASK | EMAC_NCR_RE_MASK)   // Enable RX TX
  str r0,[r1, #EMAC_NCR_OFFSET]
  bl wait_nsr_idle

  ldmfd sp!,{r0,r1,pc}




// Input r0 = register
// Output r0 = data
phy_read:
  stmfd sp!,{r1,r2,r3,lr}
  ldr r1,=EMAC_BASE

  bl enable_mpe
  bl wait_nsr_idle

  ldr r3,=phy_addr
  ldr r3,[r3]
  mov r3,r3, lsl #EMAC_MAN_PHYA_BIT
  
  mov r0,r0, LSL #EMAC_MAN_REGA_BIT
  ldr r2,=( 0x01 <<EMAC_MAN_SOF_BIT ) | (0x2 << EMAC_MAN_RW_BIT) | (0x2 << EMAC_MAN_CODE_BIT)
  orr r0,r2,r0
  orr r0,r3,r0
  str r0,[r1, #EMAC_MAN_OFFSET]

 
  bl delay

  ldr r0,[r1, #EMAC_MAN_OFFSET]

  bl disable_mpe
  bl wait_nsr_idle
  ldmfd sp!,{r1,r2,r3,pc}





// Input r0 = register
//       r1 = data
phy_write:
  stmfd sp!,{r0,r1,r2,r3,lr}
  ldr r2, =0xffff         // Sanitize input
  and r1, r1, r2

  ldr r2,=EMAC_BASE

  bl enable_mpe
  bl wait_nsr_idle

  ldr r3,=phy_addr
  ldr r3,[r3]
  mov r3,r3, lsl #EMAC_MAN_PHYA_BIT  

  
  
  mov r0,r0, LSL #EMAC_MAN_REGA_BIT
  orr r0,r1,r0                        // Combine REG and DATA
  orr r0,r3,r0  

  ldr r1,=( 0x01 <<EMAC_MAN_SOF_BIT ) | (0x1 << EMAC_MAN_RW_BIT) | (0x2 << EMAC_MAN_CODE_BIT)

  orr r0,r1,r0                        // Combine other flags
  str r0,[r2, #EMAC_MAN_OFFSET]


  bl delay

  ldr r0,[r2, #EMAC_MAN_OFFSET]

  bl disable_mpe
  ldmfd sp!,{r0,r1,r2,r3,pc}



wait_nsr_idle:
  stmfd sp!,{r8,r9,lr}
  ldr r8,=EMAC_BASE
1:
  ldr r9,[r8,#EMAC_NSR_OFFSET]
  tst r9, #EMAC_NSR_IDLE_MASK
  beq 1b
  ldmfd sp!,{r8,r9,pc}



enable_mpe:
  stmfd sp!,{r5,r6,lr}
  ldr r5,=EMAC_BASE
  ldr r6,[r5, #EMAC_NCR_OFFSET]
  orr r6,r6, #EMAC_NCR_MPE_MASK                             // Enable MPE for phy mgmt
  str r6,[r5, #EMAC_NCR_OFFSET]
  ldmfd sp!,{r5,r6,pc}

disable_mpe:
  stmfd sp!,{r5,r6,lr}
  ldr r5,=EMAC_BASE
  ldr r6,[r5, #EMAC_NCR_OFFSET]
  bic r6,r6, #EMAC_NCR_MPE_MASK                             // Disable MPE for phy mgmt
  str r6,[r5, #EMAC_NCR_OFFSET]
  ldmfd sp!,{r5,r6,pc}




// Build ethernet rx or tx buffer link list.
// r0 = buffer list
// r1 = number of buffers
// r2 = buffer

initialize_eth_buffer:
  stmfd sp!,{r0,r1,r2,r3,r4,lr}
  add r1,r0, r1, lsl #3

  ldr r3,=0x4
  ldr r4,=0x0 
1:
  str r2,[r0],r3        //  First word: address of buffer
  str r4,[r0],r3        // Second word: zeros
  add r2,r2, #0x80      // Increment to next buffer

  cmp r0,r1
  bne 1b

  sub r0, r0, #0x8
  sub r2, r2, #0x80         // Add 1 wrap bit to last descriptor list
  add r2, r2, #0x2
  str r2,[r0],r3

  ldmfd sp!,{r0,r1,r2,r3,r4,pc}



delay:
  ldr r4,=DELAY

delaywait:
  subs r4,#1
  bne delaywait

  mov pc,lr



// r0: register to print
dbgu_print_reg:                   
  stmfd sp!,{r1,r2,r3,r4,lr}
  ldr r1,=DBGU_BASE               // r1 is DBGU base
  mov r4,#0x20                    // 8 x 4 chars in a reg representation

2:
  subs r4, #4
  ldmmi sp!,{r1,r2,r3,r4,pc}                     // If no more bytes, exit

  mov r2, r0, LSR r4               // r2 has the byte to display
  and r2,#0xf
  cmp r2, #0x9                    // Numbers or letters?
  addle r2, r2, #0x30             // Numbers start at 0x30 in ASCII
  addgt r2, r2, #0x37             // Capital letters start at 0x41 in ASCII, but 0xa is 10

1:
  ldr r3, [r1, #DBGU_SR_OFFSET]   // r3 status register
  tst r3, #DBGU_SR_TXRDY_MASK     // Is TX RDY?
  beq 1b                          // If not (Z == 1) then wait another cycle
  str r2,[r1, #DBGU_THR_OFFSET]   // Send r2/byte into TX holding register
  b 2b




// r0 is address of beginning of string
dbgu_puts:                
  push {r0,r1,r2,r3,lr}
  ldr r1,=DBGU_BASE       // r1 is DBGU base
2:
  ldrb r2,[r0], #1        // r2 is byte
  tst r2, #0xff           // Check the low byte
  popeq {r0,r1,r2,r3,pc}     // Exit if this byte is 0x00
1:
  ldr r3, [r1, #DBGU_SR_OFFSET]   // r3 status register
  tst r3, #DBGU_SR_TXRDY_MASK      // Is TX RDY?
  beq 1b                          // If not (Z == 1) then wait another cycle
  str r2,[r1, #DBGU_THR_OFFSET]   // Send r2/byte into TX holding register
  b 2b




  .data
helloworld:
  .asciz "\r\n----------------Hello World App--------------\r\n\r\n"

registeris:
  .asciz "\r\nRegister: "

str_pmc_pcsr:   .asciz  "\r\nPMC_PCSR: "
str_ckgr_pllar: .asciz  "\tCKGR_PLLAR: "
str_dbgu_cidr:  .asciz  "\tDBGU_CIDR: "
str_pioa_psr:   .asciz  "\r\nPIOA_PSR: "
str_piob_psr:   .asciz  "\tPIOB_PSR: "
str_emac_ncr:   .asciz  "\r\nEMAC_NCR: "
str_emac_ncfgr: .asciz  "\tEMAC_NCFGR: "
str_emac_nsr:   .asciz  "\tEMAC_NSR: "
str_emac_rbqp:  .asciz  "\r\nEMAC_RBQP: "
str_emac_tbqp:  .asciz  "\tEMAC_TBQP: "
str_emac_man:   .asciz  "\tEMAC_MAN: "
str_emac_usrio: .asciz  "\r\nEMAC_USRIO: "
str_emac_rsr: .asciz  "\tEMAC_RSR: "
str_phy_status: .asciz  "\r\nPHY_STATUS: "
str_phy_control: .asciz  "\r\nPHY_CONTROL: "
str_phy_autoneg: .asciz  "\r\nPHY_AUTONEG: "
str_phy_specific: .asciz  "\r\nPHY_SPECIFIC: "
str_phy_specific_cfg: .asciz  "\r\nPHY_SPECIFICCFG: "
str_phy_dscsr: .asciz  "\r\nPHY_DSCSR: "
str_phy_anlpar: .asciz  "\r\nPHY_ANLPAR: "
str_reg: .asciz  "\r\nREG: "
str_data: .asciz  " DATA: "

phy_addr: 
  .align 4
  .skip 4