;
; File Name  : gpio_tm1_int.asm
;
; Author     : Prof. Allen
; Description: GPIO Output with timers and interrupts
;   Uses Timer1 with Overflow Interrupt, External Interrupt 0,
;   and a Pin-Change interrupt 
; ------------------------------------------------------------

; timer
.equ DELAY_CNT = 65536 - (1000000 / 16) ; 16 == 1 / 16MHz / 256

; Delay time in seconds
.equ LED_DELAY = 3

; LED Ports
.equ blueLed = PB3
.equ greenLed = PB2
.equ redLed = PB4
.equ whiteLed = PB5

; Button Ports
.equ blueLedBtn = PD3
.equ greenLedBtn = PD2
.equ redLedBtn = PD4
.equ whiteLedBtn = PB1

; Led Count Registers
.def blueLedCnt = R21
.def greenLedCnt = R22
.def redLedCnt = R23
.def whiteLedCnt = R24

; Vector Table
; ------------------------------------------------------------
.org 0x0000                             ; reset vector
          jmp       main

.org INT0addr                           ; Ext Int 0 for green LED Button
          jmp       green_led_btn_ISR

.org INT1addr                           ; Ext Int 1 for blue LED Button
          jmp       blue_led_btn_ISR

.org PCI2addr                           ; Pin Change Int 2 for red LED Button
          jmp       red_led_btn_ISR

.org PCI1addr                           ; Pin Change Int 1 for white LED Button
          jmp       white_led_btn_ISR


.org OVF1addr	                    ; Timer/Counter1 Overflow
          jmp       tm1_ISR

.org INT_VECTORS_SIZE
; end vector table
; ------------------------------------------------------------

; ------------------------------------------------------------
main:
; main application method
;         one-time setup & configuration
; ------------------------------------------------------------
       
          sbi       DDRB,DDB2           ; setting Green LED pin to output (D10)
          cbi       PORTB,greenLed      ; turn Green LED Off (D10)

          sbi       DDRB,DDB4           ; setting Red LED pin to output (D12)
          cbi       PORTB,redLed        ; turn Red LED Off (D14)

          sbi       DDRB,DDB3           ; setting Blue LED pin to output (D12)
          cbi       PORTB,blueLed       ; turn Blue LED Off (D14)

          sbi       DDRB,DDB5           ; setting white LED pin to output (D12)
          cbi       PORTB,whiteLed      ; turn white LED Off (D14)


          cbi       DDRD,DDD2           ; set Green LED Btn to input (D2)
          sbi       PORTD,greenLedBtn   ; engage pull-up
          sbi       EIMSK,INT0          ; enable external interrupt 0 for Blue LED Btn
          ldi       r20,0b00000010      ; set falling edge sense bits for ext int 0
          sts       EICRA,r20

          cbi       DDRD,DDD3           ; set Blue LED Btn to input (D3)
          sbi       PORTD,blueLedBtn    ; engage pull-up
          sbi       EIMSK,INT1

          cbi       DDRD,DDD4           ; set Red LED Btn to input (D4)
          cbi       PORTD,redLedBtn     ; set high-impedance
          cbi       DDRB, DDB1          ; set White LED Btn to input (D5)
          cbi       PORTB,whiteLedBtn   ; set high-impedance
          ldi       r20, (1<<PCINT20)   ; enable port 4
          sts       PCMSK2, r20         ; Port D
          ldi       r20, (1<<PCINT1)    ; enable port 1
          sts       PCMSK0, r20         ; Port B
          ldi       r20, (1<<PCIE2) | (1<<PCIE0) ; Enable PORT D and PORT B
          sts       PCICR, r20   

          call      tm1_init            ; initialize timer1

          sei                           ; enable global interrupts

main_loop:                              ; loop continuously 
; ------------------------------------------------------------
          ; all events are being handled by the 
          ; interrupt service routines
end_main:
          rjmp      main_loop           ; stay in main loop


