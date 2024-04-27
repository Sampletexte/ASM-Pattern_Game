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
.equ LED_DELAY = 1
.equ SLOW_SPEED = 40
.equ MED_SPEED = 25
.equ FAST_SPEED = 10
; LED Ports
.equ blueLed = PB3 
.equ greenLed = PB2
.equ redLed = PB4
.equ whiteLed = PB5
.equ loseLed = PD5
.equ winLed = PB0
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
;Button Pressed Comparison Values
.equ whiteButtonPress = 4
.equ blueButtonPress = 3
.equ redButtonPress = 2
.equ greenButtonPress = 1

.def pat_row = r4
.def pat_col = r5

.def temp_pat_row = r6 
.def temp_pat_col = r7
   

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
          ldi       r19,1           
          sbi       DDRB,DDB2           ; setting Green LED pin to output (D10)
          cbi       PORTB,greenLed      ; turn Green LED Off (D10)

          sbi       DDRB,DDB4           ; setting Red LED pin to output (D12)
          cbi       PORTB,redLed        ; turn Red LED Off (D14)

          sbi       DDRB,DDB3           ; setting Blue LED pin to output (D12)
          cbi       PORTB,blueLed       ; turn Blue LED Off (D14)

          sbi       DDRB,DDB5           ; setting white LED pin to output (D12)
          cbi       PORTB,whiteLed      ; turn white LED Off (D14)

          sbi       DDRB, DDD6          ; lose LED
          cbi       PORTB, loseLed      ; turn lose LED off

          sbi       DDRD, DDB0          ; win LED pin to output
          cbi       PORTD, winLed       ; turn win LED off           


          cbi       DDRD,DDD2           ; set Green LED Btn to input (D2)
          sbi       PORTD,greenLedBtn   ; engage pull-up
          sbi       EIMSK,INT0          ; enable external interrupt 0 for Blue LED Btn
          LDI	r20, (0b10<<ISC10)  ; load 10 in ISC11:ISC10 

          ORI	r20, (0b10<<ISC00)  ; load 10 in ISC01:ISC00 

          STS	EICRA,r20     ; set falling edge sense bits for ext int 0

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

          call      tm1_init
          
          ldi       r16,0
          mov       pat_row,r16
          mov       pat_col, pat_row


       

patterns:
.db 4,1,3,1,0,0,0,0
.db 4,3,2,1,0,0,0,0    
.db 1,3,2,4,0,0,0,0  
.db 1,3,2,4,1,3,2,0 
.db 5,0,0,0,0,0,0,0


main_loop:  
          cli                        ;clear the global interrupt flag
          
          call     show_next
          
end_main:
          rjmp      main_loop           ; stay in main loop

show_next:
          ldi       ZH,HIGH(patterns<<1)
          ldi       ZL,LOW(patterns<<1)

          mov       r16,pat_row

find_pat_row:
          tst       r16                 ; if (row == 0)          
          breq      at_pat_row          ;   break

          adiw      ZH:ZL,8

          dec       r16                 ; row--

          rjmp      find_pat_row

at_pat_row:


          mov       r16,pat_col           ; pat_col_indx

find_pat_col:
          tst       r16
          breq      at_pat_col

          adiw      ZH:ZL,1             ; next pat_col address

          dec       r16                 ; pat_col_indx--

          rjmp      find_pat_col

at_pat_col:

          lpm       r27,Z               ; r27 = patterns[row][col]

