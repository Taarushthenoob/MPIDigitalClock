#make_bin#

; BIN is plain binary format similar to .com format, but not limited to 1 segment;
; All values between # are directives, these values are saved into a separate .binf file.
; Before loading .bin file emulator reads .binf file with the same file name.

; All directives are optional, if you don't need them, delete them.

; set loading address, .bin file will be loaded to this address:
#LOAD_SEGMENT=0000h#
#LOAD_OFFSET=0000h#

; set entry point:
#CS=0000h#	; same as loading segment
#IP=0000h#	; same as loading offset

; set segment registers
#DS=0000h#	; same as loading segment
#ES=0000h#	; same as loading segment

; set stack
#SS=0000h#	; same as loading segment
#SP=FFFEh#	; set to top of loading segment

; set general registers (optional)
#AX=0000h#
#BX=0000h#
#CX=0000h#
#DX=0000h#
#SI=0000h#
#DI=0000h#
#BP=0000h#

	;jump to the start of the code - reset address is kept at 0000:0000
;as this is only a limited simulation
         jmp     st1 
;jmp st1 - takes 3 bytes followed by nop that is 4 bytes
         nop  
;int 1 is not used so 1 x4 = 00004h - it is stored with 0
         dw      0000
         dw      0000   
;eoc - is used as nmi - ip value points to ad_isr and cs value will
;remain at 0000
         dw     start1
         dw      0000
;int 3 to int 255 unused so ip and cs intialized to 0000
;from 3x4 = 0000cH		 
		 db     1012 dup(0)

st1:    cli 					; clear interrupt flag, because we won't be using maskable innterrupts

          mov       ax,200h		; intialize ds, es,ss to start of RAM
          mov       ds,ax
          mov       es,ax
          mov       ss,ax
          mov       sp,0FFEH
		  
								
	port1a equ 00h				
	port1b equ 02h; ports for 8255A
	port1c equ 04h
	creg1 equ 06h

	port2a equ 10h				
	port2b equ 12h
	port2c equ 14h; ports for 8255B
	creg2 equ 16h
	
						
	counter_0 equ 08h
	counter_1 equ 0Ah			
	creg equ 0Eh;ports for 8254 timer               
	
	
	mov al,80h 			
	out creg2,al;setting all ports of 8255B for mode 0 output
	
	mov al,9Bh 			
	out creg1,al;seting all ports of 8255A for mode 0 input
	
	; To run the clock, we need interrupts at an interval of 1 sec (so as to update the value of second).
	; 8254 is running on 10kHz clock => We must divide by (100)d or (0064)h in order to get a out frequency of 100Hz which is the clock input for counter1
	; to which we give a count of (100)d or (0064)h square wave of 0.5 sec up and 0.5 down
	; Note that we are using mode 3, i.e. square wave generation mode
	
		  mov       al,36h	
		  out       creg,al   
		  mov       al,76h
		  out       creg,al
		  mov       al,64h
		  out       counter_0,al
		  mov       al,00h
		  out       counter_0,al 
		  mov       al,64h
		  out       counter_1,al
		  mov       al,00h
		  out       counter_1,al  
	
	                    

	;initialisation of lcd

		MOV AL, 38H 			;initialize LCD for 2 lines & 5*7 matrix
		out port2b,al
		mov al,01h  			;clearscreen
		out port2c,al
		MOV AL, 00000000B 		;RS=0,R/W=0,E=0 for H-To-L pulse
		out port2c,al
		call delay_20ms
		
		MOV AL, 0EH 			;LCD on, cursor on and no blink character
		out port2b,al
		mov al,01h
		out port2c,al
		mov al,00h
		out port2c,al
		call delay_20ms
		
		MOV AL, 06  			;command for shifting cursor right
		out port2b,al
		mov al,01h
		out port2c,al
		mov al,00h
		out port2c,al
		call delay_20ms
	;initialisation end
				  
		; Setting the default values
		
		mov second,0
		mov min,0
		mov hour,13
		mov hour_12,1
		mov format_check,0
		mov phase,1				; Initiazed time to 1:00:00 pm
		
		mov day,1
		mov month,1
		mov year,21				; setting date to 1/1/2021
		
		mov count_sec,60
		mov count_min,60
		mov count_hour,24
		mov count_day,30
		mov count_month,12		; the total number of seconds in a min, minutes in an hour, etc.
				
		
										
		mov alarm_hour,13
		mov alarm_hour_12,1
		mov alarm_min,2
		mov alarm_phase,1		; setting alarm for 1:02 pm     
		
		
		; the main program 
