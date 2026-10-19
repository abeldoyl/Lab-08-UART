    ; Abel Doyle
    ; RCET3375
    ; Lab8-4UART
    ; https://github.com/abeldoyl/Lab-08-UART/tree/main/Lab8-4UART/Lab8-4UART.X

; PIC16F883 Configuration Bit Settings
 
; Assembly source line config statements
 
; CONFIG1
  CONFIG  FOSC = XT             ; Oscillator Selection bits (XT oscillator: Crystal/resonator on RA6/OSC2/CLKOUT and RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF           ; Power-up Timer Enable bit (PWRT disabled)
  CONFIG  MCLRE = ON            ; RE3/MCLR pin function select bit (RE3/MCLR pin function is MCLR)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3 pin has digital I/O, HV on MCLR must be used for programming)
 
; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)
 
; config statements should precede project file includes.
#include <xc.inc>
 
; ======================================================================
; Constants
; ======================================================================
SPBRG_VAL     EQU 25          ; 4 MHz / (16 * (25 + 1)) = 9615 baud, +0.16 % error
 
CHAR_START    EQU 0x24        ; '$' start byte
CMD_ID        EQU 0x49        ; 'I' device ID command
CMD_ADC       EQU 0x41        ; 'A' ADC reading command
CMD_SERVO     EQU 0x53        ; 'S' servo compare command
CMD_ERROR     EQU 0x45        ; 'E' error response
DEVICE_ID_H   EQU 0x33        ; device ID 0x3375, high byte first
DEVICE_ID_L   EQU 0x75
 
; Servo timing (4 MHz: Timer1 ticks every 1 us)
FRAME_RELOAD_H EQU 0xB1       ; Timer1 reload 0xB1E0 = 45536 -> 20 ms to overflow
FRAME_RELOAD_L EQU 0xE0
SERVO_INIT_H  EQU 0xB7        ; initial compare 0xB7BC = 0xB1E0 + 1500 us
SERVO_INIT_L  EQU 0xBC
MATCH_MIN_H   EQU 0xB3        ; smallest accepted compare 0xB3D4 (500 us)
MATCH_MIN_L   EQU 0xD4
MATCH_MAX_H   EQU 0xBB        ; largest accepted compare 0xBBA4 (2500 us)
MATCH_MAX_L   EQU 0xA4
 
; rx_state values
WAIT_START    EQU 0
GET_COMMAND   EQU 1
GET_LENGTH    EQU 2
GET_CHANNEL   EQU 3
GET_MATCH_H   EQU 4           ; S packet: compare high byte
GET_MATCH_L   EQU 5           ; S packet: compare low byte
 
; reply_pending values (the error values must stay the largest)
REPLY_NONE    EQU 0
REPLY_ID      EQU 1
REPLY_ADC     EQU 2
REPLY_FRAMING EQU 3           ; error code byte = value - 2 -> 0x01
REPLY_OVERRUN EQU 4           ; error code byte = value - 2 -> 0x02
REPLY_RANGE   EQU 5           ; error code byte = value - 2 -> 0x03 (servo range)
 
; adc_state values
ADC_IDLE      EQU 0
ADC_BUSY      EQU 1
ADC_READY     EQU 2
 
; Bit numbers used below
BIT_C         EQU 0           ; STATUS carry
BIT_Z         EQU 2           ; STATUS zero
BIT_IRP       EQU 7           ; STATUS indirect bank select (0 = banks 0/1)
BIT_TMR1IF    EQU 0           ; PIR1  Timer1 overflow (servo frame start)
BIT_CCP1IF    EQU 2           ; PIR1  CCP1 compare match (servo pulse end)
BIT_TXIF      EQU 4           ; PIR1  TX register empty
BIT_RCIF      EQU 5           ; PIR1  RX byte waiting
BIT_OERR      EQU 1           ; RCSTA overrun error
BIT_FERR      EQU 2           ; RCSTA framing error
BIT_CREN      EQU 4           ; RCSTA continuous receive enable
BIT_GO        EQU 1           ; ADCON0 GO/DONE
BIT_GIE       EQU 7           ; INTCON global interrupt enable
DIAG_BIT      EQU 1           ; RA1 = receive-service diagnostic output
SERVO_BIT     EQU 2           ; RC2 = servo output
 
