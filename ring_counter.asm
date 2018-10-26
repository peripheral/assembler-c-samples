;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 
;
; Author:
; Artur Vitt
;
;
; 
; Title: How to use the PORTs. Digital input/output. Subroutine call.
;
; Hardware: STK600, CPU ATmega2560 with clock rate set to 1.0 MHz
;
; Function: Create a ring counter with help of LSL or LSR instructions. The counter will have
; delay of 0.5s between each count. The delay should be used as subroutine, which requires stack pointer initiated.
; For delay to be 0.5s the clock rate should be 1.0000 MHz
; Input ports: Not used
; 
;
; Output ports: On-board LEDs connected to PORTB.
; 
;
; Subroutines: delay
; Included files: Include files "m2560def.inc"
;
; Other information:
;
; Changes in program: (Description and date)
;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
.include "m2560def.inc"
; Initialize SP, Stack Pointer
ldi r20, HIGH(RAMEND) ; R20 = high part of RAMEND address
out SPH,R20 ; SPH = high part of RAMEND address
ldi R20, low(RAMEND) ; R20 = low part of RAMEND address
out SPL,R20 ; SPL = low part of RAMEND address

;Load data direction register B (DDRB) setting all bits to 1, to output
ldi r16,0xFF
out DDRB,r16
.DEF ringCounter = r16
.DEF temp = r17
.DEF complement = r18
ldi ringCounter,0x01


main:
mov complement,ringCounter
com complement
out PORTB,complement
lsl ringCounter
in temp,SREG
sbrc temp,1
ldi ringCounter,0x01


rcall routine_delay				;Gives ~500 050 cycles, with 1.0 MHz ~ 0.5 sec
rjmp main

routine_delay:
push r18
push r16
push r17
ldi r16,0x00
ldi r18,0x00


loop:
	ldi r17,0x00
	inc r16;
	cpi r16,0xF9
	brlo loop2 			;If r16 is less than 250, go to inner loop2,r16 counts times loop2 called,
	breq intro_loop2
							; gives ~250000 cycles 
	
	ldi r16,0x00			;If r16 is equal to 250, set r16 to 0 and increment r18
	inc r18

	cpi r18,0x02
	brlo loop				;if r18 is lower than 0x02 start loop from the begining, r18 counts outer loops

	breq end				;else branch to end sequence
		intro_loop2:
		ldi r17,(250-188)	; reduce last loop to deal with extra cycles due to braching in loop2
							; loop2 gives 1001 cycles
		loop2:
			inc r17			; 1 cycle 
			cpi r17,0xF9 	; 1 cycle
			brlo loop2 		; 1 cycle condition false, 2 cycles condition is true
		nop
		nop
		nop
	rjmp loop				;
end:
	pop r17
	pop r16
	pop r18
	ret