polling:
		in al,port1c 
		cmp al,00
		jne p2				; Jump if the thumbswitch isn't in lock position
		call delay_20ms		; Delay code execution by 20ms
		in al,port1c		
		cmp al,00
		jne p2				;Again checking the same because of thumbswitch debounce property
		in al,port1a
		and al,10h 			 
		cmp al,10h			;Checking whether the alarm is on/ off
		jne p1				;Keep polling
		call buzzer			;Buzzer is called 
p1:		jmp polling			;If alarm is not set and switch is in LOCK position => Keep polling
p2:		in al,port1c
		mov bl,al
		call delay_20ms
		in al,port1c
		cmp al,bl				; if the two values are diff, keep polling
		jne polling			
		ret							
							
		
		

mn0:	cmp al,80h			;Set Hour
		jne mn1		
		call set_hour 
mn1:	cmp al,40h 			;Set Minute
		jne mn2
		call set_minute
mn2:	cmp al,20h 			;Set Second
		jne mn3
		call set_second
mn3:	cmp al,10h 			;Set Date
		jne mn4
		call set_date
mn4:	cmp al,08h 			;Set Month
		jne mn5
		call set_month
mn5:	cmp al,04h 			;Set Year
		jne mn6
		call set_year
mn6:	cmp al,02h 			;Set Alarm Hour
		jne mn7
		call set_alarm_hour 
mn7:	cmp al,01h			;Set Alarm Min
		jne mn8
		call set_alarm_min
mn8:		jmp polling     ; After one of them has been done, we need to repeat the polling process

;end of main program.

	
	; ISR associated with NMI(from 8254) compares seconds, minutes, etc increments them if necessary 
	;if second reaches 60, reset it to 0 and increment minute and so on for hour, day, month and year
start1: 
    sti
	mov al,second					;inc second
	inc al
	mov second,al
	cmp al,count_sec				; check if the seconds have reached 60
	jne y1							
	
	mov second,00					
	mov al,min						
	inc al
	mov min,al
	mov al,min
	cmp al,count_min
	jne y1							

	mov min,00						; Increment hour if minutes reached 60
	mov al,hour
	inc al
	mov hour,al
	cmp al,count_hour
	jne y1							

	mov hour,00						
	mov al,day
	inc al
	mov day,al
	mov al,day					
	cmp al,count_day				
	jne y1							

	mov day,1						
	mov al,month			
	inc al
	mov month,al
	mov al,month
	cmp al,count_month				; compare month with 12
	jne y1							

	mov month,1						;increment year
	mov al,year
	inc al
	mov year,al
y1:	call display  
	iret

; end of ISR associated with NMI (int 2h)
	
; procedure for delaying sequential execution of program by 20ms
delay_20ms proc near
				push 	cx
				mov 	cx,900d
				
dl1:			nop							
				loop 	dl1					
				
				pop 	cx					
				ret
delay_20ms endp 



;procedure to display clock
display proc near		  
		
	;format_check: 1 = 24hr & 0 = 12hr
	
		
		;input format check
		in al,port1a
		and al,01h
		mov format_check,al 		
		
		;clearing screen
		mov al,01h
		out port2b,al
		mov al,01h
		out port2c,al
		mov al,00h
		out port2c,al
		call delay_20ms
		
		
		;checking if 24hr or 12hr 
		mov al,format_check
		cmp al,1
		jne hr12				
		
		;display the 24 hr format time
		
		mov cx,0	
		mov al,hour  
		
		mov       bl,al 
	    mov       al,0          ; converting hex to dec value
