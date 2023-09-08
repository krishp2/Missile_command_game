# mp1.S - missile-command version
# Good luck, and have fun!

.data
	
    # Constants for accessing the fields of a struct missile, 
    # struct missile is defined in rtc.h and mp1.h

	NEXT 	  = 0
	X	  = 4
	Y	  = 8
	VX	  = 12
	VY	  = 16
	DEST_X	  = 20
	DEST_Y	  = 24
	EXPLODED  = 28
	C	  = 32

    # Character to draw for an explosion - '@'

	EXPLOSION = 64


# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

mp1_missile_list:	.long 0x0	# Head of list pointer
base_alive:		.long 0x0	# Array of 3 bytes, plus a padding byte
mp1_score:		.long 0x0	# Player's current score


# Data private to this  file

base_pic:     	    .string "/^^^\\"	# Picture of a live base
dead_base_pic: 	    .string "xxxxx"	# Picture of a dead base
crosshairs_x:		.long 0x0	# X-position of the crosshairs
crosshairs_y:		.long 0x0	# Y-position of the crosshairs

.text

# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX 

mp1_poke:
		movl    vmem_base_addr(,1),%edx
		movb    %cl,(%edx,%eax,1)
		ret

#   ----------------- Exported functions ---------------------

# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#	(1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#	(2) Redraw the bases - they may have been overwritten with missiles
#	(3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention

.globl mp1_rtc_tasklet
mp1_rtc_tasklet:
	 

	pushl %eax
	pushl %ecx 
	call update_missiles
	add $8, %esp  
	
	pushl %eax
	pushl %ecx 
	pushl %edx 
	pushl %edi
	pushl %esi 
	call Redraw_base
	add $20, %esp 

	pushl %eax
	pushl %ecx 
	pushl %edx 
	pushl %edi
	pushl %esi 
	call Redraw_crosshairs
	add $20, %esp 

		ret

# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function 
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

.globl mp1_ioctl
mp1_ioctl:
		ret


# ----------------- Functions private to this file -------------------
# First, your tasklet should walk down the struct missile linked list. For each missile, you should check whether
# it is currently exploding. If not, then you should update the x and y fields as explained above in the “MP1 Data
# Structure” section. There are then three cases based on the state and position of the missile.
# Processing a missile requires three steps. First, if the missile has moved off of the screen (that is, its screen x coordinate
# is outside of the range 0-79 or its y coordinate is out of the range 0-24), then the missile should be erased from the
# screen, removed from the linked list, and its struct missile freed with mp1 free (see “Allocating and Freeing
# Memory”). Removing a missile from the list should be implemented as a separate function since you may need to
# perform this operation in more than one place in the code (possibly outside of the tasklet). In this document, we will
# refer to this function as mp1 missile remove, though you may name it whatever you chose.


update_missiles:
	movl NEXT(mp1_missile_list), %ecx # ecx --> Next missle
	
	movl EXPLODED(%ecx), %esi # esi -> exploded
	cmpl $0, %esi # missle not exploded 
	je no_update_x_y
	# idk what to do if it is not
	movw X(%ecx), %edx # edx --> x
	movw VX(%ecx), %ebx # ebx --> VX
	addw %ebx, %edx
	movw %edx, X(%ecx)
	movw Y(%ecx), %edi # edi --> y
	movw VY(%ecx), %ebx # ebx (resused)--> VY
	addw %ebx, %edi
	movw %edi, Y(%ecx)

	pushl %eax
	pushl %edx
	pushl %edi
	
	call stage_1

	add $12, %esp

#------- stage 2 -------
	pushl %eax
	pushl %edx
	pushl %edi
	pushl %esi

	call stage_2

	add $12, %esp
	
#----- stage 3 --------



no_update_x_y

		ret



stage_1:
	movw X(%ecx), %edx # %edx -> x 
	movw Y(%ecx), %edi # %edi -> y
	cmpw $0, %edx # x<0
	jl OUT_of_bound
	cmpw $0, %edi # y<0
	jl OUT_of_bound
	cmpw $79,%edx # x>76
	jg OUT_of_bound
	cmpw $24, %edi # y>24
	jg OUT_of_bound

