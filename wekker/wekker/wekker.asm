	.include "m32def.inc"

	; Registers for the counters for the time
	.def hour_ten = R2
	.def hour_one = R3
	.def minute_ten = R4
	.def minute_one = R5
	.def second_ten = R6
	.def second_one = R7
	; Registers for the counters for the alarm
	.def alarm_hour_ten = R8
	.def alarm_hour_one = R9
	.def alarm_minute_ten = R10
	.def alarm_minute_one = R11
	; Register to use for comparing
	.def ten_compare = R12
	.def six_compare = R13
	.def two_compare = R14
	.def four_compare = R15

	.def tmp = R16
	.def arg = R17
	.def counter1 = r18
	.def counter2 = r19

	.equ button = PINA			; Define the input buttons
	.equ button_setup = DDRA

	RJMP init
	
	.org OC1Aaddr
	RJMP TIMER_INTERRUPT ; adres ISR (Timer1 Output Compare Match)		

init:
	; init stackpointer
	LDI tmp, LOW(RAMEND)
 	OUT SPL, tmp
 	LDI tmp, HIGH(RAMEND)
 	OUT SPH, tmp

	LDI tmp, 0x00				; Define the value for the output
	OUT button_setup, tmp		; Define the buttons as input

	RCALL INIT_RS232 ; Initialize the connection with the PC
	RCALL INIT_TIMER ; Initialize the timer interrupt

	; Initialize the compare registers
	LDI tmp, 10
	MOV ten_compare, tmp
	LDI tmp, 6
	MOV six_compare, tmp
	LDI tmp, 2
	MOV two_compare, tmp
	LDI tmp, 4
	MOV four_compare, tmp

	; Make sure the registers are clear
	CLR second_one
	CLR second_ten
	CLR minute_one
	CLR minute_ten
	CLR hour_one
	CLR hour_ten
	CLR alarm_minute_one
	CLR alarm_minute_ten
	CLR alarm_hour_one
	CLR alarm_hour_ten

	LDI tmp, 0xFF
	OUT DDRB, tmp
	OUT PORTB, tmp

	/*LDI arg, 0x00
	RCALL send_byte
	test_loop:
	IN tmp, UDR
	CPI tmp, 0x02
	BRNE test_loop
	LDI tmp, 0x00
	OUT PORTB, tmp*/

	LDI tmp, 0x81
	OUT UDR, tmp

	RJMP main

main:
	;RCALL TIMER_INTERRUPT

	RJMP main

send_time:
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, hour_ten
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte
	
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, hour_one
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte

	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, minute_ten
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte

	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, minute_one
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte

	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, second_ten
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte

	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, second_one
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte

	LDI arg, 0b00000010		; Only the last colon is on
	RCALL send_byte

	/*wait_seven_bytes_loop:
	IN tmp, UDR
	COM R20
	OUT PORTB, R20
	CPI tmp, 0x02
	BRNE wait_seven_bytes_loop*/

	RET

send_byte:
	OUT UDR, arg
	waiting_loop:
	SBIS UCSRA, TXC
	RJMP waiting_loop
	RET

TIMER_INTERRUPT:
	MOV tmp, second_one
	COM tmp
	;OUT PORTB, tmp
	INC second_one ; A second has passed
	CP second_one, ten_compare
	BRNE END_OF_INTERRUPT
	CLR second_one	; Set second_one to zero again
	INC second_ten ; Ten seconds have passed
	CP second_ten, six_compare
	BRNE END_OF_INTERRUPT
	CLR second_ten	; Set second_ten to zero again
	INC minute_one ; A minute has passed
	CP minute_one, ten_compare
	BRNE END_OF_INTERRUPT
	CLR minute_one	; Set minute_one to zero again
	INC minute_ten ; Ten minutes have passed
	CP minute_ten, six_compare
	BRNE END_OF_INTERRUPT
	CLR minute_ten	; Set minute_ten to zero again
	INC hour_one ; An hour has passed
	; Check whether 24 hours has been reached
	CP hour_one, four_compare
	BRNE CONTINUE
	CP hour_ten, two_compare
	BREQ END_OF_DAY_REACHED
	; 24 not reached, hour_one can increase, continue
	CONTINUE:
	CP hour_one, ten_compare
	BRNE END_OF_INTERRUPT
	CLR hour_one	; Set hour_one to zero again
	INC hour_ten	; Ten hours have passed
	RJMP END_OF_INTERRUPT	; End

	; 24 hours reached, set it to zero
	END_OF_DAY_REACHED:
	CLR hour_ten
	CLR hour_one

	; Jump here to end the interrupt when needed
	END_OF_INTERRUPT:
	RCALL send_time
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
	LDI tmp, (1 << OCIE1A)
	out TIMSK, tmp
	sei ; enable alle interrupts
	RET

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

numbers:
	.db 0b01110111, 0b00100100, 0b01011101, 0b01101101, 0b00101110, 0b01101010, 0b01111011, 0b00100101, 0b01111111, 0b01101111
;		0			1			2			3			4			5			6			7			8			9