x1:		add       al,01
	    daa
	    dec       bl
	    jnz       x1
				
        mov digit,al			
								
		and al,0f0h				
		mov cl,4
		rol al,cl
		add al,30h				
		
		out port2b,al			
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
						
						
		mov al,digit			
		and al,0fh
		add al,30h				
						
		out port2b,al			
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms

		; displaying time in 24 hour format completed
				
		jmp skip
		
	;	displaying 12 hour format
	
hr12:mov al,hour
	cmp al,00					
	jne a1						
	mov hour_12,12
	mov phase,0
	jmp exit					

a1:	cmp al,12					;12pm
	jne a2
	mov hour_12,12
	mov phase,1
	jmp exit

a2:	cmp al,12					;am
	ja a3
	mov hour_12,al
	mov phase,0
	jmp exit

a3:	mov bl,12					;Subtract 12, pm
	sub al,bl
	mov hour_12,al	
	mov phase,1
	
exit:	mov al,hour_12
		mov       bl,al 
	    mov       al,0          ; converting hex to dec value
x2:		add       al,01
	    daa
	    dec       bl
	    jnz       x2
		mov digit,al			
		
		and al,0f0h				
		mov cl,4
		rol al,cl
		add al,30h
		
		out port2b,al			
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		mov al,digit			
		and al,0fh
		add al,30h
		
		out port2b,al			
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
	;display_hour_12 completed
		
	;displaying ':'
skip:		mov al,3ah		;Ascii value of ':' is 3a
		out port2b,al		; displaying ':'
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
							
		;displaying min 
		mov cx,0
		mov al,min
		mov       bl,al 
	    mov       al,0          ; converting hex to dec value
x3:		add       al,01
	    daa
	    dec       bl
	    jnz       x3
		mov digit,al
								
		and al,0f0h
		mov cl,4
		rol al,cl
		add al,30h
								
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
								
		mov al,digit
		and al,0fh
		add al,30h
								
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		;display min completed
		
		;displaying ':'
		mov al,3ah
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		;display sec
		
		mov al,second
		mov       bl,al 
	    mov       al,0          ; converting hex to dec value
x4:		add       al,01
	    daa
	    dec       bl
	    jnz       x4
		mov digit,al
								
		and al,0f0h
		mov cl,4
		rol al,cl
		add al,30h
								
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
								
		mov al,digit
		and al,0fh
		add al,30h
								
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		;display_sec completed
		
	;Checking for format again
		mov al,format_check			
		cmp al,1				
		je skip2
		
		;space
		mov al,20h
		out port2b, al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		
								;checking am or pm			
		mov al,phase
		cmp al,1
		je pm1
	
		;Displaying 'am' 
		mov al,41h
		out port2b, al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		mov al,4dh
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		jmp skip2
		
		;Displaying 'pm'

pm1:
		mov al,50h
		out port2b, al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		mov al,4Dh
		out port2b, al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms

		
skip2:	
		;next line, 6th position

		mov al,0C6h
		out port2b,al
		mov al,01h
		out port2c,al
		mov al,00h
		out port2c,al
		call delay_20ms
		
		;Displaying date
		
		mov al,day
		mov       bl,al 
	    mov       al,0        
x5:		add       al,01
	    daa
	    dec       bl
	    jnz       x5
		mov digit,al
							
		and al,0f0h
		mov cl,4
		rol al,cl
		add al,30h
							
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
							
		mov al,digit
		and al,0fh
		add al,30h
							
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		;display_day completed
		
		;displaying '/'
		mov al,2fh
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		;display month
		
		mov al,month
		mov       bl,al 
	    mov       al,0          ; converting hex to dec value
x6:		add       al,01
	    daa
	    dec       bl
	    jnz       x6
		mov digit,al
			
		and al,0f0h			
		mov cl,4
		rol al,cl
		add al,30h
		
		out port2b,al		
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		mov al,digit		
		and al,0fh
		add al,30h
		
		out port2b,al		
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		;display_month completed
		
		;displaying '/'
		mov al,2fh
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		;display year
		 		
		
		;display 2
		mov al,32h
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		;display 0 
		mov al,30h
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		
		;display year_last 2 digits
		
		mov al,year
		mov       bl,al 
	    mov       al,0          ; converting hex to dec value