show_led:
          cpi       r27,1               ; if(patterns[row][col] == 1                     
          breq      greenledshow

          cpi       r27,2               ; if(patterns[row][col] == 2    
          breq      redledshow

          cpi       r27,3               ; if(patterns[row][col] == 3   
          breq      blueledshow

          cpi       r27,4               ; if(patterns[row][col] == 4   
          breq      whiteledshow

          cpi       r27,5
          breq      endgame             ;if(patterns[row][col] == 5
                                        ;else {
          ldi       r16,0               ; reset col } 
          mov       pat_col,r16
          
          mov       temp_pat_row,pat_row      
          inc       pat_row
          sei
          ldi       r27,1
          call      input_loop
          cli
          ldi       r19,1   
          call      delay_ms
          call      delay_ms
          ret
                    
greenledshow:
          call      delay_ms
          sbi       PORTB,greenled
          call      delay_ms
          cbi       PORTB,greenled
          inc       pat_col
          ret

redledshow:
          call      delay_ms
          sbi       PORTB,redled
          call      delay_ms
          cbi       PORTB,redled
          inc       pat_col
          ret

blueledshow:
          call      delay_ms
          sbi       PORTB,blueled
          call      delay_ms
          cbi       PORTB,blueled
          inc       pat_col
          ret

whiteledshow:
          call      delay_ms
          sbi       PORTB,whiteLed
          call      delay_ms
          cbi       PORTB,whiteLed
          inc       pat_col
          ret

endgame:
          sbi       PORTB,greenled
          rjmp      endgame
;-----------------------------------------
;             INPUT LOOP
;----------------------------------------

input_loop:
          cli
          call      delay_ms
          cpi       r19,5                
          breq      ret_input_loop
          sei
          call      delay_ms
          rjmp      input_loop

ret_input_loop:
          ldi       r16,0               ; reset col } 
          mov       pat_col,r16 
          ret                           ; exit loop

show_next_input:           
          ldi       ZH,HIGH(patterns<<1)
          ldi       ZL,LOW(patterns<<1)    
          
          mov       r16,temp_pat_row                
find_temp_pat_row:
          tst       r16                 ; if (temp_row == 0)          
          breq      at_temp_pat_row          ;   break

          adiw      ZH:ZL,8

          dec       r16                 ; temp_row--

          rjmp      find_temp_pat_row

at_temp_pat_row:
          mov       r16,pat_col           ; pat_col_indx      
  
find_temp_pat_col:
          tst       r16
          breq      at_temp_pat_col

          adiw      ZH:ZL,1             ; next pat_col address

          dec       r16                 ; pat_col_indx--

          rjmp      find_temp_pat_col 
     
at_temp_pat_col:
          lpm       r27,Z               ; r27 = patterns[row][col]
          
  
show_temp:          
          cp        r27,r18   
          brne      fail_condition

          
          cp         r27,r18
          breq      win_condition
                                        ;else {
          reti

fail_condition:
          sbi       PORTD,loseLed
          call      delay_ms_show
          cbi       PORTD, loseLed
          ldi       ZH,HIGH(patterns<<0)
          ldi       ZL,LOW(patterns<<0)
          rjmp      main

win_condition:
          sbi       PORTB, winLed
          inc       r19
          inc       pat_col
          call      delay_ms
          cbi       PORTB, winLed
          reti 

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

          ret 

delay_ms:
; creates a timed delay using multiple nested loops
; ------------------------------------------------------------
          ldi       r18, 15
delay_ms_1:

          ldi       r17,200
delay_ms_2:

          ldi       r16,250
delay_ms_3:
          nop
          nop
          dec       r16
          brne      delay_ms_3          ; 250 * 5 = 1250

          dec       r17
          brne      delay_ms_2          ; 200 * 1250 = 250K

          dec       r18
          brne      delay_ms_1          ; 16 * 250K = 4M (1/4s ex)
dealy_ms_end:
          ret         


delay_ms_show:
; creates a timed delay using multiple nested loops for failed pattern
; ------------------------------------------------------------
          ldi       r18, 200
delay_ms_show_1:

          ldi       r17,200
delay_ms_show_2:

          ldi       r16,250
delay_ms_show_3:
          nop
          nop
          dec       r16
          brne      delay_ms_show_3          ; 250 * 5 = 1250

          dec       r17
          brne      delay_ms_show_2          ; 200 * 1250 = 250K

          dec       r18
          brne      delay_ms_show_1          ; 16 * 250K = 4M (1/4s ex)
dealy_ms_show_end:
          ret         


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
          ldi       r18,3
          call      show_next_input

blue_led_btn_ret:
          reti

green_led_btn_ISR:
; handle external interrupts 0 calls for the green LED button
; ------------------------------------------------------------
                 

          tst       greenLedCnt
          brne      green_led_btn_ret
          
          sbi       PORTB,greenLed
          ldi       greenLedCnt,LED_DELAY
          ldi       r18,1 
          call      show_next_input
         


green_led_btn_ret:
          reti

red_led_btn_ISR:
; handle pin-change interrupts calls for the Red LED button
; ------------------------------------------------------------
         

          sbis      PIND,redLedBtn      ; if(rising-edge) //skip
          rjmp      red_led_btn_ret     ; else return

          tst       redLedCnt           ; if (redLedCnt != 0)
          brne      red_led_btn_ret     ;    return
                                        ; else
          sbi       PORTB,redLed        ;    turn on red LED
          ldi       redLedCnt,LED_DELAY ; set LED counter   
          ldi       r18,2
          call      show_next_input
         

red_led_btn_ret:
          reti

white_led_btn_ISR:
; handle pin-change interrupts calls for the White LED button
; ------------------------------------------------------------        
       
          
          sbis      PINB,whiteLedBtn    ; if(rising-edge) //skip
          rjmp      white_led_btn_ret   ; else return

          tst       whiteLedCnt         ; if (whiteLedCnt != 0)
          brne      white_led_btn_ret   ;    return
                                        ; else
          sbi       PORTB,whiteLed      ;    turn on white LED
          ldi       whiteLedCnt,LED_DELAY;   set LED counter
          ldi       r18,4
          call      show_next_input
        

white_led_btn_ret:
          reti





; Example in C++ to do 2 rounds
;         
;
;
;         
;         string arr[2] = {"12340","43210"}
;         string tempString = "";
;         While(int timer != 0 && inputNum < 4){
;           if(event.type == white_button_input){
;                        tempstring[inputNum] = 1      
;                       inputNum++;
;                    }
;          else if(event.type == blue_button_input){
;                       tempstring[inputNum] = 2      
;                       inputNum++;
;                  } 
;          else if(event.type == red_button_input){
;                       tempstring[inputNum] = 3      
;                       inputNum++;
;                  } 
;          else if(event.type == green_button_input){
;                       tempstring[inputNum] = 4      
;                       inputNum++;
;                  } 
;         --timer
;                  }
;         bool correct = true;
;         while(arr[i] != 0){
;             if(arr[i] != tempstring[i]{
;                  correct = false;
;                             }
;                    }
;         if(correct){
;             LIGHT UP GREEN LED
;         if(!correct){
;             LIGHT UP RED LED            
;
;     
;
;.equ     TM1_CNT   =65336    (5000000/16)
;
;
;         main:
;
;         main_lp
;      
;
;
;         
;         end_main:
;                   rjmp      main_lp
;
;
;
;
;tm1_init:
;         ldi       r20_HIGH(TM1_CNT)
  ;        sts       TCNT1H,r20
   ;       ldi       r20,LOW(Tm1_CNT)
;
 ;         clr       r20
  ;        sts       TCCRBA,r20
;
 ;         ldi       r20, (1<<TO1E1)]    
  ;        sts       TIMSK1,
;        
;patterns:
;         .db      1,2,3,4,0,0,0,0
;         ,db      4,3,2,1,0,0,0,0