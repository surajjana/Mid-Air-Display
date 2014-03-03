	list p=pic16f84
	__CONFIG   _CP_OFF & _WDT_OFF & _PWRTE_ON & _HS_OSC
	include <p16f84.inc>
	include	<data.inc>



; RAM valtozok	
w_temp			EQU     0x0C    ; variable used for context saving 
status_temp		EQU     0x0D    ; variable used for context saving
led_mask		EQU	0x0E	; bitN=1 -> ledN on	
time_counter	EQU	0x0F	; cycle variable
time_counter1	EQU	0x10	; cycle variable
time_counter2	EQU	0x11	; cycle variable
column			EQU	0x12	; actual column number
column_it		EQU	0x13	; actual column number in IT
begin_column	EQU	0x14	; kezdõoszlop
rotate_time		EQU 0x15	; last measured rotation time
rotate_time_counter		EQU 0x16	; rotation time conter
dark_time		EQU 0x17	; ON pixel begin-end off time
light_time		EQU 0x18	; ON pixel on time
state_flags		EQU 0x19	; bit0 = display database must be called
time_counter3	EQU	0x1A	; cycle variable

; Konstansok
	; pixel counter loop start value (D155 = 125us)
	; 1 pixel = DARK + LIGHT + DARK
	constant		DARK_TIME			= D'250'	; ON pixel begin-end off time
	constant		LIGHT_TIME			= D'183'	; ON pixel on time
	; column number-1
	constant        NUM_COLUMNS_DATA 	= D'250'	
	constant        NUM_COLUMNS_DISP 	= D'100'	
	constant		EXTRA_DATA			= D'150'	; =NUM_COLUMNS_DATA-NUM_COLUMNS_DISP
	constant		TIMER_START_VALUE	= D'218'	; 218 = 39
	constant		ROTATE_TIME_LIMIT	= D'250'	; overflow limit for rotate time counter
	;flags
	constant		DISPALY_DATABASE_CALL = d'0'	; display database must be called
	constant		NO_DISPLAY			 = d'1'	; too slow to display


; forditas vezerlok
	#define	SLIDING	



; program **************************************************************
	ORG     0x000             ; processor reset vector
	goto    main              ; go to beginning of program

; IT routine ***********************************************************
; context save
	ORG     0x004             ; interrupt vector location
	movwf   w_temp            ; save off current W register contents
	movf	STATUS,w          ; move status register into W register
	movwf	status_temp       ; save off contents of STATUS register


; PB0 IT ******************
pb0_it
	btfss	INTCON,INTF
	goto	timer_it		; no , go and decide if timer it
							; yes
	
	bsf	state_flags,DISPALY_DATABASE_CALL

	bcf		INTCON,INTF	; clear flag

; timer IT ******************
timer_it
	btfss	INTCON,T0IF
	goto	it_routine_end		; no go out of it routines
								; yes
; reset timer and rotate time measure counter
	incf	rotate_time_counter,1	; increment rotate time counter

	bcf		INTCON,T0IE				; disable timer it
	movlw	TIMER_START_VALUE		; reload timer
	movwf	TMR0
	bcf		INTCON,T0IF				; clear timer it flag
	bsf		INTCON,T0IE				; enable timer it

; disable display if counter =250
	movf	rotate_time_counter,0
	addlw	D'87'
	;movlw	ROTATE_TIME_LIMIT
	;subwf	rotate_time_counter,0
	btfsc	STATUS,Z				; 0? overflow?
	bsf		state_flags,NO_DISPLAY	;yes
									;no

; context reload ******************
it_routine_end
	movf    status_temp,w     ; retrieve copy of STATUS register
	movwf	STATUS            ; restore pre-isr STATUS register contents
	swapf   w_temp,f
	swapf   w_temp,w          ; restore pre-isr W register contents
	retfie                    ; return from interrupt

; ***********************************************************************

main
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms
	call delay_50ms


