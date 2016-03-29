@ Amanda Falke 2015
@ Sitara ARM GPIO LED Pulse Train
@ Using ARM Assembly, this program implements GPIO button interrupts,
@  timer interrupts (a sort of pre-emption), for an LED pulse train.
@
@ Engin-nerds beware: This program goes over 80 cols.


.text
.global _start
.global INT_DIRECTOR
_start:

	@ MAPPING of GPIO2_1 to PIN 18 via gpmc_clk register mapping:
		LDR R6, =0x44E1088C
		MOV R7, #0x00000027		@ copy word to set bits 5, and 0-2 to mode7
		LDR R8,[R6]				@ READ from it,
		ORR R8, R7, R8			@ MODIFY Control Module Reg with mode 7,
		STR R8, [R6]			@ WRITE to Control Module register.


@ Note: Interrupt vector table redirects IRQ to INT_DIRECTOR via hook and chain method.
		

LDR R13,=STACK1			@ Point to base of STACK for SVC mode
ADD R13, R13, #0x1000		@ point to top of stack
	CPS #0x12		@ Switch to IRQ mode
	LDR R13,=STACK2		@ Point to IRQ Stack
	ADD R13, R13, #0x1000	@ Point to top of Stack
	CPS #0x13		@ back to SVC mode


	LDR R0,=0x4804C000	@GPIO1 Base Address
	LDR R1,=0x481AC000	@GPIO2 Base Address


INT_CLEAR:
	ADD R4, R0, #0x190		@ GPIO1_CLEARDATAOUT register,
	MOV R7, #0x01E00000		@ LOAD VALUE TO TURN OFF ALL LED'S,
	STR R7, [R4]			@ TURN OFF ALL LED'S,
	ADD R2, R0, #0x134		@ MAKE GPIO1_OE REGISTER ADDRESS,
	LDR R6, [R2]			@ READ CURRENT GPIO1 ENABLE REGISTER,
	LDR R7,=0xFE1FFFFF		@ WORD TO ENABLE GPIO1 ALL LED'S AS OUTPUT,
	AND R6, R7, R6			@ CLEAR BITS 21, 22, 23, 24 USR0-USR3,
	STR R6, [R2]			@ WRITE TO GPIO1_CLEARDATAOUT REGISTER.
	
@ Detect falling edge on GPIO2_1 and enable to assert POINTERPEND1
@ Write 0x0000 0002 to 0x481AC14C to program GPIO2, pin 1, to detect falling edge. RMW.
	ADD R2, R1, #0x14C		@ R2 = address of GPIO2_FALLINGDETECT reg
	MOV R3, #0x00000002		@ load value for bit 1
	LDR R4, [R2]			@ READ GPIO2_FALLINGDETECT reg
	ORR R4, R4, R3			@ MODIFY (set bit 1)
	STR R4, [R2]			@ WRITE

@ Enable GPIO module to send interrupt request to INTC: 
@ Write 0x00000002 to 0x481AC034
	ADD R2, R1, #0x34		@ Address of GPIO2_IRQSTATUS_SET_0 reg
	STR R3, [R2]			@ enable GPIO2_1 request on POINTERPEND1

	
	
@ Initialize INTC :
@ Enable INTC to respond to an interrupt request:	
	LDR R2,=0x48200000		@ Address of INTC base register,
	
