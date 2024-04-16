; File Name  : group7_simon_says.asm
;
; Author     : Group 7
; Description: Your project description 
; ------------------------------------------------------------

.equ DELAY_S = 65536 - (1000000 / 16)   ; sleep 1 second
.equ LED_DELAY = 3

.def redLedCnt = r21

; Vector Table
; ------------------------------------------------------------
.org 0x0000
          jmp       main

.org INTO0addr
          jmp       red_btn_isr

.equ OVF1addr
          jmp tm1_ISR

.org INT_VECTORS_SIZE                   ; end vector table      

; ------------------------------------------------------------
main:
;            main application method
;         one-time setup & configuration
; ------------------------------------------------------------
;
;         Light 1, Button 1
; ------------------------------------------------------------
          sbi       DDRB, DDB1          ; setting LED 1 to output
          cbi       PORTB, PORTB1       ; turn LED 1 off

          cbi       DDRD, DDD2          ; put button 1 in input mode
          sbi       PORTD, PD2          ; make input pull-up
;         Light 2, Button 2
; ------------------------------------------------------------
          sbi       DDRB, DDB2          ; setting LED 2 output
          cbi       PORTB, PORTB2       ; turn LED 2 off

          cbi       DDRD, DDD3          ; put button 2 in input mode
          sbi       PORTD, PD3          ; make input pull-up
;         Light 3, Button 3
; ------------------------------------------------------------
          sbi       DDRB, DDB4          ; setting LED 3 output
          cbi       PORTB, PORTB4       ; turn LED 3 off

          cbi       DDRD, DDD5          ; put button 3 in input mode
          sbi       PORTD, PD5          ; make input pull-up
;         Light 4, Button 4
; ------------------------------------------------------------
          sbi       DDRB, DDB5          ; setting LED 4 output
          cbi       PORTB, PORTB5       ; turn LED 4 off

          cbi       DDRD, DDD6          ; put button 4 in input mode
          sbi       PORTD, PD6          ; make input pull-up
;
;         timer
; ------------------------------------------------------------
          call      tm1_init            ; initialize timer 1
          sei                           ; enable global interrupts


main_loop:                              ; loop continuously 
; ------------------------------------------------------------


end_main:
          rjmp      main_loop           ; stay in main loop
          
;         Button Presses
; ------------------------------------------------------------
button_1_press:                         ; do {
          sbic      PIND, PIND2         ;    break on high // checks if pin d2 is set (which it is in line 24)
          rjmp      button_1_press        ; } while(true) // if pin d2 is set skip this instruction
          
          sbis      PINB, PINB1         ; if (led is on) skip next instruction
          rjmp      led_1_on              ; go to turn led on
          rjmp      led_1_off             ; go to turn led off
; ------------------------------------------------------------
button_2_press:                         ; do {
          sbic      PIND, PIND3         ;    break on high // checks if pin d2 is set (which it is in line 24)
          rjmp      button_2_press        ; } while(true) // if pin d2 is set skip this instruction
          
          sbis      PINB, PINB2         ; if (led is on) skip next instruction
          rjmp      led_2_on              ; go to turn led on
          rjmp      led_2_off             ; go to turn led off
; ------------------------------------------------------------
button_3_press:                         ; do {
          sbic      PIND, PIND4         ;    break on high // checks if pin d2 is set (which it is in line 24)
          rjmp      button_3_press        ; } while(true) // if pin d2 is set skip this instruction
          
          sbis      PINB, PINB4         ; if (led is on) skip next instruction
          rjmp      led_3_on              ; go to turn led on
          rjmp      led_3_off             ; go to turn led off
; ------------------------------------------------------------
button_4_press:                         ; do {
          sbic      PIND, PIND5         ;    break on high // checks if pin d2 is set (which it is in line 24)
          rjmp      button_4_press        ; } while(true) // if pin d2 is set skip this instruction
          
          sbis      PINB, PINB5         ; if (led is on) skip next instruction
          rjmp      led_4_on              ; go to turn led on
          rjmp      led_4_off             ; go to turn led off

;
; ------------------------------------------------------------
led_1_on:
          sbi       PORTB, PB1          ; turns on led
          rjmp      led_end             ; jumps to led end to call delay
led_1_off:
          cbi       PORTB, PB1          ; turns led off then calls delay
;
; ------------------------------------------------------------
led_2_on:
          sbi       PORTB, PB2          ; turns on led
          rjmp      led_end             ; jumps to led end to call delay
led_2_off:
          cbi       PORTB, PB2          ; turns led off then calls delay
;
; ------------------------------------------------------------
led_3_on:
          sbi       PORTB, PB4          ; turns on led
          rjmp      led_end             ; jumps to led end to call delay
led_3_off:
          cbi       PORTB, PB4          ; turns led off then calls delay
;
; ------------------------------------------------------------
led_4_on:
          sbi       PORTB, PB5          ; turns on led
          rjmp      led_end             ; jumps to led end to call delay
led_4_off:
          cbi       PORTB, PB5          ; turns led off then calls delay
;
; ------------------------------------------------------------
; jump to next led 
led_end:
          call      delay_tm1            ; sleep(n)

tm1_init:
          ldi       r20,HIGH(DELAY_CNT)
          sts       TCNT1H,r20
          ldi       r20,LOW(DELAY_CNT)
          sts       TCNT1L,r20

          clr       r20                 ; Normal Mode
          sts       TCCR1A, r20

          ldi       r20, (1<<CS12)      ; left shift operator, take a 1 and move it to position 2 in binary. Normal Mode Clock 256
          sts       TCCR1B, r20

          ldi       r20, (1<<TOIE1)     ; enabling timer overflow interrupt
          sts       TIMSK1, r20

          ret

tm1_ISR:
;-------------------------------------------------------------
          ldi       r20, HIGH(DELAY_CNT)
          sts       TCNT1H, r20
          ldi       r20, LOW(DELAY_CNT)
          sts       TCNT1L, r20

          clr       r20
          sts       TCCR1A, r20

          ldi       r20, (1<<CS12)
          sts       TCCR1B, r20

          ldi       r20, (1<<TOIE1)
          sts       TIMSK1, r20

          ret

tm1_ISR
          tst       redLedCnt
          breq      red_btn_off
          
          dec       redLedCnt
          rjmp      tm1_isr_ret     

tm1_red_off:
          cbi PORTB, PB1

tm1_isr_ret:
          ldi       r20, HIGH(DELAY_CNT)
          sts       TCNT1h, r20
          ldi       r20, LOW(DELAY_CNT)
          sts       TCNT1L, r20

          reti

red_btn_isr:
          tst       redLedCnt
          brne      red_btn_isr_ret

          sbi       PORTB, PB1
          ldi       redLedCnt, LED_DELAY

red_btn_isr_ret:
          reti