x7:		add       al,01
	    daa
	    dec       bl
	    jnz       x7
		mov digit,al
						
		and al,0f0h			
		mov cl,4
		rol al,cl
		add al,30h
							
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
							
		mov al,digit
		and al,0fh
		add al,30h
							
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		;display_year completed
		
		
		
		
		
		
		ret
	display endp				;Display procedure ends here          
	
	
	
	;procedure to set hour
set_hour proc near
    call display
	
sh1:	
	in al,port1c
	cmp al,80h			
	jnz sh2						; if set hour is not high then ret		
	
	
     	in al,port1a			;Check format
		and al,01h		
		mov bl,format_check	
		cmp al,bl
		je n1		
		call display		;display if format changed
n1:   		
		in al,port1c		;check set_hour  debounce
		cmp al,80h		
		jne sh2			
		in al,port1a		
		and al,01h
		mov bl,format_check
		cmp al,bl				
		je n2			
		call display

n2:	    in al,port1b			;debounce for inc/dec
    	cmp al,00
    	je n1
    	mov bl,al
    	call delay_20ms
    	in al,port1b
    	cmp al,bl
    	jne n1
    	
    	in al,port1b
    	cmp al,01h					
    	jnz sh3							
    	mov bl,hour			
    	dec bl			 
    	cmp bl,00 			
    	jge sh5				
	
	
	    mov bl,23			;If the hour value goes lower than 0 make it 23
sh5:	
	    mov hour,bl			
		mov al,hour			
		cmp al,00		;12 AM
		jne shr01
		mov hour_12 , 12	
		mov phase,0
		jmp exit1		
shr01:		
		cmp al,12		
		jne shr04		;12 PM
		mov hour_12,12
		mov phase,1
		jmp exit1
shr04:		
		cmp al,12		;am
		ja shr02
		mov hour_12,al
		mov phase,0
		jmp exit1
shr02:		
		sub al,12
		mov hour_12,al	
		mov phase,1
						; display
exit1:	call display			
		jmp sh1			;check again
sh3:		
		;To check increment
		cmp al,02h		
		jne sh1			
		mov bl,hour		
		inc bl
		cmp bl,24			
		jb sh6
		mov bl,00		
sh6:	mov hour,bl
						;setting hour_12
		mov al,hour
		cmp al,00
		jne shr01
		mov hour_12 , 12
		mov phase,0
		jmp exit2
shr11:		cmp al,12
		jne shr04
		mov hour_12,12
		mov phase,1
		jmp exit2
shr14:		cmp al,12
		ja shr02
		mov hour_12,al
		mov phase,0
		jmp exit2
shr12:		sub al,12
		mov hour_12,al	
		mov phase,1
						;incrementing hour done 					
exit2:	call display
		jmp sh1
sh2:		ret			;End of set_hour

set_hour endp

						;set_month
set_month proc near 
    call display
mon1:	in al,port1c
	cmp al,08h
	jne mon2
     	in al,port1a			;Check format
		and al,01h		
		mov bl,format_check	
		cmp al,bl
		je n3		
		call display		;display if format changed
n3:   		
		in al,port1c		;check set_month  debounce
		cmp al,08h		
		jne mon2			
		in al,port1a		
		and al,01h
		mov bl,format_check
		cmp al,bl				
		je n4			
		call display

n4:	    in al,port1b			;debounce for inc/dec
    	cmp al,00
    	je n3
    	mov bl,al
    	call delay_20ms
    	in al,port1b
    	cmp al,bl
    	jne n3
   			
    	in al,port1b
    	cmp al,01h
    	jne mon3
    	mov bl,month
    	dec bl
    	cmp bl,0
    	jne mon4
    	mov bl,12
mon4:	mov month,bl			;Decrement
    	call display
    	jmp mon1
mon3:	cmp al,02h
    	jne mon1
    	mov bl,month				;Increment
    	inc bl
    	cmp bl,13
    	jne mon5
    	mov bl,1
mon5:	mov month,bl
    	call display
    	jmp mon1
mon2:	ret
set_month endp

						
									;set_minute function starts			
