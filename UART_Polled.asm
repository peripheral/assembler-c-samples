;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 
; Author:
; Artur Vitt
;
; 
; Title: Serial communication with echo
;
; Hardware: STK600, CPU ATmega2560
;
; Function: The program should receive character, send an echo back to PC and display on LEDs.
; Using polled communication.
;
; Input ports: Port0(RS232) connected to PC, connecting jumper cables RXD/TXD spare RS232 to 
; port D PD2/PD3
; 
;
; Output ports: On-board LEDs connected to PORTB.Port0(RS232) connected to PC, connecting 
; jumper cables RXD/TXD spare RS232 to port D PD2/PD3
; 
;
; Subroutines: read_from_USART - waits for receive complete flag and read char from UDR1 
;			   write_to_USART - waits for empty flag and writes char to UDR1
; Included files: m2560def.inc
;
; Other information:
;
; Changes in program: (Description and date)
;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
.INCLUDE "m2560def.inc"
.DEF char				= r16
.DEF temp 				= r18
.EQU TIMER0VAL			= 50
.EQU speed 				= 12



.CSEG
.ORG 0
	rjmp Reset



.ORG 0x30
Reset:
;Initilize SP, stack pointer
ldi r16,HIGH(RAMEND)
out SPH,r16
ldi r16,LOW(RAMEND)
out SPL,r16

;Configure PORTB for leds
ldi r16,0xFF
out DDRB,r16
ldi r16,0xFF		; Initial value LED ON
out PORTB,r16


USART_init:

	ldi r16,12				;Set baud rate 4800 under CPU clock 1.0 MHz
	sts UBRR1L,r16

	ldi r16,(0 <<RXCIE1)+(1 << RXEN1)+(1 <<TXEN1)
	STS UCSR1B,r16



;sei
ldi char,0x00 			; Initial char


main:
rcall read_from_USART
rcall write_to_USART
rcall write_to_PORTB


rjmp main

read_from_USART:
	lds temp, UCSR1A
	sbrs temp, RXC1
	rjmp read_from_USART
	
	lds char,UDR1
	ret


write_to_USART:
	; Wait for empty transmit buffer
	lds temp, UCSR1A
	sbrs temp, UDRE1
	rjmp write_to_USART
	; Put char  into buffer, sends the data
	sts UDR1,char
	ret



write_to_PORTB:
	mov temp, char
	com temp
	out PORTB,temp
	ret