; ======================================================================
; RAM map
;   Common RAM 0x70-0x7F is reachable from every bank, so the parser,
;   reply, and ISR save registers need no bank switching.
;   Bank 0 holds the servo variables (the ISR selects Bank 0) and the
;   transmit packet. The main loop always runs with Bank 0 selected.
; ======================================================================
rx_byte       EQU 0x70        ; latest received byte
rx_state      EQU 0x71        ; WAIT_START ... GET_MATCH_L
rx_command    EQU 0x72        ; CMD_ID, CMD_ADC, or CMD_SERVO
reply_pending EQU 0x73        ; REPLY_NONE / ID / ADC / FRAMING / OVERRUN / RANGE
adc_state     EQU 0x74        ; ADC_IDLE / ADC_BUSY / ADC_READY
adc_high      EQU 0x75        ; high byte of saved 10-bit result (bits 9:8)
adc_low       EQU 0x76        ; low byte of saved 10-bit result
tx_length     EQU 0x77        ; response packet length
tx_count      EQU 0x78        ; index of next byte to send = bytes queued so far
rx_hi         EQU 0x79        ; S packet compare high byte (waiting for validation)
rx_lo         EQU 0x7A        ; S packet compare low byte (waiting for validation)
PCLATH_TEMP   EQU 0x7D        ; ISR save area
STATUS_TEMP   EQU 0x7E
W_TEMP        EQU 0x7F
 
servo_h       EQU 0x20        ; saved compare for the NEXT frame, high byte
servo_l       EQU 0x21        ; saved compare for the NEXT frame, low byte
servo_busy    EQU 0x22        ; bit 0 = 1 while the RC2 pulse is HIGH
tx_data       EQU 0x23        ; tx_data[0..5] = 0x23..0x28, consecutive bytes
 
; ======================================================================
; Vectors
; ======================================================================
PSECT resetVect,class=CODE,delta=2
ResetVector:
    goto Setup
    
PSECT isrVect,class=CODE,delta=2
InterruptVector:
    goto ISRHandler
 
PSECT code,class=CODE,delta=2
Setup:
    CLRF INTCON                 ; interrupts stay off until Setup is finished
    BCF STATUS,7          ; IRP: FSR/INDF reach banks 0/1 (tx_data is in Bank 0)
 
    BANKSEL PORTA
    CLRF PORTA                  ; RA1 diagnostic output starts LOW
    CLRF PORTC                  ; RC2 servo output starts LOW
 
    BANKSEL TRISC
    MOVLW 0xC0                  ; RC7/RX and RC6/TX = 1 for the EUSART, RC2 servo = output
    MOVWF TRISC
    BANKSEL TRISA
    BSF TRISA,0                 ; RA0/AN0 (LM34) is an input
    BCF TRISA,1                 ; RA1 diagnostic is an output
 
    BANKSEL ANSEL
    MOVLW 0x01                  ; AN0 analog, every other pin digital
    MOVWF ANSEL
    CLRF ANSELH
 
    BANKSEL BAUDCTL
    BCF BAUDCTL,3               ; 8-bit baud rate generator (BRG16 = 0)
    BANKSEL SPBRG
    MOVLW SPBRG_VAL             ; 9600 baud at 4 MHz
    MOVWF SPBRG
    BANKSEL SPBRGH
    CLRF SPBRGH                 ; unused in 8-bit mode
 
    BANKSEL TXSTA
    BCF TXSTA,4                 ; SYNC = 0: asynchronous
    BSF TXSTA,2                 ; BRGH = 1: high speed
    BCF TXSTA,6                 ; TX9 = 0: 8-bit
    BSF TXSTA,5                 ; TXEN = 1: enable transmitter
 
    BANKSEL RCSTA
    MOVLW 0x90                  ; SPEN = 1, RX9 = 0, SREN = 0, CREN = 1 (8N1 receiver on)
    MOVWF RCSTA
 
    BANKSEL ADCON1
    MOVLW 0x80                  ; ADFM = 1 right-justified, VCFG = 00 (VDD/VSS)
    MOVWF ADCON1
    BANKSEL ADCON0
    MOVLW 0x41                  ; ADCS = 01 (FOSC/8), CHS = 0000 (AN0), ADON = 1
    MOVWF ADCON0                ; (ADCON0 is in Bank 0, so we finish in Bank 0)
 
    CLRF rx_byte                ; clear parser, reply, ADC, and TX state
    CLRF rx_state               ; WAIT_START
    CLRF rx_command
    CLRF reply_pending          ; REPLY_NONE
    CLRF adc_state              ; ADC_IDLE
    CLRF adc_high
    CLRF adc_low
    CLRF rx_hi
    CLRF rx_lo
    CLRF tx_length              ; tx_count = tx_length = 0 -> nothing to send
    CLRF tx_count
    CLRF tx_data
    CLRF tx_data+1
    CLRF tx_data+2
    CLRF tx_data+3
    CLRF tx_data+4
    CLRF tx_data+5
 
    MOVLW SERVO_INIT_H          ; servo starts at 1500 us (0xB7BC)
    MOVWF servo_h
    MOVLW SERVO_INIT_L
    MOVWF servo_l
    CLRF servo_busy             ; no pulse in progress
 
    MOVLW FRAME_RELOAD_H        ; Timer1 = 0xB1E0: first overflow after 20 ms
    MOVWF TMR1H
    MOVLW FRAME_RELOAD_L
    MOVWF TMR1L
    MOVF servo_h,W              ; first compare value = 1500 us
    MOVWF CCPR1H
    MOVF servo_l,W
    MOVWF CCPR1L
    MOVLW 0x0A                  ; CCP1M = 1010: compare, interrupt only (RC2 stays GPIO)
    MOVWF CCP1CON
    BCF PIR1,0                  ; TMR1IF: start with both flags clear
    BCF PIR1,2                  ; CCP1IF
 
    BANKSEL PIE1
    MOVLW 0x05                  ; TMR1IE (bit 0) + CCP1IE (bit 2); RX/TX stay polled
    MOVWF PIE1
    BANKSEL T1CON
    MOVLW 0x01                  ; TMR1ON = 1, 1:1 prescale, Fosc/4 -> 1 us per tick
    MOVWF T1CON                 ; (T1CON is in Bank 0, so we finish in Bank 0)
 
    MOVLW 0xC0                  ; GIE = 1, PEIE = 1
    MOVWF INTCON
 
 