set_minute proc near

    call display

m1:	in al,port1c			
	cmp al,40h
	jnz m2
	
    	in al,port1a			;Check format
		and al,01h		
		mov bl,format_check	
		cmp al,bl
		je n5		
		call display		;display if format changed
n5:   		
		in al,port1c		;check set_minute  debounce
		cmp al,40h		
		jne m2			
		in al,port1a		
		and al,01h
		mov bl,format_check
		cmp al,bl				
		je n6			
		call display

n6:	    in al,port1b			;debounce for inc/dec
    	cmp al,00
    	je n5
    	mov bl,al
    	call delay_20ms
    	in al,port1b
    	cmp al,bl
    	jne n5
   	
	 		
	in al,port1b			
	cmp al,01h			
	jnz m3
	mov bl,min			;Decrement
	cmp bl,0			
	jnz m4				
	add bl,60
m4:	dec bl
	mov min,bl
	call display
	jmp m1
	
m3:	cmp al,02h
	jnz m1				;Increment
	mov bl,min
	inc bl
	cmp bl,60
	jnz m5
	mov bl,0
m5:	mov min,bl
	call display
	jmp m1
m2:	ret
set_minute endp			

						;set_date
set_date proc near
    call display
da1:	in al,port1c
	cmp al,10h
	jne da2
	
	    in al,port1a			;Check format
		and al,01h		
		mov bl,format_check	
		cmp al,bl
		je n7		
		call display		;display if format changed
n7:   		
		in al,port1c		;check set_date  debounce
		cmp al,10h		
		jne da2			
		in al,port1a		
		and al,01h
		mov bl,format_check
		cmp al,bl				
		je n8			
		call display

n8:	    in al,port1b			;debounce for inc/dec
    	cmp al,00
    	je n7
    	mov bl,al
    	call delay_20ms
    	in al,port1b
    	cmp al,bl
    	jne n7 		
	
	in al,port1b
	cmp al,01h
	jne da3
	
	mov bl,day
	dec bl
	cmp bl,0
	jne da4
	mov bl,count_day
da4:	
	mov day,bl					;Decrement
	call display
	jmp da1
da3:	cmp al,02h
	jne da1
	mov bl,day
	cmp bl,count_day			;Increment
	jne da5
	mov bl,0
da5:	inc bl
	mov day,bl	
	call display
	jmp da1
da2:	ret
set_date endp	

						;set_second	
set_second proc near
    call display
s1:	in al,port1c
	cmp al,20h
	jnz s2
	
	    in al,port1a			;Check format
		and al,01h		
		mov bl,format_check	
		cmp al,bl
		je n9		
		call display		;display if format changed
n9:   		
		in al,port1c		;check set_second  debounce
		cmp al,20h		
		jne s2			
		in al,port1a		
		and al,01h
		mov bl,format_check
		cmp al,bl				
		je n10			
		call display

n10:	    in al,port1b			;debounce for inc/dec
    	cmp al,00
    	je n9
    	mov bl,al
    	call delay_20ms
    	in al,port1b
    	cmp al,bl
    	jne n9
		
	in al,port1b
	cmp al,01h
	jnz s3
	mov bl,second
	cmp bl,0
	jnz s4
	add bl,60
s4:	dec bl				;Decrement
	mov second,bl
	call display
	jmp s1
	
s3:	cmp al,02h
	jnz s1				;Increment
	mov bl,second
	inc bl
	cmp bl,60
	jnz s5
	mov bl,0
s5:	mov second,bl
	call display
	jmp s1

s2:	ret				

set_second endp




								;set_year
set_year proc near
    call display
ye1:	in al,port1c
	cmp al,04h
	jne ye2   
	
	    	in al,port1a			;Check format
		and al,01h		
		mov bl,format_check	
		cmp al,bl
		je n5		
		call display		;display if format changed
n11:   		
		in al,port1c		;check set_year  debounce
		cmp al,04h		
		jne ye2			
		in al,port1a		
		and al,01h
		mov bl,format_check
		cmp al,bl				
		je n12			
		call display

