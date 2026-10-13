    ; Abel Doyle
    ; RCET3375
    ; Lab8-2UART
    ; https://github.com/abeldoyl/Lab-08-UART/tree/main/Lab8-2UART/Lab8-2UART.X

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
    ; The EUSART takes over the pin direction itself when enabled, but the
    ; datasheet requires the TRIS bits for both pins to be 1.
    BANKSEL TRISC               ; TRISC is in Bank 1
    MOVLW 0xC0                  ; RC7:RC6 = 1, the rest outputs
    MOVWF TRISC
 
    ; ----- Baud rate generator: 8-bit, high speed -----
    ; BRG16 = 0 means only the 8-bit SPBRG register sets the baud rate,
    ; so the formula in SPBRG_VAL above applies.
    BANKSEL BAUDCTL             ; BAUDCTL is in Bank 3
    BCF BAUDCTL,3               ; 8-bit baud rate generator (BRG16 = 0)
 
    BANKSEL SPBRG               ; SPBRG is in Bank 1
    MOVLW SPBRG_VAL             ; 9600 baud at 4 MHz
    MOVWF SPBRG
    BANKSEL SPBRGH              ; SPBRGH is in Bank 3
    CLRF SPBRGH                 ; unused in 8-bit mode, keep clear
 
    ; ----- Transmit status/control -----
    ; Bank 1. These bits must be set before the transmitter is enabled.
    BANKSEL TXSTA
    BCF TXSTA,4                 ; SYNC = 0: asynchronous mode (see note on bit 3 vs. bit 4 in the chat)
    BSF TXSTA,2                 ; high speed baud rate (divisor of 16)
    BCF TXSTA,6                 ; 8-bit transmission (no 9th bit)
    BSF TXSTA,5                 ; enable transmitter; TXIF now reads 1 because TXREG is empty
 
    ; ----- Receive status/control -----
    ; SPEN connects the EUSART to the pins. Only SPEN is set here, so the
    ; receiver (CREN) stays off in this lab.
    BANKSEL RCSTA
    BSF RCSTA,7                 ; enable serial port, RC6/TX becomes TX pin
 
    BANKSEL PIR1                ; back to Bank 0 for main loop (PIR1 and TXREG are both in Bank 0)
 
Main:
    ; wait until the transmit buffer is empty (TXIF = 1)
    BTFSS PIR1,4                ; TXIF is PIR1 bit 4; skip the goto once it is set
    goto Main                   ; buffer still full: keep polling
 
    MOVLW TX_BYTE
    MOVWF TXREG                 ; start transmission of the selected byte
                                ; (writing TXREG clears TXIF until the byte moves to the shifter)
 
    goto Main                   ; repeat forever
 
End