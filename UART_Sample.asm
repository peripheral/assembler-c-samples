;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 
; Author:
; Artur Vitt

; Title: Timer and UART:Serial communication using Interrupt
;
; Hardware: STK600, CPU ATmega2560
;
; Function: The application provides functionality to receive/send echo with RS232 with use of interrupts
; and displays received character on LEDS.
;
; Input ports: Port0(RS232) connected to PC, connecting jumper cables RXD/TXD spare RS232 to 
; port D PD2/PD3
;
; Output ports: On-board LEDs connected to PORTB.Port0(RS232) connected to PC, connecting 
; jumper cables RXD/TXD spare RS232 to port D PD2/PD3
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
.EQU speed 				= 12



.CSEG
.ORG 0
	rjmp Reset
.ORG URXC1addr
	rjmp read_from_USART
.ORG UTXC1addr
	rjmp write_to_PORTB
.ORG UDRE1addr
	rjmp write_to_USART
	
	
	
	

.ORG 0x50
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
	;Set baudrate 4800
	ldi r16,12
	sts UBRR1L,r16
	
	;Enable receive interrupt, receive and transmit by USART
	ldi r16,(1 <<TXCIE1)+(1 <<RXCIE1)+(1 << RXEN1)+(1 <<TXEN1)	
	STS UCSR1B,r16


sei
ldi char,0x00 			; Initial char


main:
nop
rjmp main

; Call when receive complete
read_from_USART:
	lds char,UDR1
	;Enable USART Data Register Empty Interrupt
	ldi temp,(1 <<UDRE1)+(1 <<TXCIE1)+(1 <<RXCIE1)+(1 << RXEN1)+(1 <<TXEN1)	
	STS UCSR1B,temp
	reti

; Called by Data Register Empty Interrupt
write_to_USART:
	;Disable USART Data Register Empty Interrupt
	ldi temp,(1 <<TXCIE1)+(1 <<RXCIE1)+(1 << RXEN1)+(1 <<TXEN1)		
	STS UCSR1B,temp
	sts UDR1,char
	reti

; Called on Transmit complete
write_to_PORTB:
	mov temp, char
	com temp
	out PORTB,temp
	reti