; ----------------------------------------------------------------------
; Each pass calls the three service routines in order:
;   1. ServiceRx    - check for a new received byte and parse it
;   2. ServiceReply - if a reply is needed, build the reply packet
;   3. ServiceTx    - send one byte of the reply packet
; (ServiceAdc is called from ServiceReply when an ADC reply is needed.)
; No routine waits, so the loop runs fast and RX is checked often.
; While the servo output is HIGH (servo_busy = 1) the loop does not
; start any service work. servo_busy is checked at the top of the loop
; and again between the service calls.
; The RA1 pulse before ServiceRx lets a scope show how often the
; receiver is checked. It stops while RC2 is HIGH.
; ----------------------------------------------------------------------
Main:
    BTFSC servo_busy,0          ; servo pulse HIGH? wait until it ends
    GOTO Main
    BSF PORTA,1          ; RA1: pulse marks one receive-service check
    NOP
    BCF PORTA,1                 ; RA1
    CALL ServiceRx
    BTFSC servo_busy,0          ; pulse started during ServiceRx?
    GOTO Main
    CALL ServiceReply
    BTFSC servo_busy,0          ; pulse started during ServiceReply?
    GOTO Main
    CALL ServiceTx
    GOTO Main
 
; ----------------------------------------------------------------------
; Checks the UART receiver once and returns.
;   - No byte waiting          -> return.
;   - Overrun error (OERR)     -> clear it, queue an overrun error reply.
;   - Framing error (FERR)     -> drop the byte, queue a framing error reply.
;   - Good byte                -> save it in rx_byte and call ParseRxByte.
; If an error reply is already waiting to be sent, new good bytes are
; thrown away so the error is not overwritten.
; ----------------------------------------------------------------------
ServiceRx:
    BTFSS PIR1,5         ; RCIF: is a received byte waiting?
    RETURN
    BTFSC RCSTA,1        ; OERR: receive overrun?
    GOTO Rx_Overrun
    BTFSC RCSTA,2        ; FERR: framing error on the waiting byte?
    GOTO Rx_Framing             ; (must be checked BEFORE reading RCREG)
 
    MOVF RCREG,W                ; read one byte
    MOVWF rx_byte
    MOVLW REPLY_FRAMING
    SUBWF reply_pending,W       ; C = 1 when reply_pending >= REPLY_FRAMING
    BTFSC STATUS,0                 ; C
    RETURN                      ; an error reply is pending: drop this byte
    CALL ParseRxByte
    RETURN
 