OUT_of_bound
	#call mp1_missile_remove
	ret

stage_2:
	cmpw DEST_X(%ecx), %edx
	jne NOT_reached
	cmpw DEST_Y(%ecx), %edi
	jne NOT_reached
	# still exploding ????
	pushl %eax
	pushl %ecx
	call missile_explode
	add $8, %esp

	# decrement exploded for missle
	movl EXPLODED(%ecx), %esi # esi -> exploded
	subl $1 ,%esi
	cmpl $0, %esi
	je skip_SHOW_EXPLOSION
	# call remove 
	movl EXPLOSION(%ecx), %cl
	pushl %edx
	pushl %eax
	pushl %cl
	call mp1_poke
	add $12, %esp

skip_SHOW_EXPLOSION
NOT_reached
	ret

stage_3:
	ret

Redraw_base:

		ret

Redraw_crosshairs:
		ret


#    while (temp != NULL && temp->data != key) {
#        prev = temp;
#        temp = temp->next;
#    }

#    // Unlink the node from linked list
#    prev->next = temp->next;
  
#   free(temp); // Free memory
mp1_missile_remove:
	# head condition to be put (use the mp1_list_ head pointer)
	movl %ecx, %esi # temp vairiable
	cmpl $mp1_missile_list,%esi
	jne not_head
	movl NEXT(%ecx), %edi # edi -> temp next
	# delete %ecx
	movl %edi, %ecx
not_head
    movl NEXT(%esi), %esi
	cmpl %ecx, NEXT(%esi)
	jne not_head
	movl %esi 


		ret

mp1_ioctl_startgame:
		ret

mp1_ioctl_addmissile:
		ret

mp1_ioctl_movexhairs:

mp1_ioctl_startgame:
	pushl %ebp
	movl %esp, %ebp 
	pushl %ebx
	pushl %esi
	pushl %edi

	movl $40, crosshairs_x
	movl $12, crosshairs_y
	movl $0, mp1_missile_list
	movl $0, mp1_score
	movl $BASE_n, base_alive

	popl %ebx
	popl %esi
	popl %ebx
	leave
		ret

mp1_ioctl_addmissile:
	
		ret

mp1_ioctl_movexhairs:
	pushl %ebp
	movl %esp, %ebp 
	pushl %ebx
	pushl %esi
	pushl %edi

	movl (crosshairs_x),%ebx  # edx -> x
	movl (crosshairs_y),%esi # esi -> y	

	imul $160, %esi
	imul $2, %ebx
	addl %esi,%ebx
	movl %ebx, %eax
	movb $0x20,%cl # print space
	
	pushl %edx
	call mp1_poke
	popl %edx

	movl 8(%ebp), %ebx # ebx -> local variable

	movl %ebx, %esi 
	movswl %bx , %ebx # high 16 ebx -> x +
	sarl  $16, %esi # %esi -> y +
	
	movl (crosshairs_x), %edi 
	addl %edi , %ebx
	movl (crosshairs_y), %ecx
	addl %ecx, %esi

	cmpl $0, %ebx # x<0
	jnl skip_checky
	movl $0, %ebx
skip_checky:

	cmpl $79,%ebx # x>76
	jng skip_checky2
	movl $79, %ebx
	
skip_checky2:
	
	cmpl $0, %esi # y<0
	jnl skipy
	movl $0, %esi
skipy:
	cmpl $24, %esi # y>24
	jng skipy2
	movl $24, %esi
skipy2:

	movl %ebx , crosshairs_x
	movl %esi, crosshairs_y

	imul $160, %esi
	imul $2, %ebx
	addl %ebx, %esi
	movl %esi, %eax
	movb $43, %cl
	pushl %edx
	call mp1_poke
	popl %edx

	popl %ebx
	popl %esi
	popl %ebx
	movl $0, %eax
	leave
		ret

mp1_ioctl_getstatus:
		ret

mp1_ioctl_endgame:
		ret
