;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 1DT301, Computer Technology I
; Date: 2018-10-04
; Author:
; Artur Vitt
;
; Lab number: 3
; Title: How to use the PORTs. Digital input/output. Subroutine call.
;
; Hardware: STK600, CPU ATmega2560
;
; Function: A program that simulates the rear lights on a car when turning or when not turning
; but car in motion. The turning behaviour is initiated via external interrupts which physically 
; connected to PORTD. SW0 when pressed triggers behaviour of LEDs presenting action of car turning
; right and the same for SW1 but behavior of LEDs presents action of turning left.
; The LEDs are connected to PORTB
; 
;
; Input ports: PORTD is used as input port to read from on-board switches.
; 
;
; Output ports: on-board LEDs connected to PORTB.
; 
;
; Subroutines: routine_turn, routine_turn_left,routine_turn_right, TurnLeftInterrupt, TurnRightInterrupt
; Included files: m2560def.inc
;
; Other information:
;
; Changes in program: (Description and date)
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
.include "m2560def.inc"
.DEF normalLight = r16
.DEF output = r17
.DEF turningLight = r18
.DEF appState = r19

.CSEG
.ORG 0
	rjmp Reset		;Address for program restart(Reset)
.ORG INT0addr
	rjmp TurnRightInterrupt	;Address to interrupt for INT0
.ORG INT1addr
	rjmp TurnLeftInterrupt	;Address to interrupt for INT1

.ORG 0x10
Reset:
; Initialize SP, Stack Pointer
ldi r20, HIGH(RAMEND) ; R20 = high part of RAMEND address
out SPH,R20 ; SPH = high part of RAMEND address
ldi R20, low(RAMEND) ; R20 = low part of RAMEND address
out SPL,R20 ; SPL = low part of RAMEND address

;Load data direction register B (DDRB) setting all bits to 1, to output
ldi r16,0xFF
out DDRB,r16

;Load data direction register A (DDRA) setting 0 bit to 0, to input
ldi r16,0xFC
out DDRD,r16

;Set delay length millis, on processor with 1.0 MHz
ldi r25,0x01
ldi r24,0xF4

ldi r16,(1<<INT0)+(1<<INT1)		;Sett INT0,INT1 interrupts
out EIMSK,r16
ldi r16,(1<<ISC00)+(0<<ISC01)+(1<<ISC10)+(0<<ISC11) 
clr r27
ldi r26,0x69
st X+,r16
sei



ldi appState,0x00 			;If bit 0 set turning right, if bit 1 set turning left,
							;if bit 1 set turning
ldi normalLight,0xC3
ldi turningLight,0x00

main:
	mov output,normalLight 			; Start value normal light

	sbrc appState,1
	rcall routine_turn			;Call routine turn if bit 1 in appState set

	sbrc appState,1				; Apply turning light to output via OR if bit 1 is set in appState
	OR output,turningLight

	com output					; Produce complement of output
	out PORTB,output			;Write to port B complement
	rcall wait_miliseconds
	rjmp main

routine_turn:
	sbrs appState,0
	andi output,0xF0
	sbrc appState,0
	andi output,0x0F
	sbrc appState,0
	rcall routine_turn_left
	sbrs appState,0
	rcall routine_turn_right
	ret

routine_turn_left:
	lsl turningLight
	brbc 1,return
	ldi turningLight,0x10
	ret

routine_turn_right:
	lsr turningLight
	brbc 1,return
	ldi turningLight,0x08
	ret

	return:
	ret


wait_miliseconds:   ; Gives 0.5 sec if clock rate is 1.0 MHz
	push r18
	push r17
	push r27
	push r26
	movw r27:r26,r25:r24

	loop:
		ldi r17,0x00
		sbiw r27:r26,1
		brbs 1,end 	;Goes to end sequence when all millis finished
	
	 				; gives ~500000 cycles 
								
								; loop2 gives 1000 cycles
		loop2:
			inc r17			; 1 cycle 
			cpi r17,0xF9 	; 1 cycle
			brlo loop2 		; 1 cycle condition false, 2 cycles condition is true
		nop


		rjmp loop				;
	end:
		pop r26
		pop r27
		pop r17
		pop r18
		ret


TurnLeftInterrupt:
	sbrs appState,1
	rjmp setTurnLeftFlagAndReturn 	; Sets bits in register that indicates turning bit 1 and direction bit 0
	
	rjmp clearAndReturn


	setTurnLeftFlagAndReturn:
		ldi turningLight,0x10
		sbr appState,0x03
		reti

TurnRightInterrupt:
	sbrs appState,1
	rjmp setTurnRightFlagAndReturn
	
	rjmp clearAndReturn


	setTurnRightFlagAndReturn:
		ldi turningLight,0x08
		sbr appState,0x02
		cbr appState,0x01
		reti
	
clearAndReturn:						; Clear bit 1, stop turning procedure
	cbr appState,0x02
	reti
