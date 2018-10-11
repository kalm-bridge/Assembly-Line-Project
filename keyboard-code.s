.global _start
_start:

.equ KEYBOARD, 0xFF200100
.equ ADDR_7SEG1, 0xFF200020
.equ ADDR_7SEG2, 0xFF200030

.data
storedInput1:
.byte 0
storedInput2:
.byte 0
storedInput3:
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

.text
.global _start
_start:

#initialise
movia sp, 0x03FFFFFC
movia r8, KEYBOARD


turn_on_interrupts:
#write one to enable read interrupts on keyboard
movia r5, 0x01
stwio r5, 4(r8)

movui r15, 0x0080
wrctl ctl3, r15
movi r15, 1
wrctl ctl0, r15 #INTERRUPTS ARE ON


#hex display
DisplayOnHex:
movia r2,ADDR_7SEG1
movia r3, ADDR_7SEG2

movia r5, PATTERNS
mov r8, r0
movia r4, storedInput1
movi r6, 0x03
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
srli r8, r8, 8
stwio r8, 0(r2)
br DisplayOnHex

.section .exceptions, "ax"

#you check if the queue is full; if not full, write into the data section
exception_handler:
subi sp, sp, 28
stw r9, 0(sp)
stw r10, 4(sp)
stw r8, 8(sp)
stw r12, 12(sp)
stw r13, 16(sp)
stw r14, 20(sp)
stw r11, 24(sp)


handler:
rdctl et, ctl4
movia r8, 0x00000080
and et, et, r8
beq et, r8, keyboard_interrupt
br exit

keyboard_interrupt:
#get the data from the 0:7 bits of the base, store it into r9
movia r8, KEYBOARD
ldwio r9, 0(r8)
movi r10, 0x00FF
and r9, r9, r10

#make sure the entered key was valid input
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

subi ea, ea, 4
eret

