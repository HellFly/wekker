	.include "m32def.inc"

	; Registers for the counters
	.def hour_ten = R2
	.def hour_one = R3
	.def minute_ten = R4
	.def minute_one = R5
	.def second_ten = R6
	.def second_one = R7

	.def tmp = R16
	.def arg = R17
	.def counter1 = r18
	.def counter2 = r19

	.equ LCD_RS = 3
	.equ LCD_E = 2

	.equ LCD = PORTD
	.equ DDR_LCD = DDRD

	.equ led = PORTB			; Define the output LEDS
	.equ led_setup = DDRB

	.equ button = PINA			; Define the input buttons
	.equ button_setup = DDRA

	RJMP init
	
	.org OC1Aaddr
	rjmp TIMER_INTERRUPT ; adres ISR (Timer1 Output Compare Match)		

init:
	; init stackpointer
	LDI tmp, LOW(RAMEND)
 	OUT SPL, tmp
 	LDI tmp, HIGH(RAMEND)
 	OUT SPH, tmp

	LDI tmp, 0xFF				; Define the value for the output
	OUT led_setup, tmp			; Define the LEDs as output
	LDI tmp, 0xFF
	OUT led, tmp

	LDI tmp, 0x00				; Define the value for the output
	OUT button_setup, tmp		; Define the buttons as input

	RCALL INIT_RS232 ; Initialize the connection with the PC
	RCALL INIT_TIMER ; Initialize the timer interrupt
	RCALL init_lcd

	RJMP main

main:
	
	RJMP main

TIMER_INTERRUPT:
	
	RETI

; Initialize the connection with the PC
INIT_RS232:
	; set the baud rate, see datahseet p.167
	; F_OSC = 11.0592 MHz & baud rate = 19200
	; to do a 16-bit write, the high byte must be written before the low byte !
	; for a 16-bit read, the low byte must be read before the high byte !
	ldi tmp, high(35)
	out UBRRH, tmp
	ldi tmp, low(35) ; 19200 baud
	out UBRRL, tmp

	; set frame format : asynchronous, parity disabled, 8 data bits, 1 stop bit
	ldi tmp, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0)
	out UCSRC, tmp
	; enable receiver & transmitter
	ldi tmp, (1 << RXEN) | (1 << TXEN)
	out UCSRB, tmp
	RET

; Initialize the timer
INIT_TIMER:
	; init Output Compare Register
	; f kristal = 11059200 en 1 sec = (256/11059200) * 43200
	; to do a 16 - bit write, the high byte must be written before the low byte !
	; for a 16 - bit read, the low byte must be read before the high byte !
	; (p 89 datasheet)
	ldi tmp, high(43200)
	out OCR1AH, tmp
	ldi tmp, low(43200)
	out OCR1AL, tmp
	; zet prescaler op 256 & zet timer in CTC - mode
	ldi tmp, (1 << CS12) | (1 << WGM12)
	out TCCR1B, tmp
	; enable interrupt
	ldi tmp, (1 << OCIE1A)
	out TIMSK, tmp
	sei ; enable alle interrupts
	RET

//LCD stuff
init_lcd:
	rcall init_4bitmode
	ldi arg, 0x28		; 0010 1000 2 lines, 5x8 font, 4-bit mode see p 24/25 datasheet
	rcall send_ins
	ldi arg, 0x0E		; 0000 1110 display on, cursor on, no blinking see p 24/25 datasheet
	rcall send_ins
	ldi arg, 0x01		; 0000 0001 clear display, set cursor home, adres counter = 0
	rcall send_ins
	ldi arg, 0x06		; 0000 0110 auto-increment cursor
	rcall send_ins
	ret

init_4bitmode:
	ldi arg, 0x30
	rcall clock_in
	rcall delay_some_ms
	ldi arg, 0x30
	rcall clock_in
	rcall delay_some_ms
	ldi arg, 0x30
	rcall clock_in
	rcall delay_some_ms
	ldi arg, 0x20
	rcall clock_in
	rcall delay_some_ms
	ret

send_ins:
	push arg
	; first 4 higher bits
	andi arg, 0xf0
	rcall clock_in
	; then 4 lower bits
	pop arg
	swap arg
	andi arg, 0xf0
	rcall clock_in
	rcall delay_some_ms
	ret

send_str:
	LPM arg, Z+
	CPI arg, 0xFF
	BREQ send_str_end
	RCALL show_char
	RJMP send_str
	send_str_end:
		RET

show_char:
	push arg
	; first 4 higher bits
	andi arg, 0xf0
	ORI arg, 0b00001000	; Set the RS bit high
	rcall clock_in
	; then 4 lower bits
	pop arg
	swap arg
	andi arg, 0xf0
	ORI arg, 0b00001000	; Set the RS bit high
	rcall clock_in
	rcall delay_some_ms
	ret

clock_in:
	OUT LCD, arg
	ORI arg, 0b00000100
	out LCD, arg
	ANDI arg, 0b11111011
	out LCD, arg
	rcall delay_some_ms
	ret

; 65000 steps & CPU 11 Mhz gives delay of appr. 6 ms
delay_some_ms:
	ldi counter1, 12
delay_1:
	clr counter2
delay_2:
	dec counter2
	brne delay_2
	dec counter1
	brne delay_1
	ret

