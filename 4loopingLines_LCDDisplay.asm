;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
; 
; 
; Author:
; Artur Vitt
;
; 
; Title: Serial communication and display.
;
; Hardware: STK600, CPU ATmega2560
;
;	Function
;	--------
;	The program should be able to display 4 lines of text. Each line should be 
;	displayed under 5 seconds, after that the text on the line 1 should be moved
;	to line 2 and so on. The text should be entered from terminal program, PUTTY
;   
;
;	(run @ 1.8432 MHz clk frequency)
;	
;
; Input ports: 
;
; Output ports: PORTE connected to LCD display
; 
;
; Subroutines:	init_disp - initiates display
;			  	write_char - writes character in Data variable to the display
;			  	write_cmd - writes command to display
;				Get_Char_FromUSART - gets character from Usart, requires
;				interrupt to be used.
;				SendEchoUSART - sends echo, if char is \r new lines char also sent
;				write_char_to_SRAM - writes character to SRAM on space for text lines
;				provides features to jump between lines
;				ShiftLines - called by timer interrupt to perform line rotation
;				when complete startLine increased by 1
;				write_line - prints 40 characters from SRAM, with use of Y pointer
;				setNextYStartPosition - prepares Y pointer, uses and modifies startLine
;				variable
;				CopyToSRAM - populates space for lines with space characters
; Included files: m2560def.inc
;
; Other information:
;
; Changes in program: (Description and date)
;
;<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
.include 	"m2560def.inc"
.def	Temp		= r16
.def	Data		= r17
.def	RS			= r18
.def	charCounter	= r19
.def	startLine	= r20


.equ	BITMODE4		= 0b00000010		; 4-bit operation
.equ	CLEAR			= 0b00000001			; Clear display
.equ	RETURN_HOME		= 0b00000010			; Return home
.equ	DISPCTRL		= 0b00001111		; Display on, cursor on, blink on.
.equ	NULL			= 0x00
.equ	DELAY			= 4882				;Counter ticks, translates to 5000 ms
.equ	LINE_LENGTH		= 40
.equ	TEXT_LENGTH		= 160

.org 0x200
text_1:
.db "                                        "
text_2:
.db "                                        "
text_3:
.db "                                        "
text_4: 
.db "                                        "

.dseg
.org 0x200
line_1:
.BYTE 40
line_2:
.BYTE 40
line_3:
.BYTE 40
line_4:
.BYTE 40

.cseg
.org	0x0000				; Reset vector
	rjmp reset
.org URXC1addr
	rjmp Get_Char_FromUSART
.org OC1Aaddr
	rjmp ShiftLines

.org	0x0072

reset:	

	ldi Temp, HIGH(RAMEND)	; Temp = high byte of ramend address
	out SPH, Temp			; sph = Temp
	ldi Temp, LOW(RAMEND)	; Temp = low byte of ramend address
	out SPL, Temp			; spl = Temp

	ser Temp				; r16 = 0b11111111
	out DDRE, Temp			; port E = outputs ( Display JHD202A)
	clr Temp				; r16 = 0
	out PORTE, Temp	

	ldi Temp, HIGH(DELAY)	; Initiate Timer Counter with delay 5000 ms
	sts OCR1AH,Temp
	ldi Temp, LOW(DELAY)	
	sts OCR1AL,Temp

	ldi Temp, (1<<OCIE1A)	;Enable interrupt mask bit, MAtch interrupt enable
	sts TIMSK1,Temp

	ldi Temp,(1 << CS12)+(1 << CS10)+(1 << WGM12)	; Set prescaler value to 1024 ,set flag Clear timer on compare match
	sts TCCR1B, Temp



	ldi XH,	HIGH(SRAM_START)				; Configure X pointer register for writing to SRAM
	ldi XL, LOW(SRAM_START)

			
	ldi YH,HIGH(SRAM_START)			; Configure Y pointer register for reading from SRAM
	ldi YL, LOW(SRAM_START)

	ldi ZH,HIGH(text_1*2)			; Configure Z pointer register for reading from SRAM
	ldi ZL, LOW(text_1*2)

	ldi charCounter,TEXT_LENGTH

	rcall CopyToSRAM