n12:	in al,port1b			;debounce for inc/dec
    	cmp al,00
    	je n11
    	mov bl,al
    	call delay_20ms
    	in al,port1b
    	cmp al,bl
    	jne n11	
    		
	in al,port1b
	cmp al,01h
	jne ye3
	mov bl,year
	cmp bl,00
	jne ye4
	inc bl
ye4:	dec bl				;Decrement
	mov year,bl
	call display
	jmp ye1
ye3:	cmp al,02h
	jne ye1
	mov bl,year
	
	cmp bl,99
	jne ye5
	dec bl					;Increment
ye5:	inc bl
	mov year,bl
	call display
	jmp ye1
ye2:	ret
set_year endp
					


	;set_alarm_hour		

set_alarm_hour proc near

mov alarm_hour,00				; default values of set_alarm hour
mov alarm_hour_12,12
mov alarm_phase,0
							
alh1:	
	in al,port1c				
	cmp al,02h
	jne alh2					;If set alarm hour is not selected, end.
	
	in al,port1a				;Checking alarm on or off
	and al,10h					
	cmp al,10h				
	jne alh2					
	
	call alarm_display				
	
	    in al,port1a			;Check format
		and al,01h		
		mov bl,format_check	
		cmp al,bl
		je n13		
		call alarm_display		;display if format changed
n13:   		
		in al,port1c		;check set_alarm_hour  debounce
		cmp al,02h		
		jne alh2			
		in al,port1a		
		and al,01h
		mov bl,format_check
		cmp al,bl				
		je n14			
		call alarm_display

n14:	    in al,port1b			;debounce for inc/dec
    	cmp al,00
    	je n13
    	mov bl,al
    	call delay_20ms
    	in al,port1b
    	cmp al,bl
    	jne n13			
										
	in al,port1b				
	cmp al,01h					
	jnz alh3						
	mov bl,alarm_hour		
	dec bl						;decrement alarm_hour
	cmp bl,00
	jge alh5
	mov bl,23					; if the hour becomes less than 0, make it 23
	
alh5: 
	mov alarm_hour,bl
								;12hr format
	mov al,alarm_hour
		cmp al,00
		jne alha1
		mov alarm_hour_12 , 12
		mov alarm_phase,0
		jmp exita1
alha1:		
		cmp al,12
		jne alha4
		mov alarm_hour_12,12
		mov alarm_phase,1				
		jmp exita1
alha4:		cmp al,12
		ja alha2
		mov alarm_hour_12,al
		mov alarm_phase,0
		jmp exita1
alha2:		sub al,12
		mov alarm_hour_12,al	
		mov alarm_phase,1
							;end
exita1:	call alarm_display				
		jmp alh1						
alh3:		cmp al,02h								
		jne alh1
		mov bl,alarm_hour
		inc bl
		cmp bl,24
		jb alh6
		mov bl,00
alh6:		mov alarm_hour,bl
		;12hr
		mov al,alarm_hour
		cmp al,00
		jne alhb1						
		mov alarm_hour_12 , 12
		mov alarm_phase,0
		jmp exita2
alhb1:		cmp al,12
		jne alhb4
		mov alarm_hour_12,12
		mov alarm_phase,1
		jmp exita2
alhb4:		cmp al,12
		ja alhb2
		mov alarm_hour_12,al
		mov alarm_phase,0
		jmp exita2
alhb2:		sub al,12
		mov alarm_hour_12,al	
		mov alarm_phase,1
								;end
exita2:	call alarm_display
		jmp alh1				
	
alh2:	ret							

set_alarm_hour endp

								;set_alarm_min 
set_alarm_min proc near
	mov alarm_min,00
	
al1:	in al,port1a
		and al,10h					;checking if set_alarm minute is on
		cmp al,10h	
		jne al2						;end if off
		in al,port1c
		cmp al,01h
		jnz al2 						
		call alarm_display				
		
		in al,port1a			;Check format
		and al,01h		
		mov bl,format_check	
		cmp al,bl
		je n15		
		call alarm_display		;display if format changed
n15:   		
		in al,port1c		;check set_alarm_min  debounce
		cmp al,01h		
		jne al2			
		in al,port1a		
		and al,01h
		mov bl,format_check
		cmp al,bl				
		je n16			
		call alarm_display

