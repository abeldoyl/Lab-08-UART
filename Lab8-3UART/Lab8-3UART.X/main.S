    ; Abel Doyle
    ; RCET3375
    ; Lab8-3UART
    ; https://github.com/abeldoyl/Lab-08-UART/tree/main/Lab8-3UART/Lab8-3UART.X

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
CMD_ERROR     EQU 0x45        ; 'E' receive error response
DEVICE_ID_H   EQU 0x33        ; device ID 0x3375, high byte first
DEVICE_ID_L   EQU 0x75
 
; rx_state values
WAIT_START    EQU 0
GET_COMMAND   EQU 1
GET_LENGTH    EQU 2
GET_CHANNEL   EQU 3
 
; reply_pending values (the two error values must stay the largest)
REPLY_NONE    EQU 0
REPLY_ID      EQU 1
REPLY_ADC     EQU 2
REPLY_FRAMING EQU 3           ; error detail byte = value - 2 -> 0x01
REPLY_OVERRUN EQU 4           ; error detail byte = value - 2 -> 0x02
 
; adc_state values
ADC_IDLE      EQU 0
ADC_BUSY      EQU 1
ADC_READY     EQU 2
 
; Bit numbers used below
BIT_C         EQU 0           ; STATUS carry
BIT_Z         EQU 2           ; STATUS zero
BIT_IRP       EQU 7           ; STATUS indirect bank select (0 = banks 0/1)
BIT_TXIF      EQU 4           ; PIR1  TX register empty
BIT_RCIF      EQU 5           ; PIR1  RX byte waiting
BIT_OERR      EQU 1           ; RCSTA overrun error
BIT_FERR      EQU 2           ; RCSTA framing error
BIT_CREN      EQU 4           ; RCSTA continuous receive enable
BIT_GO        EQU 1           ; ADCON0 GO/DONE
DIAG_BIT      EQU 0           ; RC0 = receive-service diagnostic output
                              ; (change this if Part 2 used a different pin)
 
; ======================================================================
; RAM map - all in common RAM 0x70-0x7F so no bank switching is needed
; ======================================================================
rx_byte       EQU 0x70        ; latest received byte
rx_state      EQU 0x71        ; WAIT_START / GET_COMMAND / GET_LENGTH / GET_CHANNEL
rx_command    EQU 0x72        ; CMD_ID or CMD_ADC
reply_pending EQU 0x73        ; REPLY_NONE / ID / ADC / FRAMING / OVERRUN
adc_state     EQU 0x74        ; ADC_IDLE / ADC_BUSY / ADC_READY
adc_high      EQU 0x75        ; high byte of saved 10-bit result (bits 9:8)
adc_low       EQU 0x76        ; low byte of saved 10-bit result
tx_length     EQU 0x77        ; response packet length
tx_count      EQU 0x78        ; index of next byte to send = bytes queued so far
tx_data       EQU 0x79        ; tx_data[0..5] = 0x79..0x7E, consecutive bytes
 
; Scratch for the overrun-test delay only (Bank 0)
delay_outer   EQU 0x20
delay_inner   EQU 0x21
 
; ======================================================================
; Vectors
; ======================================================================
PSECT resetVect,class=CODE,delta=2
ResetVector:
    goto Setup
 
PSECT code,class=CODE,delta=2

Setup:
    CLRF INTCON                 ; interrupts off, RX is polled
    BCF STATUS,7          ; IRP: FSR/INDF reach banks 0/1 (tx_data is in common RAM)
 
    BANKSEL PORTC
    CLRF PORTC                  ; diagnostic output starts LOW
 
    BANKSEL TRISC
    MOVLW 0xC0                  ; RC7/RX and RC6/TX = 1 for the EUSART, RC0 diag = output
    MOVWF TRISC
    BANKSEL TRISA
    BSF TRISA,0                 ; RA0/AN0 is an input
 
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
    CLRF tx_length              ; tx_count = tx_length = 0 -> nothing to send
    CLRF tx_count
    CLRF tx_data
    CLRF tx_data+1
    CLRF tx_data+2
    CLRF tx_data+3
    CLRF tx_data+4
    CLRF tx_data+5
 
 
; ----------------------------------------------------------------------
; Each pass calls the four service routines in order:
;   1. ServiceRx    - check for a new received byte and parse it
;   2. ServiceReply - if a reply is needed, build the reply packet
;   3. ServiceTx    - send one byte of the reply packet
; (ServiceAdc is called from ServiceReply when an ADC reply is needed.)
; No routine waits, so the loop runs fast and RX is checked often.
; The RC0 pulse at the top of each pass lets a scope show how often
; the receiver is checked.
; ----------------------------------------------------------------------
Main:
    BSF PORTC,0          ; RC0: pulse marks one receive-service check
    NOP
    BCF PORTC,0                 ; RC0
    CALL ServiceRx
    CALL ServiceReply
    CALL ServiceTx
    ; CALL TestDelay            ; overrun test only: uncomment to block RX service
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
;   'I' request: '$' 'I' 0x00        -> sets reply_pending = REPLY_ID
;   'A' request: '$' 'A' 0x01 0x00   -> sets reply_pending = REPLY_ADC
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
    BTFSS STATUS,2                 ; Z
    GOTO Parse_ResetState       ; not 'I' or 'A'
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
    GOTO Parse_LengthAdc        ; no, it is 'A'
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
Parse_LengthAdc:
    MOVLW 1
    XORWF rx_byte,W
    BTFSS STATUS,2          ; Z: length byte = 1?
    GOTO Parse_ResetState
    MOVLW GET_CHANNEL
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
    SUBWF reply_pending,W       ; 3 -> 0x01 framing, 4 -> 0x02 overrun
    MOVWF tx_data+3
    CLRF tx_data+4              ; detail byte is always 0
    MOVLW 5
    MOVWF tx_length
 
Reply_Queue:                    ; shared path: packet is built, start sending it
    CLRF tx_count
    CLRF reply_pending
    RETURN
 
; ----------------------------------------------------------------------
; Reads AN0 without waiting. One step per call, using adc_state:
;   ADC_IDLE  -> start the conversion (set GO/DONE), go to ADC_BUSY
;   ADC_BUSY  -> if GO/DONE is still 1, return and check again later.
;                When it is 0, save ADRESH/ADRESL and go to ADC_READY
;   ADC_READY -> nothing to do (ServiceReply uses the result)
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
; Example, tx_count = 2:  W = tx_data + 2 = 0x7B -> FSR = 0x7B
;                         INDF now reads/writes RAM 0x7B = tx_data[2]
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
 
; ----------------------------------------------------------------------
; Test aid: ~6 ms of blocking delay (about 2 byte times at 9600 baud).
; Only runs when the CALL in Main is uncommented (overrun test).
; ----------------------------------------------------------------------
TestDelay:
    MOVLW 8
    MOVWF delay_outer
TestDelay_Outer:
    CLRF delay_inner            ; 256 passes of ~3 us = ~0.77 ms
TestDelay_Inner:
    DECFSZ delay_inner,F
    GOTO TestDelay_Inner
    DECFSZ delay_outer,F
    GOTO TestDelay_Outer
    RETURN
 
End