; Inicializalas ******************************************************
; port A inicializalas
	clrf	PORTA
	bsf	STATUS,RP0	; B1
	movlw	b'11111100'	; A4 in, A3 in, A2 in, A1 out, A0 out
	movwf	TRISA


; port B inicializalas
	bcf	STATUS,RP0	; B0
	clrf	PORTB
	bsf	STATUS,RP0	; B1
	movlw	b'00000001'	; B7 out,B6 out,B5 out,B4 out,B3 out,B2 out,B1 out,B0 in, 
	movwf	TRISB
	bsf	OPTION_REG,NOT_RBPU	; B0 pull-up kikapcsolva

; interrupt inicializalas
	movlw	b'10010000'	; INTE enabled, all flags cleared
	movwf	INTCON
	bcf	OPTION_REG,INTEDG	; PB0/INT: IT on falling edge

; timer0 inicializalas
; prescaler from wdt to timer0
	clrwdt				; clear wdt
	bsf	STATUS,RP0		; B1
	bcf	OPTION_REG,T0CS		; timer0 input = instruction clock
	bcf	OPTION_REG,PSA		; prescaler to timer
	bsf	OPTION_REG,PS2		; prescaler = 128
	bsf	OPTION_REG,PS1		; prescaler = 128
	bcf	OPTION_REG,PS0		; prescaler = 128
	
	bcf	STATUS,RP0	; B0

	bcf		INTCON,T0IE				; disable timer it

; valtozok inicializalasa
	movlw	NUM_COLUMNS_DATA
	movwf	column		; next column = 0

	call	led_power_off	; turn off all leds

	movlw	NUM_COLUMNS_DATA		; init begin column
	movwf	begin_column	;  


; idle *****************************************************
idle

	btfsc	state_flags,DISPALY_DATABASE_CALL
	call	display_database

	goto	idle


; ************** szubrutinok *********************

; next_colum *************************************
; return with led mask set
next_colum
column_loop
	movlw	HIGH led_table	; table page adress
	movwf	PCLATH
	movf	column,0	; move column number to w
	call 	led_table	; puts led mask to w
	movwf	led_mask	; refresh led mask

	btfss	PORTA,4				; static?
	goto	static				; yes
	goto	moving				; no
static
	decf	column,1
	movlw	EXTRA_DATA
	subwf	column,0
	goto	common
moving
	decf	column,1
common
	btfss	STATUS,Z	; zero?
	return				; no
						; yes	
	movlw	NUM_COLUMNS_DATA	
	movwf	column		; next column = 0
	return			




; set_leds *************************************
set_leds
	
set_led7 				; (top)	
	btfss	led_mask,7
	goto	led7_off
	goto	led7_on
led7_off	
	bsf	PORTA,0
	goto set_led6
led7_on
	bcf	PORTA,0

set_led6
	btfss	led_mask,6
	goto	led6_off
	goto	led6_on
led6_off	
	bsf	PORTB,7
	goto set_led5
led6_on
	bcf	PORTB,7

set_led5
	btfss	led_mask,5
	goto	led5_off
	goto	led5_on
led5_off	
	bsf	PORTB,6
	goto set_led4
led5_on
	bcf	PORTB,6

set_led4
	btfss	led_mask,4
	goto	led4_off
	goto	led4_on
led4_off	
	bsf	PORTB,5
	goto set_led3
led4_on
	bcf	PORTB,5

set_led3
	btfss	led_mask,3
	goto	led3_off
	goto	led3_on
led3_off	
	bsf	PORTB,4
	goto set_led2
led3_on
	bcf	PORTB,4

set_led2
	btfss	led_mask,2
	goto	led2_off
	goto	led2_on
led2_off	
	bsf	PORTB,3
	goto set_led1
led2_on
	bcf	PORTB,3

set_led1
	btfss	led_mask,1
	goto	led1_off
	goto	led1_on
led1_off	
	bsf	PORTB,2
	goto set_led0
led1_on
	bcf	PORTB,2

set_led0
	btfss	led_mask,0
	goto	led0_off
	goto	led0_on
led0_off	
	bsf	PORTA,1
	goto set_led_end