Usart_Init:
	ldi Temp, 23 ; Set baud 4800 under clk 1.8432 MHz
	sts UBRR1L,Temp
	;Set unable receive transmit flags
	ldi Temp,(1 << RXCIE1)+(1<<RXEN1) + (1<<TXEN1)
	sts UCSR1B,Temp

	; Set frame format: 8data, 1stop bit
	ldi r16, (0<<UMSEL10)|(3<<UCSZ10)
	sts UCSR1C,r16
	

	rcall init_disp


	ldi charCounter,0x00
	ldi startLine,0x00
	
	sei


loop:	nop
	rjmp loop			; loop forever

; **
; ** init_display
; **
init_disp:	
	rcall power_up_wait		; wait for display to power up

	ldi Data, BITMODE4		; 4-bit operation
	rcall write_nibble		; (in 8-bit mode)
	rcall short_wait		; wait min. 39 us
	ldi Data, DISPCTRL		; disp. on, blink on, curs. On
	rcall write_cmd			; send command
	rcall short_wait		; wait min. 39 us
clr_disp:	
	ldi Data, CLEAR			; clr display
	rcall write_cmd			; send command
	rcall long_wait			; wait min. 1.53 ms
	ret

; **
; ** write char/command
; **

write_char:		
	ldi RS, 0b00100000		; RS = high
	rjmp write
write_cmd: 	
	clr RS					; RS = low
write:	
	mov Temp, Data			; copy Data
	andi Data, 0b11110000	; mask out high nibble
	swap Data				; swap nibbles
	or Data, RS				; add register select
	rcall write_nibble		; send high nibble
	mov Data, Temp			; restore Data
	andi Data, 0b00001111	; mask out low nibble
	or Data, RS				; add register select

write_nibble:
	rcall switch_output		; Modify for display JHD202A, port E
	nop						; wait 542nS
	sbi PORTE, 5			; enable high, JHD202A
	nop
	nop						; wait 542nS
	cbi PORTE, 5			; enable low, JHD202A
	nop
	nop						; wait 542nS
	ret

; **
; ** busy_wait loop
; **
short_wait:	
	clr zh					; approx 50 us
	ldi zl, 30
	rjmp wait_loop
long_wait:	
	ldi zh, HIGH(1000)		; approx 2 ms
	ldi zl, LOW(1000)
	rjmp wait_loop
dbnc_wait:	
	ldi zh, HIGH(4600)		; approx 10 ms
	ldi zl, LOW(4600)
	rjmp wait_loop
power_up_wait:
	ldi zh, HIGH(9000)		; approx 20 ms
	ldi zl, LOW(9000)

wait_loop:	
	sbiw z, 1				; 2 cycles
	brne wait_loop			; 2 cycles
	ret

; **
; ** modify output signal to fit LCD JHD202A, connected to port E
; **

switch_output:
	push Temp
	clr Temp
	sbrc Data, 0				; D4 = 1?
	ori Temp, 0b00000100		; Set pin 2 
	sbrc Data, 1				; D5 = 1?
	ori Temp, 0b00001000		; Set pin 3 
	sbrc Data, 2				; D6 = 1?
	ori Temp, 0b00000001		; Set pin 0 
	sbrc Data, 3				; D7 = 1?
	ori Temp, 0b00000010		; Set pin 1 
	sbrc Data, 4				; E = 1?
	ori Temp, 0b00100000		; Set pin 5 
	sbrc Data, 5				; RS = 1?
	ori Temp, 0b10000000		; Set pin 7 (wrong in previous version)
	out porte, Temp
	pop Temp
	ret