@ TIMER4: CONFIG: Write 0x2 to INTC_SYSCONFIG at 0x4820 0010 to reset INTC:
	MOV R3, #0x2			@ Value to reset INTC
	STR R3, [R2, #0x10]		@ Write to INTC Sys CONFIG register.
	
@ TIMER4: INTERRUPT: Write 0x1000 0000 to 0x482000C8 enable INTC #92 Timer4:
	MOV R3, #0x10000000		@ unmask INTC #92, MIR2 bit 28, hence IRQ2.
	STR R3, [R2, #0xC8]		@ INTC base 4820 + offset 0xC8 INTC_MIR_CLEAR2

@  BUTTON: Write 0x0000 0001 to INTC_MIR_SET1 register at address 0x4820 00A8.
	MOV R3, #0x00000001		@ value to unmask INTC INT 32. GPIOINT2A
	STR R3, [R2, #0xA8]		@ WRITE to INTC_MIR_CLEAR1 register.
	
	
	
@ Turn on Timer4 clock:
@ Write 0x02 to Base Address of CM_PER  0x44E0 0000 base
@ + offset 0x88 for CM_PER_TIMER4_CLKCTRL = Write 0x2 to 0x 44E0 0088 :
	MOV R3, #0x2			@ Value to enable TIMER4 CLK
	LDR R1,=0x44E00088		@ Address CM_PER_TIMER4 CLK
	STR R3, [R1]			@ Turn on CLK
@Set Timer clock frequency MUX for 32K Hz: 
@Write 0x2 to PRCM CLKSEL_TIMER4 register at address 0x44E0 0510 :
	LDR R1,=0x44E00510	@ Address of PRCM CLKSEL_TIMER4 register
	STR R3, [R1]			@ Select 32K CLK for timer 4, by writing 0x2. 


	
@ Initialize Timer 4 registers, with count, overflow interrupt generation				
@7a. Write 0x1 to Timer4 CFG register at 0x4804 4010 to reset Timer4
	LDR R1,=0x48044000		@ Base address TIMER4 registers
	MOV R3, #0x1			@ value to reset TIMER4
	STR R3, [R1, #0x10]		@ Write to TIMER4 CONFIG register 
@7b. Write 0x2 to Timer4 IRQ_ENABLE_SET register at 0x 4804 402C
	MOV R3, #0x2			@ Value to enable Overflow interrupt
	STR R3, [R1, #0x2C]		@ Write to TIMER4 IRQENABLE_SET
@7c. Write 0x FFFF 8000   to Timer4 TLDR TimerLoad reg at 0x4804 4040 to get 1sec
	LDR R3,=0xFFFF8000		@ Count value for 1 second
	STR R3, [R1, #0x40]		@Timer4 TLDR load reg (reload value)
@7d. Write 0x FFFF 8000   to Timer4 TCRR TimerCounter reg at 0x 4804 403C to get 1sec 
	STR R3, [R1, #0x3C]		@ Write to Timer4 TCRR count register
	
	


@ Make sure processor IRQ enabled in CPSR
	MRS R3, CPSR			@ Copy CPSR to R3
	BIC R3, #0x80			@ Clear bit 7
	MSR CPSR_c, R3			@ Write back to CPSR	

	MOV R8, #0x0			@ set LEDFLAG to zero so it falls through the first time.

@ wait for interrupt
	LOOP: NOP	
		
		B LOOP

INT_DIRECTOR:

STMFD SP!, {R0-R3, LR}		@ push registers on stack
	LDR R0,=0x482000B8		@ Address of INTC_PENDING_IRQ1 reg, text p. 236
	LDR R1, [R0]			@ Read INTC_PENDING_IRQ1 register
	TST R1, #0x00000001		@ test bit ZERO of IRQ 1 !!! 	
	
					@  IS TIMER?? If bit 0 = 0 then not BUTTON
	BEQ TIMERCHECK			@ if not from button push, Check if Timer 2, else
	
@ IS BUTTON??  If bit 0 = 1 then check if  button: 
	LDR R0,=0x481AC02C		@ Load GPIO2_IRQSTATUS_0 register address, text p. 131
	LDR R1, [R0]			@ READ status register, to see if button,
	TST R1, #0x00000002		@ Check if bit 1 = 1
	BNE BUTTON_PUSHED		@ If bit 1 = 1, then button pushed!
	
	@ program control moves to PASS_ON here if it's NEITHER button NOR TIMER4:
	
	@ "if bit 1 = 0, then enable new IRQ response in INTC by 
		@ writing 0x1 to INTC_CONTROL register at 4820 0048 to allow new IRQ.

	@BEQ PASS_ON				@ if bit 1 = 0, then :
	LDR R0,=0x48200048		@ Else, go back. Address of INTC_PENDING_IRQ2 reg TIMER4
	MOV R3, #01			@ value to clear bit 0 per sitara manual
	STR R3, [R0]			@ Write to INTC_CONTROL register.
	LDMFD SP!, {R0-R3, LR}		@ Restore registers = POP
	SUBS PC, LR, #4			@ Pass execution on to wait LOOP for now




	
TIMERCHECK:
	LDR R3,=0x482000D8		@ Address of INTC PENDING IRQ2 register
	LDR R0, [R3]			@ Read value
	TST R0, #0x10000000		@ Check if interrupt from TIMER4
	BEQ PASS_ON			@ if not TIMER4 interrupt, return; if YES, check overflow
	@ if yes, aka IS TIMER4 interrupt, check for overflow:
	LDR R3,=0x48044028		@ Address of TIMER4 IRQSTATUS register
	LDR R0, [R3]			@ read value
	TST R0, #0x2			@ check bit 1. Sitara manual p 4341, IRQSTATUS OVERFLOW bit.
	BNE LEDZ			@ if overflow, then go to toggle LEDs
					@ else go back to wait loop
PASS_ON:
	LDR R0,=0x48200048		@ Else, go back. Address of INTC_PENDING_IRQ2 reg TIMER4
	MOV R3, #01			@ value to clear bit 0 
	STR R3, [R0]			@ Write to INTC_CONTROL register.
	LDMFD SP!, {R0-R3, LR}		@ Restore registers = POP
	SUBS PC, LR, #4			@ Pass execution on to wait LOOP for now




	
BUTTON_PUSHED:
	LDR R0,=0x481AC02C		@ Load GPIO2_IRQSTATUS_0 register address, text p. 131
	MOV R1, #0x00000002		@ Value turns off GPIO2_1 interrupt request
							@   also INTC interrupt request
	STR R1, [R0]			@ Write to GPIO2_IRQSTATUS_0 register


@ Start Timer4, and set for auto reload by writing 0x03 to TCLR at 0x 4804 4038:	
	MOV R3, #0x03			@ load value of auto reload timer and start 
	LDR R1,=0x48044038
	STR R3, [R1]

					@ turn off NEWIRQA bit in INTC_CONTROL, so
					@ processor can respond to new IRQ:
	LDR R0,=0x48200048		@ Address of INTC_CONTROL reg p.236
	MOV R1, #01			@ Clear Bit 0
	STR R1, [R0]			@ Write to INTC_CONTROL register


	LDR R0,=0x4804C000		@ LOAD ADDRESS OF GPIO1 REGISTER for LED's.

	
@ if LED's are off, fall through to flash LED's. Else, stop it!
	TST R8, #0x1			@ Check if bit 1 = 1			
	BNE STOPIT			@ If bit LEDFLAG = 1, then button pushed!
					@ if bit LEDFLAG = 0, then FALL THROUGH
	
/* IF LED'S ARE ON, THEN FALL THROUGH TO LEDZ AND THE PARITY CHECK. */
	


			
LEDZ:	
		MOV R8, #0x1		@ set LEDFLAG to 1, therefore "LEDs on."
		
		LDR R0,=0x4804C000	@ LOAD ADDRESS OF GPIO1 REGISTER for LED's.

@ Turn off Timer4 Overflow Interrupt request:
@ Write 0x2 to IRQSTATUS register at 0x4804 4028 :
		LDR R1,=0x48044028	@ load address of Timer4 IRQSTATUS register
		MOV R2, #0x2		@ value to reset timer4 overflow IRQ request (bit1)
		STR R2, [R1]		@ write.

	
/* when hitting the button to START the LEDs, we MUST RESET/ENABLE timer overflow IRQ's.
	TO DO SO, WE USE IRQENABLE_SET REGISTERS IN SITARA MANUAL (TIMER).
 */
	LDR R1,=0x48044000		@ BASE ADDRESS OF TIMER4,
	MOV R3, #0x2			@ WRITE A 1 TO BIT 1 OF BOTH SET AND CLR REGISTERS,
	STR R3, [R1, #0x2C]		@ IRQENABLE_SET
	
	
	
TOGGLEPARITY:

@ TEST PARITY : EVEN OR ODD.   IF 0, GOTO ODDS. IF 1, GOTO EVEN.

		TST R9, #0x1			@ Check if bit 1 = 1			
		BNE EVENS			

	ODDS:
		MOV R9, #0x1			@ SET PARITY TO ODD
		@ clear evens:
		MOV R11, #0x00A00000		@ COPY MASK: EVENS,
		ADD R2, R0, #0x190		@ CLEARDATAOUT ADDRESS,
		STR R11, [R2]			@ WRITE MASK.  CLEAR EVENS.

		@ Set odds:
		MOV R11, #0x01400000		@ COPY MASK: ODDS,
		ADD R2, R0, #0x194		@ SETDATAOUT ADDRESS,
		STR R11, [R2]			@  WRITE MASK.  LIGHT ODDS.
		B PASS_ON_TEMP
		
	EVENS:	
		MOV R9, #0x0			@ SET PARITY TO EVEN
		@ Clear odds:			
		MOV R11, #0x01400000		@ COPY MASK: ODDS
		ADD R2, R0, #0x190		@ CLEARDATAOUT ADDRESS
		STR R11, [R2]			@ WRITE MASK. CLEAR ODDS.
		
		MOV R11, #0x00A00000		@ COPY MASK: EVENS.
		ADD R2, R0, #0x194		@ SETDATAOUT address,
		STR R11, [R2]			@ WRITE MASK, LIGHT EVENS.
		B PASS_ON_TEMP
						
	
STOPIT:
	@ CLEAR LED'S
	MOV R8, #0x0				@ set LEDFLAG to zero
	
	ADD R4, R0, #0x190		@ GPIO1_CLEARDATAOUT register,
	MOV R7, #0x01E00000		@ LOAD VALUE TO TURN OFF ALL LED'S,
	STR R7, [R4]			@ TURN OFF ALL LED'S.
	
/* when hitting the button to stop the LEDs, we MUST disable timer overflow IRQ's.
	TO DO SO, WE USE IRQENABLE_SET AND IRQENABLE_CLR REGISTERS IN SITARA MANUAL (TIMER).
 */
	LDR R1,=0x48044000		@ BASE ADDRESS OF TIMER4,
	MOV R3, #0x2			@ WRITE A 1 TO BIT 1 OF BOTH SET AND CLR REGISTERS,
	STR R3, [R1, #0x2C]		@ IRQENABLE_SET
	STR R3, [R1, #0X30]		@ IRQENABLE_CLR
		
PASS_ON_TEMP:
	@ INTC : RESET FOR NEW IRQ'S!
	LDR R1,=0x48200048		@ address of INTC control register
	MOV R3, #0x01
	STR R3, [R1]			@ Write to INTC_CONTROL register
	
	@return to wait loop
	LDMFD SP!, {R0-R3, LR}	@ Restore registers
	SUBS PC, LR, #4			@ Pass execution on to wait LOOP for now
								
		@LDR R1,=0x481AC02C		@ Load GPIO2_IRQSTATUS_0 register address, text p. 131
		@LDR R2, [R1]			@ READ status register,
		@TST R2, #0x00000002		@ Check if bit 1 = 1
		@BNE STOPIT				@ If bit 1 = 1, then button pushed again, so go back to WAIT!
		

.align 2
SYS_IRQ: .WORD 0			@location to store systems’ IRQ address!

.data

.align 2

STACK1:	.rept 1024
		.word 0x0000
		.endr
STACK2:	.rept 1024
		.word 0x0000
		.endr
		
.END