led0_on
	bcf	PORTA,1

set_led_end
	return

; led_power_on *********************************
led_power_on
	bcf	PORTB,1
	return

; led_power_off *********************************
led_power_off
	bsf	PORTB,1
	return

; delay_dark_time ************************************
delay_dark_time
	;movf	DARK_TIME,0
	movlw	DARK_TIME
	movwf	time_counter
loop01
	decf	time_counter,1
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	btfss	STATUS,Z	; zero?
	goto	loop01		; no
	return			; yes

; delay_light_time ************************************
delay_light_time
	;movf	light_time,0
	movlw	LIGHT_TIME
	movwf	time_counter
loop04
	decf	time_counter,1
	nop
	nop
	nop
	nop
	nop
	nop
	nop

	btfss	STATUS,Z	; zero?
	goto	loop04		; no
	return			; yes




; delay_50ms ************************************
delay_50ms


	movlw	D'243'
	movwf	time_counter2
loop03



	movlw	D'255'
	movwf	time_counter1
loop02
	decf	time_counter1,1

	btfss	STATUS,Z	; zero?
	goto	loop02		; no
				; yes



	decf	time_counter2,1

	btfss	STATUS,Z	; zero?
	goto	loop03		; no
				; yes


	return

; delay_45deg ************************************
delay_45deg



	movlw	D'3'
	movwf	time_counter3
loop07



	;movf	light_time,0
	movlw	D'150'
	movwf	time_counter2
loop05



	movlw	D'250'
	movwf	time_counter1
loop06
	decf	time_counter1,1

	btfss	STATUS,Z	; zero?
	goto	loop06		; no
				; yes



	decf	time_counter2,1

	btfss	STATUS,Z	; zero?
	goto	loop05		; no
				; yes


	decf	time_counter3,1

	btfss	STATUS,Z	; zero?
	goto	loop07		; no
				; yes

	return

; display database ************************************
display_database

; clear flag rb0it
	bcf	state_flags,DISPALY_DATABASE_CALL


; reset timer and rotate time measure counter
	movf	rotate_time_counter,0	; rotate time counter -> w
	movwf	rotate_time				; store last rotation time
	clrf	rotate_time_counter		; clear rotate time counter

	movf	rotate_time,0			; rotate time -> w
	movwf	light_time				; refresh light time
	movwf	dark_time				; dark time same as light time
	bcf		STATUS,C				; clear carry flag
	rrf		dark_time,1				; dark time /=2
	addwf	dark_time,1				; w+dark_time/2 -> dark time

	bcf		INTCON,T0IE				; disable timer it
	movlw	TIMER_START_VALUE		; reload timer
	movwf	TMR0
	bcf		INTCON,T0IF				; clear timer it flag
	bsf		INTCON,T0IE				; enable timer it

; display disabled by counter overflow?
	btfss	state_flags,NO_DISPLAY	; overflow?
	goto	no_overflow				; no
	bcf		state_flags,NO_DISPLAY	; yes, clear overflow flag
	return							
no_overflow
; wait about 45 degrees = 3.74ms
	call	delay_45deg

; static picture?
;	btfss	PORTA,4				; static?
;	goto	skip				; yes
								; no
; begin column belemegy a columnba és eggyel csökken. 
; Ha 0, akkor NUM_COLUMNS_DATAra inicializálódik
;	movf	begin_column,0	; begin_column -> w
;	movwf	column
;	decf	begin_column,1
;	btfss	STATUS,Z			; 0?
;	goto	skip				; no	
;	movlw	NUM_COLUMNS_DATA	; yes
;	movwf	begin_column	 
skip	




	movlw	NUM_COLUMNS_DISP	; init loop variable
	movwf	column_it	 
column_it_loop
	
	call	next_colum
	call	set_leds
	call	delay_dark_time
	call	led_power_on
	call	delay_light_time
	call	led_power_off
	call	delay_dark_time


	decf	column_it,1
	btfss	STATUS,Z	; zero?
	goto column_it_loop	; no
						; yes


	return


	end
