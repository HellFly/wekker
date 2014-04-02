	.include "m32def.inc"

	.def tmp = R16

	.equ led = PORTB			; Define the output LEDS
	.equ led_setup = DDRB

	.equ button = PINA			; Define the input buttons
	.equ button_setup = DDRA

	RJMP init

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


loop:
	
	RJMP loop