Rx_Overrun:                     ; branch target inside ServiceRx
Rx_Discard:
    BTFSS PIR1,5         ; RCIF: FIFO holds at most two stale bytes
    GOTO Rx_Reset
    MOVF RCREG,W                ; discard a stale byte
    GOTO Rx_Discard
Rx_Reset:
    BCF RCSTA,4          ; CREN: CREN off then on clears OERR
    BSF RCSTA,4                 ; CREN
    MOVLW REPLY_OVERRUN
    MOVWF reply_pending
    CLRF rx_state               ; WAIT_START
    RETURN
 
Rx_Framing:                     ; branch target inside ServiceRx
    MOVF RCREG,W                ; read and discard the bad byte (also clears FERR)
    MOVLW REPLY_FRAMING
    MOVWF reply_pending
    CLRF rx_state               ; WAIT_START
    RETURN
 
; ----------------------------------------------------------------------
; A state machine. It gets one byte per call (in rx_byte) and uses
; rx_state to remember where it is in the request packet:
;   WAIT_START -> GET_COMMAND -> GET_LENGTH -> GET_CHANNEL (A only)
;                                           -> GET_MATCH_H -> GET_MATCH_L (S only)
;   'I' request: '$' 'I' 0x00              -> sets reply_pending = REPLY_ID
;   'A' request: '$' 'A' 0x01 0x00         -> sets reply_pending = REPLY_ADC
;   'S' request: '$' 'S' 0x02 HIGH LOW     -> ServoUpdate (no reply if valid)
; Any unexpected byte sends the parser back to WAIT_START.
; A new reply is only requested if no other reply is already pending.
; ----------------------------------------------------------------------
ParseRxByte:
    MOVF rx_state,F             ; sets Z when rx_state = WAIT_START (0)
    BTFSC STATUS,2                 ; Z
    GOTO Parse_WaitStart
    MOVLW GET_COMMAND
    XORWF rx_state,W
    BTFSC STATUS,2                 ; Z
    GOTO Parse_GetCommand
    MOVLW GET_LENGTH
    XORWF rx_state,W
    BTFSC STATUS,2                 ; Z
    GOTO Parse_GetLength
    MOVLW GET_CHANNEL
    XORWF rx_state,W
    BTFSC STATUS,2                 ; Z
    GOTO Parse_GetChannel
    MOVLW GET_MATCH_H
    XORWF rx_state,W
    BTFSC STATUS,2                 ; Z
    GOTO Parse_GetMatchH
    MOVLW GET_MATCH_L
    XORWF rx_state,W
    BTFSC STATUS,2                 ; Z
    GOTO Parse_GetMatchL
Parse_ResetState:               ; shared path: back to WAIT_START (also unknown state)
    CLRF rx_state
    RETURN
 
Parse_WaitStart:
    MOVLW CHAR_START
    XORWF rx_byte,W
    BTFSS STATUS,2          ; Z: start byte?
    RETURN
    MOVLW GET_COMMAND
    MOVWF rx_state
    RETURN
 
Parse_GetCommand:
    MOVLW CMD_ID
    XORWF rx_byte,W
    BTFSC STATUS,2                 ; Z
    GOTO Parse_SaveCommand
    MOVLW CMD_ADC
    XORWF rx_byte,W
    BTFSC STATUS,2                 ; Z
    GOTO Parse_SaveCommand
    MOVLW CMD_SERVO
    XORWF rx_byte,W
    BTFSS STATUS,2                 ; Z
    GOTO Parse_ResetState       ; not 'I', 'A', or 'S'
Parse_SaveCommand:
    MOVF rx_byte,W
    MOVWF rx_command
    MOVLW GET_LENGTH
    MOVWF rx_state
    RETURN
 
