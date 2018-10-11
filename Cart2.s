/* sample interrupt routine for port (GPIO-JP1)*/

.equ GPIO_JP1,	 0xff200060         /*GPIO_JP1*/
.equ ADDR_JP1_IRQ, 0x0800           /* IRQ line for GPIO JP1 (bit 11) */
.equ ADDR_JP1_Edge, 0xff20006C      /* address Edge Capture register GPIO JP1 */
.equ KEYBOARD, 0xFF200100
.equ ADDR_7SEG1, 0xFF200020
.equ ADDR_7SEG2, 0xFF200030
.equ TIMER, 0xFF202000
.equ PERIOD, 6250000


.global Motors
.data
Motors:
m0_direction:
.byte 0
m1_direction:
.byte 0
cart_count:
.byte 0
crane_count:
.byte 0
motor_crane_flag:
.byte 0
instruction_flag:
.byte 0
storedInput1:
.byte 0
storedInput2:
.byte 0
storedInput3:
.byte 0
storedInput4:
.byte 0
storedInput5:
.byte 0
 
# Store the 7-segment pattern
PATTERNS:
.byte  0x3f                   /* 0 */
.byte  0x06                   /* 1 */
.byte  0x5b                   /* 2 */
.byte  0x4f                   /* 3 */
.byte  0x66                   /* 4 */
.byte  0x6d                   /* 5 */
.byte  0x7d                   /* 6 */
.byte  0x07                   /* 7 */
.byte  0xff                   /* 8 */
.byte  0x6f                   /* 9 */
.byte  0x77                   /* A */
.byte  0xfc                   /* B */
.byte  0x39                   /* C */
.byte  0x5e                   /* D */
.byte  0xf9                   /* E */
.byte  0xf1                   /* F */
.byte  0x50					  /* r */
.byte  0x40					  /* - */
 
.global _start

/********************** main program ************************/
.text
_start:

 movia 	sp, 0x03FFFFFC		  	/* initialize the stack pointer to top of NIOS memory*/
setup_devices:
 movia r9, TIMER
 movui r15, %lo(PERIOD)
 stwio r15, 8(r9)
 movui r15, %hi(PERIOD)
 stwio r15, 12(r9)
 movui r15, 0x07 #enable timer interrupts
 stwio r15, 4(r9)

 movia  r10, GPIO_JP1                    /* load GPIO JP2 into r10 */
 movia  r15, 0x07f557ff
 stwio  r15, 4(r10)                 	/* set direction register for motors and sensors */           
            
 movia  r15, 0xffffffff            	/* set all motors off and disable all sensors */
 stwio  r15, 0(r10)

 movia r8, KEYBOARD
 movia r5, 0x01
 stwio r5, 4(r8)
 
#load threshold value into sensors
#sensor 0

 movia  r15,0xfe3ffbff		/* load threshold value HEX A for sensor 1 on lego controller*/
 stwio r15,0(r10)		        

#sensor 1

 movia  r15,0xfe3fefff		/* load threshold value HEX A for sensor 2 on lego controller*/
 stwio r15,0(r10)	


 movia  r15,0xffdfffff           /* turn on state mode */		   
 stwio  r15, 0(r10) 
	
	

#enable interrupts DE2 boards

movia	r15,0xf8000000
 stwio	r15,8(r10)		        /* Enable sensor1-5 interrupts */

turn_on_interrupts:
 movia  r15,ADDR_JP1_IRQ	      /* enable bit 11 interrupts(GPIO JP1) on NIOS processor*/
 ori r15, r15, 0x0001
 ori r15, r15, 0x0080		#keyboard interrupt
 wrctl	ctl3,r15			

 movia 	r15,1
 wrctl 	ctl0,r15			        /* enable global interrupts*/
 
#  main routine

main_motor_loop:

  movia  r10, GPIO_JP1              	/* load GPIO JP2 into r10 */
  movia  r14, Motors        	/* load low 4 HEX display into r4*/
  
  ldwio	r13,0(r10)
  srli   r13,r13,27
  andi	r13,r13,0x01f
  ldhu r15, 0(r14)
               
  cmpeqi r12,r13,0x01f             	/*check m0 foward m1 foward */
  movia r13, 0xffdffff0
  bne r12, r0, set_motors
  	
  cmpeqi	r12,r15,0x0101             	/*check m0 backwards m1 backwards*/
  movia r13, 0xffdffffa
  bne r12, r0, set_motors
  
  cmpeqi	r12,r15, 0x0001             	/*check  m0 backwards m1 foward*/
  movia r13, 0xffdffff2
  bne r12, r0, set_motors			
  	
  cmpeqi	r12,r15, 0x0100             	/*check  m0 foward m1 backwards*/
  movia r13, 0xffdffff8
  bne r12, r0, set_motors 
  
  set_motors:
  #movia r13, 0xffdffff0
  movia r14, storedInput5
  ldbu r15, 0(r14)
  #cmpeqi r12, r15, 0x
  stwio r13, 0(r10)
 br check_cart_count

 check_cart_count:
 movia r13, cart_count
 ldbu r13, 0(r13)
 cmplei r11, r13, 0x01
 bne r11, r0, main_motor_loop
 beq r11, r0, turn_off_motors
 
 turn_off_motors:
 movia  r10, GPIO_JP1
 movia r13, 0xffdfffff
 stwio r13, 0(r10)
 br do_somethingelse

 do_somethingelse:
 call show_keyboard_input
 br check_cart_count



 /* interrupt routine*/
