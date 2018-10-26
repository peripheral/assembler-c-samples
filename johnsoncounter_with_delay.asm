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
; Function: Johnson counter in a infinite loop, with delay between steps 0.5 sec
; 
;
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
.DEF johnsonCounter = r16
.DEF complement = r17
.DEF direction = r18
ldi direction,0x01 			; turning right if 0, turning left if 1
ldi johnsonCounter,0x01


main:
mov complement,johnsonCounter
com complement
out PORTB,complement
sbrc direction,0
lsl johnsonCounter

sbrc direction,0
inc johnsonCounter

sbrs direction,0
lsr johnsonCounter

sbrc johnsonCounter,7
ldi direction,0x00

sbrs johnsonCounter,0
ldi direction,0x01

rcall routine_delay
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


