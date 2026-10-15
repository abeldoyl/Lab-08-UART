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
 
; ---- Bank 0 variables ----
 COMStatus   EQU 0x20   ; flag byte: rx_ready, tx_pending, rx_error (bit numbers below)
 rx_byte     EQU 0x21   ; most recently received byte
 tx_byte     EQU 0x22   ; byte waiting for transmission
 
; ---- COMStatus flag bit numbers ----
 rx_ready    EQU 0      ; 1 = a received byte is waiting in rx_byte
 tx_pending  EQU 1      ; 1 = a byte is waiting in tx_byte to be sent
 rx_error    EQU 2      ; 1 = a framing or overrun error has been seen (sticky,
                        ;     only cleared by reset - watch it in the debugger)
 
; ---- Constants ----
 SPBRG_9600  EQU 25     ; 9600 baud = Fosc / (16 x (25 + 1)) with BRGH = 1, BRG16 = 0.
                        ; Correct for a 4 MHz clock; change this if the crystal is different.
 DIAG        EQU 0      ; PORTC bit used for the diagnostic output (RC0)
 
PSECT resetVect,class=CODE,delta=2
ResetVector:
    goto Setup
 
PSECT code,class=CODE,delta=2
 
; SETUP - runs once after reset, then falls into Main.
; No interrupts are used: the receiver and transmitter are polled by Main.
; Setup leaves Bank 0 selected, and every routine below assumes Bank 0.
Setup:
    BANKSEL PORTC
    CLRF COMStatus          ; rx_ready = tx_pending = rx_error = 0 (nothing received or waiting)
    CLRF PORTC              ; RC0 diagnostic output starts LOW
 
    BANKSEL TRISC
    MOVLW 0xFE
    MOVWF TRISC             ; RC0 = output (diagnostic pulse)
                            ; RC6/TX and RC7/RX must be inputs - the EUSART takes over both pins
 
    BANKSEL BAUDCTL
    BCF BAUDCTL,3           ; BRG16 = 0 -> 8-bit baud rate generator
 
    BANKSEL SPBRG
    MOVLW SPBRG_9600
    MOVWF SPBRG             ; baud divisor for 9600 baud
 
    BANKSEL TXSTA
    BCF TXSTA,4             ; SYNC = 0 -> asynchronous mode
    BSF TXSTA,2             ; BRGH = 1 -> high-speed baud rate
    BSF TXSTA,5             ; TXEN = 1 -> transmitter enabled
 
    BANKSEL RCSTA
    BSF RCSTA,7             ; SPEN = 1 -> EUSART owns RC6/TX and RC7/RX
    BSF RCSTA,4             ; CREN = 1 -> receive continuously (8-bit data, no 9th bit)
 
; MAIN - runs the three services in a fixed order, forever.
; Receive is serviced first and every pass, so a byte never sits in the
; receive FIFO for long. Each service returns immediately when it has
; nothing to do, which keeps the time between ServiceRx pulses short.
Main:
    CALL ServiceRx          ; collect a newly received byte
    CALL ProcessEcho        ; hand it over to the transmit side
    CALL ServiceTx          ; send it when the transmitter is free
    goto Main
 
; SERVICE RX - called once per pass through Main.
; Pulses the diagnostic pin so the scope can time how often the receiver is
; checked, then collects a byte if one has arrived.
; The byte is checked for errors BEFORE it is read: FERR/OERR describe the
; byte at the top of the FIFO, and reading RCREG moves on to the next one.
; Assumes Bank 0 on entry and leaves in Bank 0.
ServiceRx:
    BSF PORTC,0	            ; diagnostic pulse HIGH ...
    NOP                     ; (two NOPs widen the pulse to ~3 us so the
    NOP                     ;  scope can trigger on it)
    BCF PORTC,0		    ; ... then LOW: marks this receive-service check
 
    BTFSC COMStatus,rx_ready ; previous byte not echoed yet?
    RETURN                  ; yes: leave it alone, don't collect another
    BTFSS PIR1,5            ; RCIF set? (a byte has arrived)
    RETURN                  ; no byte: nothing to do
 
    BTFSC RCSTA,2           ; FERR: bad stop bit on this byte?
    goto RxFramingError
    BTFSC RCSTA,1           ; OERR: FIFO overflowed?
    goto RxOverrunError
 
    MOVF RCREG,W            ; good byte (reading RCREG also clears RCIF)
    MOVWF rx_byte
    BSF COMStatus,rx_ready  ; tell ProcessEcho a byte is ready
    RETURN
 
; RX FRAMING ERROR - branch target of ServiceRx, returns to ServiceRx's caller.
RxFramingError:
    MOVF RCREG,W            ; read and throw away the bad byte (this clears FERR)
    BSF COMStatus,rx_error
    RETURN
 
; RX OVERRUN ERROR - branch target of ServiceRx, returns to ServiceRx's caller.
RxOverrunError:
    BCF RCSTA,4             ; OERR is read-only: it clears when the receiver is
    BSF RCSTA,4             ; turned off (CREN = 0) and back on (CREN = 1)
    BSF COMStatus,rx_error
    RETURN
 
; PROCESS ECHO - moves a received byte to the transmit side.
; Only does so when there is a byte to send AND the previous echo has gone
; out, so a byte is never overwritten before it is transmitted.
ProcessEcho:
    BTFSS COMStatus,rx_ready ; anything received?
    RETURN                  ; no: nothing to echo
    BTFSC COMStatus,tx_pending ; previous echo still waiting to be sent?
    RETURN                  ; yes: try again next pass
 
    MOVF rx_byte,W          ; echo the byte unchanged
    MOVWF tx_byte
    BCF COMStatus,rx_ready  ; receive side may collect the next byte
    BSF COMStatus,tx_pending ; transmit side now has work to do
    RETURN
 
; SERVICE TX - sends the waiting byte as soon as the EUSART can take it.
; Never waits: if the transmit buffer is still busy it returns and tries
; again on the next pass, so ServiceRx keeps being called at a steady rate.
ServiceTx:
    BTFSS COMStatus,tx_pending ; anything waiting to be sent?
    RETURN                  ; no
    BTFSS PIR1,4            ; TXIF set? (transmit buffer can accept a byte)
    RETURN                  ; no: try again next pass
 
    MOVF tx_byte,W
    MOVWF TXREG             ; starts the transmission
    BCF COMStatus,tx_pending
    RETURN
End