.section .exceptions, "ax"

IHANDLER:

 subi	sp,sp, 24
 stw	r10,0(sp)
 stw 	r3,4(sp)		        /* save registers for main routine */
 stw 	r4,8(sp)
 stw 	r5,12(sp)
 stw    r7,16(sp)
 stw	ra,20(sp)
 
 rdctl  et,ctl4
 beq	et, r0,exit_handler		/* check if valid interrupt */

 movia r7, 0x00000080
 and r5, et, r7
 beq r5, r7, is_keyboard
 movia 	r7, ADDR_JP1_IRQ	    	/* check to make sure GPIO_JP1 interrupt*/
 and	r5, et,r7
 beq	r5, r7, is_sensor
 movi	r7, 0x01
 and   r5, et, r7
 beq	r5, r7, is_timer
 br exit_handler

 is_timer:
 call HandleTimer
 br exit_handler

 is_sensor:
 call HandleMotor
 br exit_handler
 
 is_keyboard:
 call HandleKeyBoard
 br exit_handler

 
 
exit_handler:

 ldw	r10,0(sp)	       		/* reload value from regular routine*/
 ldw	r3,4(sp)
 ldw	r4,8(sp)
 ldw	r5,12(sp)
 ldw    r7,16(sp)
 ldw	ra,20(sp)
 addi  	sp,sp,24
 
 subi	ea,ea,4
 eret			       	    	/* return from interrupt routine */


 
.section .text
/*TIMER INTERRUPTS*/
HandleTimer:
 subi	sp,sp, 20
 stw	r10,0(sp)
 stw 	r3,4(sp)		        /* save registers for HandleTimer routine */
 stw 	r4,8(sp)
 stw 	r5,12(sp)
 stw    r7,16(sp)

 movia r3, TIMER
 stwio r0, 0(r3) #acknowledge timer
 movia r3, cart_count
 ldbu r4, 0(r3)
 cmplei et,r4, 0x03
 bne et, r0, add_one
 stb r0, 0(r3)
 br exit_HandleTimer
 add_one:
 addi r4, r4, 1 
 stb r4, 0(r3)
 
 exit_HandleTimer:

 ldw	r10,0(sp)	       		/* reload value from regular routine*/
 ldw	r3,4(sp)
 ldw	r4,8(sp)
 ldw	r5,12(sp)
 ldw    r7,16(sp)
 addi  	sp,sp,20
 ret

  /*MOTOR INTERRUPTS*/
HandleMotor:
 subi	sp,sp, 20
 stw	r10,0(sp)
 stw 	r3,4(sp)		        /* save registers for HandleMotor routine */
 stw 	r4,8(sp)
 stw 	r5,12(sp)
 stw    r7,16(sp)

 movia	r7,ADDR_JP1_Edge	    	/* clear all interrupts on GPIO-JP1. Must write to all ports */
 movia	r3,0xffffffff
 stwio	r3,0(r7)
 
 
 movia  r10,GPIO_JP1             	/* load GPIO JP1 into r10*/
 ldwio	r4,0(r10)
 srli   r4,r4,27
 andi	r4,r4,0x01f
 cmpeqi r5,r4,0x01f
 bne	r5,r0,forward	    	/*false interrupt*/
 	
 check_sensors:	
 cmpeqi	r5,r4,0x01e             	/*check sensor 1 */
 bne	r5,r0,steer_away_S0
 cmpeqi	r5,r4,0x01d
 bne	r5,r0,steer_away_S1
 cmpeqi r5, r4, 0x01c
 bne    r5, r0,reverse
 #movia r7, Motors
 #sth r0, 0(r7)
 #movia r13, 0xffdffff0
 br load
 
 steer_away_S0:
 movia r7, Motors
 movi r5, 0x0100
 #movia r5, 0xffdffff8
 sth r5, 0(r7)
 br	load		       		
 
 steer_away_S1:
 movia r7, Motors
 movi r5, 0x0001
 #movia r5, 0xffdffff2
 sth r5, 0(r7)
 br	load
 
 reverse:
 movia r7, Motors
 movi r5, 0x0101
 #movia r5, 0xffdffffa
 sth r5, 0(r7)
 br	load
 
 forward:
 movia r7, Motors
 sth r0, 0(r7)
 br load
  
 load:
 /*movia r3, GPIO_JP1
 stwio  r5, 0(r3)           /* turn on one of the motors based on value in r7  
 ldwio	r4, 0(r3)
 srli   r4,r4,27
 andi	r4, r4,0x01f
 cmpeqi r7, r4,0x01f	       		check if interrupt has end*/
 #bne	r7, r0,exit_HandleMotor

 #br	load

 exit_HandleMotor:

 ldw	r10,0(sp)	       		/* reload value from regular routine*/
 ldw	r3,4(sp)
 ldw	r4,8(sp)
 ldw	r5,12(sp)
 ldw    r7,16(sp)
 addi  	sp,sp,20
 ret

