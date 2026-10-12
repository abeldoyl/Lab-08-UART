    ; Abel Doyle
    ; RCET3375
    ; Lab8-1UART
    ; https://github.com/abeldoyl/Lab-08-UART/tree/main/Lab8-1UART.X

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

  TX_BYTE     EQU 0x24          ; byte to send: '$'  (try 0xFF, 0x00, 0x55, 0xAA, 0xF7, 0x08)
  SPBRG_VAL   EQU 25            ; 4 MHz / (16 * (25 + 1)) = 9615.38 baud, +0.16 % error
  delay_count EQU 0x20          ; scratch for the inter-byte delay

PSECT resetVect,class=CODE,delta=2
ResetVector:
    goto Setup

PSECT code,class=CODE,delta=2

Setup:
    ; ----- Port C: RC6/TX and RC7/RX must be set as inputs for the EUSART -----
    BANKSEL TRISC
    MOVLW 0xC0                  ; RC7:RC6 = 1, the rest outputs
    MOVWF TRISC

    ; ----- Baud rate generator: 8-bit, high speed -----
    BANKSEL BAUDCTL
    BCF BAUDCTL,BRG16           ; 8-bit baud rate generator

    BANKSEL SPBRG
    MOVLW SPBRG_VAL             ; 9600 baud at 4 MHz
    MOVWF SPBRG
    BANKSEL SPBRGH
    CLRF SPBRGH                 ; unused in 8-bit mode, keep clear

    ; ----- Transmit status/control -----
    BANKSEL TXSTA
    BCF TXSTA,SYNC              ; asynchronous mode
    BSF TXSTA,BRGH              ; high speed baud rate (divisor of 16)
    BCF TXSTA,TX9               ; 8-bit transmission (no 9th bit)
    BSF TXSTA,TXEN              ; enable transmitter

    ; ----- Receive status/control -----
    BANKSEL RCSTA
    BSF RCSTA,SPEN              ; enable serial port, RC6/TX becomes TX pin

    BANKSEL PIR1                ; back to Bank 0 for main loop

Main:
    ; wait until the transmit buffer is empty (TXIF = 1)
    BTFSS PIR1,TXIF
    goto Main

    MOVLW TX_BYTE
    MOVWF TXREG                 ; start transmission of the selected byte

    CALL Delay_1ms              ; optional gap to make scope triggering easier
    goto Main

; ----- Roughly one byte time (~1 ms at 4 MHz, 1 us per instruction cycle) -----
; Each pass = NOP(1) + DECFSZ(1) + GOTO(2) = 4 cycles; 248 passes ~ 0.99 ms.
; Exact length is not critical, remove the CALL above if you want back-to-back bytes.
Delay_1ms:
    MOVLW 248
    MOVWF delay_count
DelayLoop:
    NOP
    DECFSZ delay_count,F
    goto DelayLoop
    RETURN

End
