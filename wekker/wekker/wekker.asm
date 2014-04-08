	.include "m32def.inc"

	; Define some constants
	.equ increment = 0b11111110
	.equ continue = 0b11111101
	.equ button = PINA			; Define the input buttons

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

	.def hud = R16 ; Register to save the HUD information
	.def tmp = R17 ; Register for temporary values
	.def arg = R18 ; Register for arguments for other subroutines
	.def mode = R19 ; Register to check which mode to use in the timer interrupt (flicker, or increment)
					; 0th bit will determine flickering in general 
					; (if zero, nothing flickers, if one, flickering is possible)
					; 1th bit will determine flickering of the alarm
					; 2th bit will determine flickering of the seconds
					; 3th bit will determine flickering of the minutes
					; 4th bit will determine flickering of the hours
	.def interrupt_counter = R20 ; A counter to increment every interrupt. If 1, increment time and clear it.

	RJMP init
	
	.org OC1Aaddr
	RJMP TIMER_INTERRUPT ; adres ISR (Timer1 output Compare Match)		

init:
	; init stackpointer
	LDI tmp, LOW(RAMEND)
 	OUT SPL, tmp
 	LDI tmp, HIGH(RAMEND)
 	OUT SPH, tmp

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
	CLR interrupt_counter

	RCALL INIT_RS232 ; Initialize the connection with the PC
	RCALL INIT_BUTTONS ; Initialize the buttons
	; Clear the display
	LDI arg, 0x80
	RCALL send_byte

	LDI hud, 0b00000110
	LDI mode, 0

	; Show the time (zero everything)
	RCALL send_time
	RCALL INIT_TIMER ; Initialize the timer interrupt

main:
	RJMP main


; Subroutine used to let the user set the time
SET_TIME:

	RET

send_time:
	; Prepare the hour_ten
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, hour_ten ; Grab it from the program memory using Z
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte
	; Prepare the hour_one
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, hour_one ; Grab it from the program memory using Z
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte
	; Prepare the minute_ten
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, minute_ten ; Grab it from the program memory using Z
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte
	; Prepare the minute_one
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, minute_one ; Grab it from the program memory using Z
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte
	; Prepare the second_ten
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, second_ten ; Grab it from the program memory using Z
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte
	; Prepare the second_one
	LDI ZL, low(numbers*2)
	LDI ZH, high(numbers*2)
	MOV tmp, second_one ; Grab it from the program memory using Z
	ADD ZL, tmp
	LPM arg, Z
	RCALL send_byte
	; Prepare the HUD information
	MOV arg, hud		; Send information
	RCALL send_byte
	RET


; Subroutine to send one byte
send_byte:	
	OUT UDR, arg ; Sent the byte saved in the register arg
	; Wait until it is confirmed that the byte has been send.
	waiting_loop:
	SBIS UCSRA, UDRE
	RJMP waiting_loop
	RET ; Return from this subroutine

; Subroutine. Will increment the counters and use the send_time subroutine to update
; the emulated display
INCREMENT_TIME:
INC second_one ; A second has passed
	CP second_one, ten_compare
	BRNE END_OF_INCREMENT ; If seconds_one has not reached ten, go to the end.
	CLR second_one	; Set second_one to zero again
	INC second_ten ; Ten seconds have passed
	CP second_ten, six_compare
	BRNE END_OF_INCREMENT ; If seconds_ten has not reached six, go to the end.
	CLR second_ten	; Set second_ten to zero again
	INC minute_one ; A minute has passed
	CP minute_one, ten_compare
	BRNE END_OF_INCREMENT ; If minutes_one has not reached ten, go to the end.
	CLR minute_one	; Set minute_one to zero again
	INC minute_ten ; Ten minutes have passed
	CP minute_ten, six_compare
	BRNE END_OF_INCREMENT ; If minutes_ten has not reached 
	CLR minute_ten	; Set minute_ten to zero again
	INC hour_one ; An hour has passed
	CP hour_one, ten_compare 
	BRNE END_OF_DAY_TEST ; If hours have not reached ten, test whether the end of day has been reached
	CLR hour_one	; Set hour_one to zero again
	INC hour_ten	; Ten hours have passed
	RJMP END_OF_INCREMENT	; End

	; Check whether 24 hours has been reached
	END_OF_DAY_TEST:
	CP hour_one, four_compare ; Check whether hour_one is four
	BRNE END_OF_INCREMENT ; If no, 24 has certainly not been reached, go to the end
	CP hour_ten, two_compare ; If gotten here, hour_one is four. Check if hour_ten is two
	BRNE END_OF_INCREMENT ; If hour_ten is not two, 24 has not been reached
	CLR hour_one ; 24 has been reached. Clear hour_ten and hour_one
	CLR hour_ten

	; Jump here to end the interrupt when needed
	END_OF_INCREMENT:
	RCALL send_time
	RET

; ISR for the timer. 
TIMER_INTERRUPT:
	
	SBRC mode, 1
	RJMP END_OF_TIMER_INTERRUPT

	;TRY_TO_INCREMENT:
	INC interrupt_counter
	CPI interrupt_counter, 2
	BRNE END_OF_TIMER_INTERRUPT
	CLR interrupt_counter
	RCALL INCREMENT_TIME

	END_OF_TIMER_INTERRUPT:
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
	LDI tmp, high(21600)
	OUT OCR1AH, tmp
	LDI tmp, low(21600)
	OUT OCR1AL, tmp
	; zet prescaler op 256 & zet timer in CTC - mode
	LDI tmp, (1 << CS12) | (1 << WGM12)
	OUT TCCR1B, tmp
	LDI tmp, (1 << OCIE1A)
	OUT TIMSK, tmp
	SEI ; enable alle interrupts
	RET

; Subroutine to initalize the buttons.
INIT_BUTTONS:
	LDI tmp, 0b11111100 ; Only SW0 and SW1 are accepted as input
	OUT DDRA, tmp
	RET


; These are the bytes needed to show a certain number on the display. These numbers are shown below.
; In order to grab these bytes, use numbers as the adres for Z, + the number you need.
numbers:
	.db 0b01110111, 0b00100100, 0b01011101, 0b01101101, 0b00101110, 0b01101011, 0b01111011, 0b00100101, 0b01111111, 0b01101111
;		0			1			2			3			4			5			6			7			8			9