/* KEYBOARD INTERRUPTS*/
HandleKeyBoard:

  subi sp, sp, 28
  stw r9, 0(sp)
  stw r10, 4(sp)
  stw r8, 8(sp)
  stw r12, 12(sp)
  stw r13, 16(sp)
  stw r14, 20(sp)
  stw r11, 24(sp)
  
  
  keyboard_interrupt:
  #get the data from the 0:7 bits of the base, store it into r9
  movia r8, KEYBOARD
  ldwio r9, 0(r8)
  movi r10, 0x00FF
  and r9, r9, r10
  
  #make sure the entered key was valid input
  movui r12, 0x000D
  beq r12, r9, is_tab
  movui r12, 0x0076
  beq r12, r9, clear
  movui r12, 0x001C
  movui r13, 0x001B
  movui r14, 0x0023
  beq r12, r9, WriteStoredInput
  beq r13, r9, WriteStoredInput
  beq r14, r9, WriteStoredInput
  br exit
  
  #write the received key into the data allocated in the data section, check if the first storedinput byte is a 0; if yes then write the value into it
  
  
  clear:
  movia r10, storedInput1
  stb r0, 0(r10)
  stb r0, 1(r10)
  stb r0, 2(r10)
  br exit
  
  #write the received key into the data allocated in the data section, check if the first storedinput byte is a 0; if yes then write the value into it
  
  WriteStoredInput:
  movia r10, storedInput1
  ldb r11, 0(r10) #r11 contains the key pressed
  beq r0, r11, writedata
  beq r9, r11, exit
  
  movia r10, storedInput2
  ldb r11, 0(r10)
  beq r0, r11, writedata
  beq r9, r11, exit
  
  movia r10, storedInput3
  ldb r11, 0(r10)
  beq r0, r11, writedata
  beq r9, r11, exit
  
  br exit
  
  writedata:
  stb r9, 0(r10)
  br exit
  
  is_tab:
  
  br exit
  
  exit:
  
  #restore registers
  ldw r9, 0(sp)
  ldw r10, 4(sp)
  ldw r8, 8(sp)
  ldw r12, 12(sp)
  ldw r13, 16(sp)
  ldw r14, 20(sp)
  ldw r11, 24(sp)
  addi sp, sp, 28
  
ret