Parse_GetLength:
    MOVLW CMD_ID
    XORWF rx_command,W
    BTFSS STATUS,2          ; Z: command is 'I'?
    GOTO Parse_LengthNotId      ; no, it is 'A' or 'S'
    CLRF rx_state               ; 'I': request ends here either way (WAIT_START)
    MOVF rx_byte,F
    BTFSS STATUS,2          ; Z: length byte = 0?
    RETURN
    MOVF reply_pending,F
    BTFSS STATUS,2          ; Z: no reply pending?
    RETURN
    MOVLW REPLY_ID
    MOVWF reply_pending
    RETURN
Parse_LengthNotId:
    MOVLW CMD_SERVO
    XORWF rx_command,W
    BTFSC STATUS,2          ; Z: command is 'S'?
    GOTO Parse_LengthServo
Parse_LengthAdc:
    MOVLW 1
    XORWF rx_byte,W
    BTFSS STATUS,2          ; Z: length byte = 1?
    GOTO Parse_ResetState
    MOVLW GET_CHANNEL
    MOVWF rx_state
    RETURN
Parse_LengthServo:
    MOVLW 2
    XORWF rx_byte,W
    BTFSS STATUS,2          ; Z: length byte = 2?
    GOTO Parse_ResetState
    MOVLW GET_MATCH_H
    MOVWF rx_state
    RETURN
 
Parse_GetChannel:
    CLRF rx_state               ; request ends here either way (WAIT_START)
    MOVF rx_byte,F
    BTFSS STATUS,2          ; Z: channel = 0 (AN0)?
    RETURN
    MOVF reply_pending,F
    BTFSS STATUS,2          ; Z: no reply pending?
    RETURN
    MOVLW REPLY_ADC
    MOVWF reply_pending
    MOVLW ADC_IDLE
    MOVWF adc_state             ; restart ADC sequence for this request
    RETURN
 
Parse_GetMatchH:
    MOVF rx_byte,W              ; hold the high byte until the low byte arrives
    MOVWF rx_hi
    MOVLW GET_MATCH_L
    MOVWF rx_state
    RETURN
 
Parse_GetMatchL:
    CLRF rx_state               ; request ends here either way (WAIT_START)
    MOVF rx_byte,W
    MOVWF rx_lo                 ; both bytes are now in hand: validate the 16-bit value
    CALL ServoUpdate
    RETURN
 
; ----------------------------------------------------------------------
; Validates the compare value in rx_hi:rx_lo and saves it for the next
; servo frame. Range is 0xB3D4 to 0xBBA4 (500 to 2500 us), both ends
; included.
;   - Out of range -> servo_h:servo_l keep the last accepted setting.
;                     Queue the range error reply (24 45 02 03 01) unless
;                     another reply is already pending.
;   - In range     -> copy both bytes to servo_h:servo_l with interrupts
;                     off, so the frame-start ISR never reads half of a
;                     new value. Valid S commands send no reply.
; This routine never writes CCPR1H/CCPR1L. The ISR does that at the
; start of the next frame.
; ----------------------------------------------------------------------
ServoUpdate:
    MOVLW MATCH_MIN_H
    SUBWF rx_hi,W               ; C = 1 when rx_hi >= 0xB3, Z = 1 when equal
    BTFSS STATUS,0                 ; C
    GOTO Servo_Reject           ; high byte below 0xB3
    BTFSS STATUS,2                 ; Z
    GOTO Servo_CheckMax         ; high byte above 0xB3: minimum is met
    MOVLW MATCH_MIN_L
    SUBWF rx_lo,W               ; high byte = 0xB3: low byte must be >= 0xD4
    BTFSS STATUS,0                 ; C
    GOTO Servo_Reject

Servo_CheckMax:
    MOVLW MATCH_MAX_H+1
    SUBWF rx_hi,W               ; C = 1 when rx_hi >= 0xBC
    BTFSC STATUS,0                 ; C
    GOTO Servo_Reject           ; high byte above 0xBB
    MOVLW MATCH_MAX_H
    XORWF rx_hi,W
    BTFSS STATUS,2                 ; Z: high byte = 0xBB?
    GOTO Servo_Accept           ; high byte below 0xBB: maximum is met
    MOVLW MATCH_MAX_L+1
    SUBWF rx_lo,W               ; high byte = 0xBB: low byte must be <= 0xA4
    BTFSC STATUS,0                 ; C: rx_lo >= 0xA5?
    GOTO Servo_Reject
 