Get_Char_FromUSART:
	lds Data,UDR1
	rcall SendEchoUSART			;Send echo
	rcall write_char_to_SRAM
	reti

SendEchoUSART:
	push Temp
	; Wait for empty transmit buffer
	wait_for_empty_transmitter_buffer:
	lds Temp, UCSR1A
	sbrs Temp, UDRE1
	rjmp wait_for_empty_transmitter_buffer
	; Put Data into buffer, sends the data
	cpi Data,0x0D
	brne not_cr			;If received character is carriage return,
		ldi Temp,0x0A	;Send echo carriage return and new line
		sts UDR1,Temp
			; Wait for empty transmit buffer
			wait_for_empty_transmitter_buffer1:
			lds Temp, UCSR1A
			sbrs Temp, UDRE1
			rjmp wait_for_empty_transmitter_buffer1
		ldi Temp,0x0D
		sts UDR1,Temp
		pop Temp
		ret
	not_cr:
		sts UDR1,Data
		pop Temp
		ret
	
write_char_to_SRAM:
	cpi charCounter,TEXT_LENGTH			;Limits number of characters that can be written
	brlo store_char						; to SRAM to 160, that is 4 lines 40 chars
	ret
	store_char:
	cpi Data,0x0D
	breq new_line						; if Received char is a carriage return start new line
	st X+,Data	
	ret
	new_line:							; Check the current value of a pointer
	cpi XL,LINE_LENGTH*1
	brlo second_line					;Then change pointer to start of the following line
										;When passing forth line charCounter reset to 0 and
	cpi XL,LINE_LENGTH*2				; the X pointer is pointing to first line
	brlo third_line

	cpi XL,LINE_LENGTH*3				
	brlo forth_line
	ret

	ldi charCounter,0x00
	ldi XL,LINE_LENGTH*0
	ret

	second_line:
	ldi XL,LINE_LENGTH*1
	ret
	third_line:
	ldi XL,LINE_LENGTH*2
	ret
	forth_line:
	ldi XL,LINE_LENGTH*3
	ret

ShiftLines:
	push r21
	rcall setNextYStartPosition				;Counts current line start and 
											;set Y pointer to that line
	push startLine

	rcall write_line
	rcall setNextYStartPosition	
	rcall write_line


	pop startLine
	pop r21
	reti

write_line:							;write characters to LCD
	push r21
	push r22
	push Data
	
	ldi r21,LINE_LENGTH				;LINE_LENGTH - number of characters to write
	char_loop:
		ld Data,Y+
		rcall write_char
		dec r21
		brne char_loop
	
	pop Data
	pop r22
	pop r21
	ret



setNextYStartPosition:				;set pointer Y to next line
	cpi startLine,0x04				;Use starLine as index, the resulting index increased
	brge resetStartLine				
	cpi startLine,0x03
	breq startFromForthLine
	cpi startLine,0x02
	breq startFromThirdLine
	cpi startLine,0x01
	breq startFromSecondLine
	cpi startLine,0x00
	breq startFromFirstLine


	startFromFirstLine:
	inc startLine
	ldi YH,HIGH(line_1)
	ldi YL,LOW(line_1)
	ret
	
	startFromSecondLine:
	inc startLine
	ldi YH,HIGH(line_2)
	ldi YL,LOW(line_2)
	ret

	startFromThirdLine:
	inc startLine
	ldi YH,HIGH(line_3)
	ldi YL,LOW(line_3)
	ret

	startFromForthLine:
	inc startLine
	ldi YH,HIGH(line_4)
	ldi YL,LOW(line_4)
	ret

	resetStartLine:
	ldi startLine,0x01
	ldi YH,HIGH(line_1)
	ldi YL,LOW(line_1)
	ret

CopyToSRAM:						; Intiate text in SRAM for pritintg
	lpm Temp,Z+					; initial is space characters
	st Y+,Temp
	dec charCounter
	brne CopyToSRAM
	ret
	