n16:	    in al,port1b			;debounce for inc/dec
    	cmp al,00
    	je n15
    	mov bl,al
    	call delay_20ms
    	in al,port1b
    	cmp al,bl
    	jne n15
		 
		in al,port1b					
		in al,port1b
		cmp al,01h					; decrement
		jnz al3
		mov bl,alarm_min
		dec bl
		cmp bl,00
		jge al5
		mov bl,59
al5:		mov alarm_min,bl
		call alarm_display
		jmp al1						
al3:		cmp al,02h
		jne al1						;increment
		mov bl,alarm_min
		inc bl
		cmp bl,60
		jne al6
		mov bl,00
al6:		mov alarm_min,bl
		call alarm_display
		jmp al1						
al2:		ret

								

		set_alarm_min endp
;end of set_alarm_min 


	; procedure to make the buzzer ring in the required sequence for an iPhone alarm(Notes: GGA#CCA#GCFCA#CF): One sequence takes approx. 3 secs
buzzer proc near
		mov al,alarm_hour							
		mov ah,hour					
		cmp al,ah						;if current hour != alarm_hour, then ret
		jne esc1						;else, check min
		
		mov al,alarm_min				; if current min is not equal to alarm_min, then ret
		mov ah,min						; else, ring buzzer
		cmp al,ah
		jne esc1
							
								 
							                            
buzz:		
		in al,port1a				;check if alarm on 	
		and al,10h
		cmp al,10h					
		jne esc1					; if not on, ret
		mov ah,min					 
		cmp ah,alarm_min
		jne esc1			        ; end if alarm_min not = min
		mov al,00h						
		out port2a,al		
		
		
		push cx
		
		mov cx, 10
	pause:								; pause for 20ms
		call delay_20ms
		loop pause
		; pop cx
		
		
	    mov al, 04h
		out port2a, al
		; push cx
		mov cx, 10
	G1:	
		call delay_20ms
		loop G1
		; pop cx  
		mov al,00h						
		out port2a,al
		call delay_20ms
		call delay_20ms
		call delay_20ms
		mov al, 04h					; ring the buzzer of note G for 200ms and pause
		out port2a, al
		
		mov cx, 10
	G2:	
		call delay_20ms
		loop G2
		
		mov al,00h						
		out port2a,al
		call delay_20ms
		call delay_20ms
		mov al, 2					; ring the buzzer of note G for 200ms and pause
		out port2a, al
		
		mov cx, 10
	A#1:	
		call delay_20ms
		loop A#1
		
		mov al,00h						
		out port2a,al
		call delay_20ms
		mov al, 1					; ring the buzzer of note A# for 200ms and pause
		out port2a, al
		
		mov cx, 10
	C1:	
		call delay_20ms
		loop C1
		
		mov al,00h						
		out port2a,al
		call delay_20ms
		mov al, 1					; ring the buzzer of note C for 200ms and pause
		out port2a, al
		
		mov cx, 10
		
	C2:	
		call delay_20ms
		loop C2
		
		mov al,00h						
		out port2a,al
		call delay_20ms
		mov al, 2					; ring the buzzer of note C for 200ms and pause
		out port2a, al
		
		mov cx,10
	
	A#2:	
		call delay_20ms
		loop A#2
		
		mov al,00h						
		out port2a,al
		call delay_20ms
		mov al, 4					; ring the buzzer of note A# for 200ms and pause
		out port2a, al
	
		mov cx, 10
	G3:	
		call delay_20ms
		loop G3   
		
		mov al,00h						
		out port2a,al
		call delay_20ms
		mov al, 1					; ring the buzzer of note G for 200ms and pause
		out port2a, al
		
		mov cx, 10
	C3:	
		call delay_20ms
		loop C3
		 
		mov al,00h						
		out port2a,al
		call delay_20ms
		mov al, 8					; ring the buzzer of note C for 200ms and pause
		out port2a, al
		
		mov cx, 10
	F1:	
		call delay_20ms
		loop F1
		 
		mov al,00h						
		out port2a,al
		call delay_20ms
		mov al, 1					; ring the buzzer of note F for 200ms and pause
		out port2a, al
		
		mov cx, 10
	C4:	
		call delay_20ms
		loop C4 
		
		mov al,00h						
		out port2a,al
		call delay_20ms
		mov al, 2					; ring the buzzer of note C for 200ms and pause
		out port2a, al
		
		mov cx, 10
	A#3:	
		call delay_20ms
		loop A#3
		
		mov al,00h						
		out port2a,al
		call delay_20ms
		mov al, 1					; ring the buzzer of note A# for 200ms and pause
		out port2a, al
		
		mov cx, 10
	C5:	
		call delay_20ms
		loop C5
		
		mov al,00h						
		out port2a,al
		call delay_20ms
		mov al, 8					; ring the buzzer of note C for 200ms and pause. Ring the buzzer of note F for 200ms and check if alarm_min= min
		out port2a, al
		
		mov cx, 10
	F2:	
		call delay_20ms
		loop F2
		
		pop cx
		
		jmp buzz						; if min == alarm_min, keep rining the buzzer
		
esc1:		mov al,00h
		out port2a,al				;Stop buzzer sound
	
		ret
buzzer endp	

alarm_display proc near
	
	;input format
	in al,port1a
	and al,01h
	mov format_check,al
	
	;clear screen
		mov al,01h
		out port2b,al
		mov al,01h
		out port2c,al
		mov al,00h
		out port2c,al
		call delay_20ms
		
	; display hour 
	;check format
		mov al,format_check
		cmp al,1
		jne ahr12
		
		;display alarm_hour_24
		mov al,alarm_hour
		mov       bl,al 
	    mov       al,0          ; converting hex to dec value
x8:		add       al,01
	    daa
	    dec       bl
	    jnz       x8
		mov digit,al
		
		and al,0f0h
		mov cl,4
		rol al,cl
		add al,30h
		
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		mov al,digit
		and al,0fh
		add al,30h
		
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		;display alarm_hour_24 completed
		
		jmp skip3
		
		;display alarm_hour_12
ahr12:	
		mov al,alarm_hour_12
		mov       bl,al 
	    mov       al,0          ; converting hex to dec value
x9:		add       al,01
	    daa
	    dec       bl
	    jnz       x9
		mov digit,al
		
		and al,0f0h
		mov cl,4
		rol al,cl
		add al,30h
		
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		mov al,digit
		and al,0fh
		add al,30h
		
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		;display alarm_hour_12 completed
		
		;displaying ':'
skip3:	mov al,3ah
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		;display alarm_min 
		
		mov al,alarm_min
		mov       bl,al 
	    mov       al,0          ; converting hex to dec value
x10:	add       al,01
	    daa
	    dec       bl
	    jnz       x10
		mov digit,al
		
		and al,0f0h
		mov cl,4
		rol al,cl
		add al,30h
		
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		mov al,digit
		and al,0fh
		add al,30h
		
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		;display alarm_min end
		
		;check format
		mov al,format_check
		cmp al,1
		je skip4
		
		
		mov al,20h
		out port2b, al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		;check if am/pm
		mov al,alarm_phase
		cmp al,1
		je apm1
		
		;display 'am'
		mov al,41h
		out port2b, al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		mov al,4dh
		out port2b,al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		jmp skip4 
		;display 'pm'
apm1:	mov al,50h
		out port2b, al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms
		
		mov al,4Dh
		out port2b, al
		mov al,11h
		out port2c,al
		mov al,10h
		out port2c,al
		call delay_20ms

skip4:	ret
alarm_display endp



stat db 00h
;count values
	count_sec db 60
	count_min db 60
	count_hour db 24
	count_day db 30
	count_month db 12
	second db 0
	min db 0
	hour db 0
	day db 01
	month db 01
	year db 13
	digit db 0
	year_mod db 0 
	format_check db 0
	hour_12 db 0 
	phase db 0    
	
;alarm values
	alarm_hour db 0 
	alarm_hour_12 db 0
	alarm_min db 0
	alarm_phase db 0 
	
		


HLT           ; halt!