/*~~~~~~~~~~~~~~~~~~~~~SHOW KEYBOARD OUTPUT~~~~~~~~~~~~*/
show_keyboard_input:

 subi	sp,sp, 32
 stw	r10,0(sp)
 stw 	r9,4(sp)		        /* save registers for HandleMotor routine */
 stw 	r8,8(sp)
 stw 	r5,12(sp)
 stw    r6,16(sp)
 stw	r4,20(sp)
 stw	r11,24(sp)
 stw	r2,28(sp)

 DisplayOnHex:
  movia r2,ADDR_7SEG1
  movia r3, ADDR_7SEG2
  
  movia r5, PATTERNS
  mov r8, r0
  movia r4, storedInput1
  movi r6, 0x04
  DIGIT_LOOP:
  #get the digit to display using and
  #load it into a diff register and display to hex
  
  
  ldbu r10, 0(r4)
  andi  r10, r10, 0x0F        /* Get the current digit */
  
  
  cmpeqi r9, r10, 0x00
  bne r9, r0, LOAD_Display0
  cmpeqi r9, r10, 0x0C
  bne r9, r0, LOAD_DisplayA #if r9 = 1, then the current digit was a C
  cmpeqi r9, r10, 0x0B
  bne r9, r0, LOAD_DisplayS
  cmpeqi r9, r10, 0x03
  bne r9, r0, LOAD_DisplayD
  
  LOAD_Display0:
  ldbu  r11, 0(r5)    #load the 7-Seg format
  #stbio r11, 0(r2)           #store to 7-seg display
  br loadPattern
  
  LOAD_DisplayA:
  ldbu  r11, 10(r5)    #load the 7-Seg format
  #stbio r11, 1(r2)           #store to 7-seg display
  br loadPattern
  
  LOAD_DisplayS:
  ldbu  r11, 5(r5)    #load the 7-Seg format
  #stbio r11, 2(r2)           #store to 7-seg display
  br loadPattern
  
  LOAD_DisplayD:
  ldbu  r11, 13(r5)    #load the 7-Seg format
  #stbio r11, 3(r2)           #store to 7-seg display
  br loadPattern
  
  loadPattern:
  or	r8,  r8, r11		/* Include the new digit */
  roli  r8,  r8, 24			/* Rotate the digit in the correct position */
  
  addi  r4,  r4, 1			/* Go to the next digit */
  
  subi  r6,  r6, 1			/* Decrement loop counter */
  bgtu  r6,  r0, DIGIT_LOOP	/* Loop if more digits need to be converted */
  #srli r8, r8, 8
  stwio r8, 0(r2)
  
  movia r5, PATTERNS
  mov r8, r0
  movia r4, storedInput5
  movi r6, 0x02
  DIGIT_LOOP2:
  #get the digit to display using and
  #load it into a diff register and display to hex
  
  
  ldbu r10, 0(r4)
  andi  r10, r10, 0x0F        # Get the current digit 
  
  
  cmpeqi r9, r10, 0x00
  bne r9, r0, LOAD2_Display0
  cmpeqi r9, r10, 0x0C
  bne r9, r0, LOAD2_DisplayA #if r9 = 1, then the current digit was a C
  cmpeqi r9, r10, 0x0B
  bne r9, r0, LOAD2_DisplayS
  cmpeqi r9, r10, 0x03
  bne r9, r0, LOAD2_DisplayD
  
  LOAD2_Display0:
  ldbu  r11, 0(r5)    #load the 7-Seg format
  #stbio r11, 0(r2)           #store to 7-seg display
  br load2Pattern
  
  LOAD2_DisplayA:
  ldbu  r11, 10(r5)    #load the 7-Seg format
  #stbio r11, 1(r2)           #store to 7-seg display
  br load2Pattern
  
  LOAD2_DisplayS:
  ldbu  r11, 5(r5)    #load the 7-Seg format
  #stbio r11, 2(r2)           #store to 7-seg display
  br load2Pattern
  
  LOAD2_DisplayD:
  ldbu  r11, 13(r5)    #load the 7-Seg format
  #stbio r11, 3(r2)           #store to 7-seg display
  br load2Pattern
  
  load2Pattern:
  or	r8,  r8, r11		# Include the new digit 
  roli  r8,  r8, 24			# Rotate the digit in the correct position 
  
  addi  r4,  r4, 1			# Go to the next digit 
  
  subi  r6,  r6, 1			# Decrement loop counter 
  bgtu  r6,  r0, DIGIT_LOOP2	# Loop if more digits need to be converted 
  srli r8, r8, 16
  stwio r8, 0(r3)
  
  ldw	r10,0(sp)	       		# reload value from regular routine
  ldw	r9,4(sp)
  ldw	r8,8(sp)
  ldw	r5,12(sp)
  ldw   r6,16(sp)
  ldw	r4,20(sp)
  ldw	r11,24(sp)
  ldw	r2,28(sp)
  addi  sp,sp,32
  
ret

get_stored_input:
  subi	sp,sp, 28
  stw	r10,0(sp)
  stw 	r9,4(sp)		        /* save registers for HandleMotor routine */
  stw 	r8,8(sp)
  stw 	r5,12(sp)
  stw    r6,16(sp)
  stw	r4,20(sp)
  stw	r11,24(sp)
  
  movia r4, storedInput1
  ldbu r2, 0(r4)	#collect the data in first
  movia r6, storedInput2
  ldbu r5, 0(r6)	#collect data in second
  stb r5, 0(r4)		#store it in first
  movia r8, storedInput3
  ldbu r9, 0(r8)	#collect data in third
  stb r9, 0(r6)		#store it in second
  stb r0, 0(r8)		#set third to zero
  

 
  ldw	r10,0(sp)	       		/* reload value from regular routine*/
  ldw	r9,4(sp)
  ldw	r8,8(sp)
  ldw	r5,12(sp)
  ldw   r6,16(sp)
  stw	r4,20(sp)
  stw	r11,24(sp)
  addi  sp,sp,28
ret