Servo_Accept:
    BCF INTCON,7                ; GIE off so the two-byte copy cannot be split
    BTFSC INTCON,7              ; GIE can stay set if an interrupt hit during BCF
    GOTO Servo_Accept
    MOVF rx_hi,W
    MOVWF servo_h
    MOVF rx_lo,W
    MOVWF servo_l
    BSF INTCON,7                ; GIE on again
    RETURN
 
Servo_Reject:
    MOVF reply_pending,F
    BTFSS STATUS,2          ; Z: no reply pending?
    RETURN
    MOVLW REPLY_RANGE
    MOVWF reply_pending
    RETURN
 
; ----------------------------------------------------------------------
; Builds the reply packet in tx_data when reply_pending is set.
; It only starts a new packet after the last one is fully sent.
; All packets start with '$'. Then, depending on reply_pending:
;   - Error -> Reply_Error builds an 'E' packet.
;   - ID    -> Reply_Id builds an 'I' packet.
;   - ADC   -> calls ServiceAdc. If the result is not ready, it returns
;              and tries again on the next pass of Main.
; Reply_Queue then sets tx_count = 0 (so ServiceTx starts sending)
; and clears reply_pending.
; ----------------------------------------------------------------------
ServiceReply:
    MOVF reply_pending,F
    BTFSC STATUS,2          ; Z: any reply pending?
    RETURN
    MOVF tx_count,W
    SUBWF tx_length,W           ; W = tx_length - tx_count, Z = 1 when all sent
    BTFSS STATUS,2          ; Z: previous packet fully sent?
    RETURN
 
    MOVLW CHAR_START
    MOVWF tx_data               ; every packet starts with '$'
 
    MOVLW REPLY_FRAMING
    SUBWF reply_pending,W       ; C = 1 when reply_pending is an error
    BTFSC STATUS,0                 ; C
    GOTO Reply_Error
    MOVLW REPLY_ID
    XORWF reply_pending,W
    BTFSC STATUS,2                 ; Z
    GOTO Reply_Id
 
    CALL ServiceAdc             ; ADC reply: run the nonblocking ADC steps
    MOVLW ADC_READY
    XORWF adc_state,W
    BTFSS STATUS,2          ; Z: result ready?
    RETURN                      ; no: try again on the next pass
    MOVLW CMD_ADC
    MOVWF tx_data+1
    MOVLW 3
    MOVWF tx_data+2
    CLRF tx_data+3              ; channel 0x00
    MOVF adc_high,W
    MOVWF tx_data+4             ; HH
    MOVF adc_low,W
    MOVWF tx_data+5             ; LL
    MOVLW 6
    MOVWF tx_length
    CLRF adc_state              ; ADC_IDLE
    GOTO Reply_Queue
 
Reply_Id:
    MOVLW CMD_ID
    MOVWF tx_data+1
    MOVLW 2
    MOVWF tx_data+2
    MOVLW DEVICE_ID_H
    MOVWF tx_data+3
    MOVLW DEVICE_ID_L
    MOVWF tx_data+4
    MOVLW 5
    MOVWF tx_length
    GOTO Reply_Queue
 
Reply_Error:
    MOVLW CMD_ERROR
    MOVWF tx_data+1
    MOVLW 2
    MOVWF tx_data+2
    MOVLW 2
    SUBWF reply_pending,W       ; 3 -> 0x01 framing, 4 -> 0x02 overrun, 5 -> 0x03 range
    MOVWF tx_data+3
    CLRF tx_data+4              ; detail byte is 0 for receive errors
    MOVLW REPLY_RANGE
    XORWF reply_pending,W
    BTFSC STATUS,2          ; Z: servo range error?
    INCF tx_data+4,F            ; yes: detail byte = 1 -> 24 45 02 03 01
    MOVLW 5
    MOVWF tx_length
 
Reply_Queue:                    ; shared path: packet is built, start sending it
    CLRF tx_count
    CLRF reply_pending
    RETURN
 
