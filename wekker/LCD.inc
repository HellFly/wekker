.equ LCD_RS = 3
	.equ LCD_E = 2

	.equ LCD = PORTD
	.equ DDR_LCD = DDRD
	
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