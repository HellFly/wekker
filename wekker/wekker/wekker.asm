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

	.def test_counter = R20

	.def tmp = R16
	.def arg = R17
	.def counter1 = r18
	.def counter2 = r19

	.equ button = PINA			; Define the input buttons
	.equ button_setup = DDRA

	RJMP init
	
	.org OC1Aaddr
	RJMP TIMER_INTERRUPT ; adres ISR (Timer1 output Compare Match)		

init:
	; init stackpointer
	LDI tmp, LOW(RAMEND)
 	OUT SPL, tmp
 	LDI tmp, HIGH(RAMEND)
 	OUT SPH, tmp

	LDI tmp, 0x00				; Define the value for the output
	OUT button_setup, tmp		; Define the buttons as input

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

	RCALL INIT_RS232 ; Initialize the connection with the PC

	; Clear the display
	LDI arg, 0x80
	RCALL send_byte

	; Show the time (zero everything)
	RCALL send_time
	RCALL INIT_TIMER ; Initialize the timer interrupt

main:
	RJMP main


send_time:
	
	; Prepare the hour_ten
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, hour_ten
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte
	; Prepare the hour_one
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, hour_one
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte
	; Prepare the minute_ten
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, minute_ten
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte
	; Prepare the minute_one
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, minute_one
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte
	; Prepare the second_ten
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, second_ten
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte
	; Prepare the second_one
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, second_one
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte
	; Prepare the HUD information
	LDI arg, 0b00000110		; Only the last colon is on
	RCALL send_byte
	
	RET


; Subroutine to send one byte
send_byte:	
	OUT UDR, arg ; Sent the byte saved in the register arg
	RCALL delay_some_ms	; Have a short delay
	RET ; RETurn from this subroutine

; ISR for the timer. Will increment the counters and use the send_time subroutine to update
; the emulated display
TIMER_INTERRUPT:
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


; Initialization subroutines

; Initialize the connection with the PC
INIT_RS232:
	; set the baud rate, see datahseet p.167
	; F_OSC = 11.0592 MHz & baud rate = 19200
	; to do a 16-bit write, the high byte must be written before the low byte !
	; for a 16-bit read, the low byte must be read before the high byte !
	LDI tmp, high(35)
	OUT UBRRH, tmp
	LDI tmp, low(35) ; 19200 baud
	OUT UBRRL, tmp

	; set frame format : asynchronous, parity disabled, 8 data bits, 1 stop bit
	LDI tmp, (1<<URSEL)|(1<<UCSZ1)|(1<<UCSZ0)
	OUT UCSRC, tmp
	; enable receiver & transmitter
	LDI tmp, (1 << RXEN) | (1 << TXEN)
	OUT UCSRB, tmp
	RET


; Initialize the timer
INIT_TIMER:
	; init output Compare Register
	; f kristal = 11059200 en 1 sec = (256/11059200) * 43200
	; to do a 16 - bit write, the high byte must be written before the low byte !
	; for a 16 - bit read, the low byte must be read before the high byte !
	; (p 89 datasheet)
	LDI tmp, high(43200)
	OUT OCR1AH, tmp
	LDI tmp, low(43200)
	OUT OCR1AL, tmp
	; zet prescaler op 256 & zet timer in CTC - mode
	LDI tmp, (1 << CS12) | (1 << WGM12)
	OUT TCCR1B, tmp
	LDI tmp, (1 << OCIE1A)
	OUT TIMSK, tmp
	SEI ; enable alle interrupts
	RET


; A short delay
delay_some_ms:
	LDI counter1, 12
delay_1:
	CLR counter2
delay_2:
	DEC counter2
	BRNE delay_2
	DEC counter1
	BRNE delay_1
	RET


; These are the bytes needed to show a certain number on the display. These numbers are shown below.
; In order to grab these bytes, use numbers as the adres for Z, + the number you need.
numbers:
	.db 0b01110111, 0b00100100, 0b01011101, 0b01101101, 0b00101110, 0b01101011, 0b01111011, 0b00100101, 0b01111111, 0b01101111
;		0			1			2			3			4			5			6			7			8			9