; ----------------------------------------------------------------------
; Reads AN0 (LM34) without waiting. One step per call, using adc_state:
;   ADC_IDLE  -> start the conversion (set GO/DONE), go to ADC_BUSY
;   ADC_BUSY  -> if GO/DONE is still 1, return and check again later.
;                When it is 0, save ADRESH/ADRESL and go to ADC_READY
;   ADC_READY -> nothing to do (ServiceReply uses the result)
; The host converts the raw count to degrees F (10 mV per degree F).
; ----------------------------------------------------------------------
ServiceAdc:
    MOVF adc_state,F
    BTFSS STATUS,2          ; Z: ADC_IDLE?
    GOTO Adc_NotIdle
    BSF ADCON0,1           ; GO/DONE: start AN0 conversion
    MOVLW ADC_BUSY
    MOVWF adc_state
    RETURN
Adc_NotIdle:
    MOVLW ADC_BUSY
    XORWF adc_state,W
    BTFSS STATUS,2          ; Z: ADC_BUSY?
    RETURN                      ; ADC_READY: nothing to do
    BTFSC ADCON0,1         ; GO/DONE: conversion still running?
    RETURN
    MOVF ADRESH,W               ; bits 9:8 (right-justified)
    MOVWF adc_high
    BANKSEL ADRESL
    MOVF ADRESL,W               ; bits 7:0
    MOVWF adc_low
    BANKSEL ADCON0              ; back to Bank 0
    MOVLW ADC_READY
    MOVWF adc_state
    RETURN
 
; ----------------------------------------------------------------------
; Sends the reply packet, one byte per call.
;   - If tx_count = tx_length, the packet is done -> return.
;   - If TXREG is not empty (TXIF = 0), return and try again later.
;   - Otherwise send tx_data[tx_count] and add 1 to tx_count.
; FSR/INDF (indirect addressing) is used to pick the byte by index.
; ----------------------------------------------------------------------
; Example, tx_count = 2:  W = tx_data + 2 = 0x25 -> FSR = 0x25
;                         INDF now reads/writes RAM 0x25 = tx_data[2]
ServiceTx:
    MOVF tx_count,W
    SUBWF tx_length,W           ; Z = 1 when tx_count = tx_length
    BTFSC STATUS,2          ; Z: all bytes sent?
    RETURN
    BTFSS PIR1,4         ; TXIF: can TXREG accept another byte?
    RETURN
    MOVLW tx_data
    ADDWF tx_count,W            ; W = address of tx_data[tx_count]
    MOVWF FSR                   ; FSR is now a pointer to that byte
    MOVF INDF,W                 ; indirect read of tx_data[tx_count]
    MOVWF TXREG                 ; writing TXREG starts sending the byte
    INCF tx_count,F             ; move to the next byte
    RETURN
 
ISRHandler:
    MOVWF W_TEMP                ; save W (common RAM, bank does not matter)
    SWAPF STATUS,W              ; SWAPF does not change any flags
    MOVWF STATUS_TEMP
    MOVF PCLATH,W
    MOVWF PCLATH_TEMP
    CLRF PCLATH
    CLRF STATUS                 ; Bank 0, IRP = 0 for the rest of the ISR
 
    BTFSS PIR1,0                ; TMR1IF: servo frame start?
    GOTO ISR_PulseEnd
    BCF PIR1,0                  ; TMR1IF
    MOVF servo_h,W              ; next-frame compare from the saved value
    MOVWF CCPR1H
    MOVF servo_l,W
    MOVWF CCPR1L
    MOVLW FRAME_RELOAD_H        ; Timer1 = 0xB1E0 -> 20 ms to the next overflow
    MOVWF TMR1H
    MOVLW FRAME_RELOAD_L
    MOVWF TMR1L
    BSF PORTC,2                 ; RC2: servo pulse HIGH
    BSF servo_busy,0            ; foreground must not start service work
 
ISR_PulseEnd:
    BTFSS PIR1,2                ; CCP1IF: servo pulse end?
    GOTO ISR_Exit
    BCF PIR1,2                  ; CCP1IF
    BCF PORTC,2                 ; RC2: servo pulse LOW
    BCF servo_busy,0            ; foreground may resume
 
ISR_Exit:
    MOVF PCLATH_TEMP,W
    MOVWF PCLATH
    SWAPF STATUS_TEMP,W         ; restores the original bank bits too
    MOVWF STATUS
    SWAPF W_TEMP,F
    SWAPF W_TEMP,W              ; W restored without touching STATUS
    RETFIE
 
End