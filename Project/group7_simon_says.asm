;
; File Name  : gpio_tm1_int.asm
;
; Author     : Prof. Allen
; Description: GPIO Output with timers and interrupts
;   Uses Timer1 with Overflow Interrupt, External Interrupt 0,
;   and a Pin-Change interrupt 
; ------------------------------------------------------------

.equ DELAY_CNT = 65536 - (1000000 / 16) ; 16 == 1 / 16MHz / 256

.equ LED_DELAY = 3

.def blueLedCnt = R21
.def greenLedCnt = R22
.def redLedCnt = R23
.def whiteLedCnt = R24

; Vector Table
; ------------------------------------------------------------
.org 0x0000                             ; reset vector
          jmp       main

.org INT0addr                           ; Ext Int 0 for Blue LED Button
          jmp       blue_led_btn_ISR

.org INT1addr
          jmp       red_led_btn_ISR

.org PCI2addr
          jmp       green_led_btn_ISR

.org PCI1addr
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
          cbi       PORTB,PB2           ; turn Green LED Off (D10)

          sbi       DDRB,DDB4           ; setting Red LED pin to output (D12)
          cbi       PORTB,PB4           ; turn Red LED Off (D14)

          sbi       DDRB,DDB3           ; setting Blue LED pin to output (D12)
          cbi       PORTB,PB3           ; turn Blue LED Off (D14)

          sbi       DDRB,DDB5           ; setting white LED pin to output (D12)
          cbi       PORTB,PB5           ; turn white LED Off (D14)


          cbi       DDRD,DDD2           ; set Blue LED Btn to input (D2)
          sbi       PORTD,PD2           ; engage pull-up
          sbi       EIMSK,INT0          ; enable external interrupt 0 for Blue LED Btn
          ldi       r20,0b00000010      ; set falling edge sense bits for ext int 0
          sts       EICRA,r20

          cbi       DDRD,DDD3           ; set Blue LED Btn to input (D3)
          sbi       PORTD,PD3           ; engage pull-up
          sbi       EIMSK,INT1

          cbi       DDRD,DDD4           ; set Green LED Btn to input (D4)
          cbi       PORTD,PD4           ; set high-impedance
          cbi       DDRD, DDD5          ; set White LED Btn to input (D5)
          cbi       PORTD, PD5          ; set high-impedance
          ldi       r20, 0b00110000     ; enable ports 4 and 5, PCINT20 and PCINT21
          sts       PCMSK2, r20         ; Port D
          ldi       r20, (1<<PCIE2)     ; 
          sts       PCICR, r20          ; enable PORTD change interrupt
          

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

; ------------------------------------------------------------
tm1_ISR:
; handle timer1 interrupts (overflow)
; ------------------------------------------------------------
          tst       blueLedCnt          ; if (blueLedCnt != 0)
          brne      tm1_isr_dec_blue    ;    go dec blue count
                                        ; else
          cbi       PORTB,PB2           ;    turn off blue LED
          rjmp      tm1_isr_green

tm1_isr_dec_blue:
          dec       blueLedCnt          ;  blueLedCnt--          
          
tm1_isr_green:
          tst       greenLedCnt          ; if (greenLedCnt != 0)
          brne      tm1_isr_dec_green    ;    go dec green count
                                         ; else
          cbi       PORTB,PB4            ;    turn off green LED
          rjmp      tm1_isr_red

tm1_isr_dec_green:
          dec       greenLedCnt          ;  greenLedCnt--   

tm1_isr_red:
          tst       redLedCnt
          brne      tm1_isr_dec_red

          cbi       PORTB, PB3
          rjmp      tm1_isr_white

tm1_isr_dec_red:
          dec       redLedCnt

tm1_isr_white:
          tst       whiteLedCnt
          brne      tm1_isr_dec_white

          cbi       PORTB, PB5
          rjmp      tm1_isr_ret

tm1_isr_dec_white:
          dec       whiteLedCnt

tm1_isr_ret:
          ldi       r20,HIGH(DELAY_CNT) ; reset timer counter
          sts       TCNT1H,r20
          ldi       r20,LOW(DELAY_CNT)
          sts       TCNT1L,r20

          reti

blue_led_btn_ISR:
; handle external interrupts 0 calls for the Blue LED button
; ------------------------------------------------------------
          tst       blueLedCnt          ; if (blueLedCnt != 0)
          brne      blue_led_btn_ret    ;    return
                                        ; else
          sbi       PORTB,PB2           ;    turn on Blue LED
          ldi       blueLedCnt,LED_DELAY;    set LED counter

blue_led_btn_ret:
          reti

red_led_btn_ISR:
          tst       redLedCnt
          brne      red_led_btn_ret
          
          sbi       PORTB,PB3
          ldi       redLedCnt, LED_DELAY

red_led_btn_ret:
          reti

green_led_btn_ISR:
; handle pin-change interrupts calls for the Green LED button
;
; Pin change interrupts use "Any-Change" or they fire for both
; falling-edge and rising-edge.
;
; Since PD4 is in high-impedance, we only want to handle
; intterupts when the voltage change was from low->high (rising edge)
; ------------------------------------------------------------
          sbis      PIND,PIND4          ; if(rising-edge) //skip
          rjmp      green_led_btn_ret   ; else return

          tst       greenLedCnt         ; if (greenLedCnt != 0)
          brne      green_led_btn_ret   ;    return
                                        ; else
          sbi       PORTB,PB4           ;    turn on Green LED
          ldi       greenLedCnt,LED_DELAY;   set LED counter

green_led_btn_ret:
          reti

white_led_btn_ISR:
; handle pin-change interrupts calls for the Green LED button
; ------------------------------------------------------------
          sbis      PIND,PIND5          ; if(rising-edge) //skip
          rjmp      white_led_btn_ret   ; else return

          tst       whiteLedCnt         ; if (greenLedCnt != 0)
          brne      white_led_btn_ret   ;    return
                                        ; else
          sbi       PORTB,PB5           ;    turn on Green LED
          ldi       whiteLedCnt,LED_DELAY;   set LED counter

white_led_btn_ret:
          reti