; ------------------------------------------------------------
tm1_init:
; initialize timer1 with interrupts
; ------------------------------------------------------------
          ; set timer counter
          ldi       r20,HIGH(DELAY_CNT)
          sts       TCNT1H,r20
          ldi       r20,LOW(DELAY_CNT)
          sts       TCNT1L,r20

          clr       r20                 ; normal mode
          sts       TCCR1A,r20

          ldi       r20,(1<<CS12)       ; normal mode, clk/256
          sts       TCCR1B,r20          ; clock is started

          ldi       r20,(1<<TOIE1)      ; enable timer overflow interrupt
          sts       TIMSK1,r20

          ret                           ; delay_tm1
;
; ------------------------------------------------------------
;                    Timer ISR's
; ------------------------------------------------------------
;
tm1_ISR:
; handle timer1 interrupts (overflow)
; ------------------------------------------------------------
          tst       blueLedCnt          ; if (blueLedCnt != 0)
          brne      tm1_isr_dec_blue    ;    go dec blue count
                                        ; else
          cbi       PORTB,blueLed           ;    turn off blue LED
          rjmp      tm1_isr_green

tm1_isr_dec_blue:
          dec       blueLedCnt          ;  blueLedCnt--          
          
tm1_isr_green:
          tst       greenLedCnt          ; if (greenLedCnt != 0)
          brne      tm1_isr_dec_green    ;    go dec green count
                                         ; else
          cbi       PORTB,greenLed       ;    turn off green LED
          rjmp      tm1_isr_red

tm1_isr_dec_green:
          dec       greenLedCnt          ;  greenLedCnt--   

tm1_isr_red:
          tst       redLedCnt           ; if (redLedCnt!=0)
          brne      tm1_isr_dec_red     ;    go dec red count
                                        ; else
          cbi       PORTB,redLed        ;    turn off red led
          rjmp      tm1_isr_white

tm1_isr_dec_red:
          dec       redLedCnt

tm1_isr_white:
          tst       whiteLedCnt         ; if (whiteLedCnt!=0)
          brne      tm1_isr_dec_white   ;    go dec white count
                                        ; else
          cbi       PORTB,whiteLed      ; turn off white led
          rjmp      tm1_isr_ret

tm1_isr_dec_white:
          dec       whiteLedCnt

tm1_isr_ret:
          ldi       r20,HIGH(DELAY_CNT) ; reset timer counter
          sts       TCNT1H,r20
          ldi       r20,LOW(DELAY_CNT)
          sts       TCNT1L,r20

          reti
;
; ------------------------------------------------------------
;                   Button ISR's
; ------------------------------------------------------------
;
blue_led_btn_ISR:
; handle external interrupts 1 calls for the Blue LED button
; ------------------------------------------------------------
          tst       blueLedCnt          ; if (blueLedCnt != 0)
          brne      blue_led_btn_ret    ;    return
                                        ; else
          sbi       PORTB,blueLed       ;    turn on Blue LED
          ldi       blueLedCnt,LED_DELAY;    set LED counter

blue_led_btn_ret:
          reti

green_led_btn_ISR:
; handle external interrupts 0 calls for the Blue LED button
; ------------------------------------------------------------
          tst       greenLedCnt
          brne      green_led_btn_ret
          
          sbi       PORTB,greenLed
          ldi       greenLedCnt,LED_DELAY

green_led_btn_ret:
          reti

red_led_btn_ISR:
; handle pin-change interrupts calls for the Green LED button
; ------------------------------------------------------------
          sbis      PIND,redLedBtn      ; if(rising-edge) //skip
          rjmp      red_led_btn_ret     ; else return

          tst       redLedCnt           ; if (greenLedCnt != 0)
          brne      red_led_btn_ret     ;    return
                                        ; else
          sbi       PORTB,redLed        ;    turn on Green LED
          ldi       redLedCnt,LED_DELAY ; set LED counter

red_led_btn_ret:
          reti

white_led_btn_ISR:
; handle pin-change interrupts calls for the Green LED button
; ------------------------------------------------------------
          sbis      PINB,whiteLedBtn    ; if(rising-edge) //skip
          rjmp      white_led_btn_ret   ; else return

          tst       whiteLedCnt         ; if (greenLedCnt != 0)
          brne      white_led_btn_ret   ;    return
                                        ; else
          sbi       PORTB,whiteLed      ;    turn on Green LED
          ldi       whiteLedCnt,LED_DELAY;   set LED counter

white_led_btn_ret:
          reti
