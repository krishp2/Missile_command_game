
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
	CROSSHAIR = 43
	BASE_n = 0X00ffffff
	HIGH_BITS = 16
	LOW_8_BITS = 8
	Y_offset = 160
	x_offset = 2
	x_upper = 79
	y_upper = 24
	y_base_offser =3840





# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

mp1_missile_list:	.long 0x0	# Head of list pointer
base_alive:		.long 0x0	# Array of 3 bytes, plus a padding byte
mp1_score:		.long 0x0	# Player's current score
add_status:    .long 0x0



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
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx
	pushl %esi
	pushl %edi # calle setup

	pushl %eax
	pushl %ecx
	pushl %edx   # caller setup
	call update_missiles
	popl %edx
	popl %ecx
	popl %eax    # caller teardown 

	pushl %eax
	pushl %ecx
	pushl %edx # caller setup
	call Redraw_base
	popl %edx
	popl %ecx
	popl %eax # caller teardown 

	pushl %eax
	pushl %ecx
	pushl %edx # caller setup
	call Redraw_crosshairs
	popl %edx
	popl %ecx
	popl %eax # caller teardown 

	popl %edi
	popl %esi
	popl %ebx # calle teardown 
	leave
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

	movl LOW_8_BITS(%esp), %esi
	cmpl $0, %esi
	jl invalid_cmd
	cmpl $4, %esi
	jg invalid_cmd
	jmp *JUMPTABLE(, %esi, 4)

invalid_cmd:
	movl $-1,%eax

		ret
JUMPTABLE:
	.long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, mp1_ioctl_getstatus, mp1_ioctl_endgame
#---------------------------------------update-missile---------------------------------------------------------
# void mp1_redraw_base( )
# This functions makes 3 bases and prints it on the screen 
# inputs : void
# output : void
# registers : 
# ---------------------------------------------------------------------------------------------------

update_missiles:
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx
	pushl %esi
	pushl %edi 	# calle save

	movl mp1_missile_list, %ebx # ebx --> missle (dont change)

	loop_start_update_missile:
		cmpl $0, %ebx
		je end_missile
		

		movl X(%ebx), %edx # edx -> x
		movl Y(%ebx), %edi # edi -> y
		shrl $HIGH_BITS, %edx  # accesing the video mode 16 bits (high)
		shrl $HIGH_BITS, %edi  # accesing the video mode 16 bits (high)
		movl %edi, %eax 
		imul $Y_offset, %eax 
		imul $x_offset, %edx
		addl %edx, %eax  # calculating offset
		movl $0x20,%ecx # printing blank


		pushl %edx
		call mp1_poke
		popl %edx


		
		movl EXPLODED(%ebx), %edi # edi -> exploded
		cmpl $0, %edi # missle not exploded 
		jne currently_exploding  
		

		# ----- -------- sus -----update val????---------------------
		movl X(%ebx), %edx # edx --> x
		addl VX(%ebx), %edx # edx --> VX + X
		shrl $HIGH_BITS , %edx
		

		movl Y(%ebx), %edi # edi --> y
		addl VY(%ebx), %edi # edi --> VY + Y
		shrl $HIGH_BITS , %edi
		
		cmpl $0, %edx # x<0
		jl OUT_of_bound
		cmpl $0, %edi # y<0
		jl OUT_of_bound
		cmpl $x_upper,%edx # x>79
		jg OUT_of_bound
		cmpl $y_upper, %edi # y>24
		jg OUT_of_bound
		jmp all_good 


	OUT_of_bound:
		jmp mp1_missile_remove #remove if out of bounds

	all_good:
	
		movl VX(%ebx) , %edx
		addl %edx, X(%ebx) # update x

		movl VY(%ebx) , %edi
		addl %edi, Y(%ebx) # update y


		movl X(%ebx), %edx # %edx -> x 
		shrl $HIGH_BITS, %edx
		movl Y(%ebx), %edi # %edi -> y
		shrl $HIGH_BITS, %edi
		
		# check of reached destination or not
		cmpl DEST_X(%ebx), %edx # %edx -> dest_x
		jne NOT_reached2
		cmpl DEST_Y(%ebx), %edi # %edx -> dest_y
		jne NOT_reached2

	currently_exploding:

		movl X(%ebx), %edx # edx -> x
		movl Y(%ebx), %edi # edi -> y
		shrl $HIGH_BITS, %edx  # accesing the video mode 16 bits (high)
		shrl $HIGH_BITS, %edi  # accesing the video mode 16 bits (high)
		movl %edi, %eax 
		imul $Y_offset, %eax 
		imul $x_offset, %edx
		addl %edx, %eax # calculate offset
		xor %cl ,%cl
		movb $EXPLOSION, %cl # print explosion

		pushl %edx
		call mp1_poke
		popl %edx


		pushl %ebx
		pushl %edx
		pushl %ebx
		call missile_explode
		popl %ebx
		popl %edx
		popl %ebx

		
		
		cmpl $0 , %eax
		je skip_notify # skip notify user if missile_expode returns 0 
		pushl %edx
		call mp1_notify_user
		popl %edx

		

	skip_notify:
		movl EXPLODED(%ebx), %edi
		subl $1, %edi
		movl %edi, EXPLODED(%ebx) # update missile explode
		cmpl $0, %edi
		je pre_missile_remove # print a blank
		movl NEXT(%ebx), %ebx # iterate linked list
		jmp loop_start_update_missile  

	
	NOT_reached2:

		movl X(%ebx), %edx # edx -> x
		movl Y(%ebx), %edi # edi -> y
		shrl $HIGH_BITS, %edx # accesing the video mode 16 bits (high)
		shrl $HIGH_BITS, %edi # accesing the video mode 16 bits (high)
		movl %edi, %eax 
		imul $Y_offset, %eax 
		imul $x_offset, %edx
		addl %edx, %eax # calculating offset

		xor %cl ,%cl
		movb C(%ebx) , %cl # print missile

		pushl %edx
		call mp1_poke
		popl %edx 
		jmp end_missile_remove # next missile

	pre_missile_remove:
		movl X(%ebx), %edx # edx -> x
		movl Y(%ebx), %edi # edi -> y
		shrl $HIGH_BITS, %edx  # accesing the video mode 16 bits (high)
		shrl $HIGH_BITS, %edi  # accesing the video mode 16 bits (high)
		movl %edi, %eax 
		imul $Y_offset, %eax 
		imul $x_offset, %edx
		addl %edx, %eax
		movb $0x20,%cl  # calculating offset


		pushl %edx
		call mp1_poke
		popl %edx
	mp1_missile_remove:
	# jmp end_missile_remove 

		movl mp1_missile_list, %edx # edx -> temp
		cmpl mp1_missile_list, %ebx	 # check for head
		je remove_head

	loop_in:  
		movl NEXT(%edx), %esi	 # find pervious	
		cmpl %esi, %ebx	
		je loop_out
		movl NEXT(%edx), %edx
		jmp loop_in

	loop_out:
		movl NEXT(%ebx), %edi # update linked list with previous
		movl %edi, NEXT(%edx)
		movl %edi, %ebx

		pushl %esi
		call mp1_free
		addl $4, %esp

		jmp loop_start_update_missile 

	remove_head:
		movl mp1_missile_list, %esi	# remove head
		pushl %esi				
		movl NEXT(%esi), %esi		
		movl %esi, mp1_missile_list
		call mp1_free				
		addl $4, %esp
		movl mp1_missile_list, %ebx

	jmp loop_start_update_missile

	end_missile_remove:
		movl NEXT(%ebx), %ebx # iterate linked list
		jmp loop_start_update_missile

	end_missile:
		popl %edi
		popl %esi
		popl %ebx # calle teardown 
		leave
	ret
#-----------------------------------redraw_base----------------------------------------------------------
# void mp1_redraw_base( )
# This functions makes 3 bases and prints it on the screen 
# inputs : void
# output : void
# ---------------------------------------------------------------------------------------------------

Redraw_base:
	pushl %ebp
	movl %esp, %ebp 
	pushl %ebx
	pushl %esi
	pushl %edi  # calle save

	movl base_alive, %ebx # %ebx -> 4 byte array (dont alter)
	movl $1, %edx
	loop_start:
		cmpl $4, %edx # edx loop counter (dont alter)
		je loop_end
		movl $0, %esi
		
		cmpb $0, %bl # check if the base is dead or alive
		jne draw_base_alive
		

		movl $20, %eax # %eax -> 20 (first base)
		imul %edx, %eax
		subl $x_offset , %eax
		imul $x_offset, %eax
		addl $y_base_offser, %eax
		leal dead_base_pic, %edi
		shrl $LOW_8_BITS, %ebx # shift left 0x0000ff00 and 0x00ff0000

		jmp print_1


	draw_base_alive:
		movl $20, %eax # %eax -> 20 (first base)
		imul %edx, %eax
		subl $x_offset , %eax
		imul $x_offset, %eax
		addl $y_base_offser, %eax
		leal base_pic, %edi
		shrl $LOW_8_BITS, %ebx # shift left 0x0000ff00 and 0x00ff0000
		jmp print_1

	print_1:
		movb (%edi,%esi,1), %cl
		pushl %edx
		call mp1_poke
		popl %edx

		incl %esi
		addl $x_offset, %eax
		cmpl $5, %esi # loop 5 times
		jb print_1
		addl $1, %edx
		jmp loop_start # loop 5 times tpo print each character with offset
	loop_end:
		popl %edi
		popl %esi
		popl %ebx
		leave  # calle teardown
		ret

# -------------------------------------redraw_crosshairs--------------------------------------------------------------
# void mp1_redraw_crosshairs( )
# This functions prints the crosshairs on top of other elements on the screen
# inputs : void
# output : void
# ---------------------------------------------------------------------------------------------------
Redraw_crosshairs:
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx
	pushl %edi
	pushl %esi   # calle save

	movl crosshairs_x, %ebx # ebx -> crosshair_x
	movl crosshairs_y, %edi # ebi -> crosshair_y
	movl %edi, %eax
	imul $Y_offset, %eax
	imul $x_offset, %ebx
	addl %ebx, %eax # calculate offset

	movb $CROSSHAIR , %cl # print +

	pushl %edx
	call mp1_poke
	popl %edx 

	popl %esi
	popl %edi
	popl %ebx # calle teardown
	leave
		ret
#---------------------------------------startgame-----------------------------------------------
# void mp1_ioctl_startgame( unsigned long ignore )
# initializes the global variables 
# inputs : unsigned long ignore
# output : void

# ---------------------------------------------------------------------------------------------------
mp1_ioctl_startgame:
	pushl %ebp
	movl %esp, %ebp 
	pushl %ebx
	pushl %esi
	pushl %edi   # calle save

	movl $40, crosshairs_x # start x val
	movl $12, crosshairs_y # start y val
	movl $0, mp1_missile_list
	movl $0, mp1_score
	movl $BASE_n, base_alive

	popl %edi
	popl %esi
	popl %ebx # calle teardown
	leave
		ret
#-------------------------------------------------------------------------
# int mp1_ioctl_addmissile( struct missile* user_missile)
# This functions adds new missile to the linked list and returns if sucessfully added 
# inputs : struct missile* user_missile
# output : 0 : if missile added sucessfully
#		   1 : if missile was not added sucessfully
# ---------------------------------------------------------------------------------------------------
mp1_ioctl_addmissile: 
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx
	pushl %esi
	pushl %edi   # calle save

	movl LOW_8_BITS(%ebp),%ebx # ebx --> local variable (struct missile)

	cmpl $0, %ebx
	je  no_point

	pushl $36
	call mp1_malloc
	add $4, %esp
	
	movl %eax, %edi
	cmpl $0, %eax # check if malloc failed
	je no_point
	
	
	movl LOW_8_BITS(%ebp),%ebx # ebx --> local variable (struct missile)
	pushl $36
	pushl %ebx  # stuct missile
	pushl %eax # memory space
    call mp1_copy_from_user
	cmpl $0, %eax
	jne FAIL
	popl %eax
	popl %ebx

	# - add node to linked list  -
	add_linked_list:					
		movl mp1_missile_list, %edx
		movl %edx, NEXT(%edi)
		movl %edi, mp1_missile_list
		
		movl $0 , %eax # return 0
		jmp PASS 
	FAIL:
		pushl %esi
		call mp1_free
		popl %esi
	no_point:
		movl $-1, %eax # return -1

	PASS:
		popl %edi
		popl %esi
		popl %ebx  # calle teardown 
		leave
		ret

#-------------------------------------------------------------------------------------------------------b 
# int mp1_ioctl_moveshairs(unsigned log xharis_delta_packed )
# This functions makes 3 bases and prints it on the screen 
# inputs : void
# output : void
# ---------------------------------------------------------------------------------------------------

mp1_ioctl_movexhairs:
	
	pushl %ebp
	movl %esp, %ebp 
	pushl %ebx
	pushl %esi
	pushl %edi  # calle save

	movl (crosshairs_x),%ebx  # edx -> x
	movl (crosshairs_y),%esi # esi -> y	

	imul $Y_offset, %esi
	imul $x_offset, %ebx
	addl %esi,%ebx
	movl %ebx, %eax
	movb $0x20,%cl # print space
	
	pushl %edx
	call mp1_poke
	popl %edx

	movl LOW_8_BITS(%ebp), %ebx # ebx -> local variable

	movl %ebx, %esi 
	movswl %bx , %ebx # high 16 ebx -> x +
	sarl  $HIGH_BITS, %esi # %esi -> y +
	
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

		imul $Y_offset, %esi
		imul $x_offset, %ebx
		addl %ebx, %esi
		movl %esi, %eax
		movb $43, %cl
		pushl %edx
		call mp1_poke
		popl %edx

		popl %edi
		popl %esi
		popl %ebx  # calle teardown
		movl $0, %eax   # return 0
		leave
		ret
#-------------------------------------------------------------------------------------------------------
# int mp1_ioctl_getstatus( unsgned long* user_status )
# This functions makes 3 bases and prints it on the screen 
# inputs : unsgned long* user_status
# output : 0 : if status updated correctly
#		   1 : if status not updated correctly
# ---------------------------------------------------------------------------------------------------
mp1_ioctl_getstatus:
	pushl %ebp
	movl %esp,%ebp
	pushl %ebx
	pushl %esi
	pushl %edi # calle save

	cmpl $0 , LOW_8_BITS(%ebp)
	je fail_copy  # fail if no input
	
	movl LOW_8_BITS(%ebp), %edx
	
	cmpl $0 , %edx
	je fail_copy 
	
	pushl $4
	call mp1_malloc
	addl $4, %esp # allocate memory
	
	cmpl $0, %eax
	je fail_copy

	movl %eax, %edi 

	movl base_alive ,%ebx # %ebx -> base alive
	cmpb $0 , %bl # check last 8 bits
	je base2
	addl $1, %edx   # add first bit
	base2: 
		cmpb $0, %bh # check high 8 bits
		je base3
		addl $x_offset, %edx # add second bit
	base3:
		shrl $HIGH_BITS, %ebx
		cmpb $0, %bl
		je go_over
		addl $4, %edx  # add 3rd bit
	

go_over:	

	shll $HIGH_BITS, %edx
	movw mp1_score, %dx # add score to last 6 bits 

	movl %edx , add_status # store in global variable to access the pointer
	pushl $4  # bytes
	pushl $add_status # add to status register
	pushl LOW_8_BITS(%ebp) # struct
	call mp1_copy_to_user

	add $12, %esp

	cmpl $0, %eax
	jne fail_copy  # return -1
	movl $0, %eax
	jmp pass_copy # return 0

fail_copy:
	movl $-1,%eax

pass_copy:
	
	popl %edi
	popl %esi
	popl %ebx # calle teardown
	leave

		ret

#-------------------------------------------------------------------------------------------------------
# int mp1_ioctl_addmissile(unsigned long ignore)
# This functions makes 3 bases and prints it on the screen 
# inputs : unsigned long ignore
# output : 0
# ---------------------------------------------------------------------------------------------------
mp1_ioctl_endgame:
	pushl %ebp
    movl %esp, %ebp
    pushl %ebx
    pushl %esi
    pushl %edi   # calle save
 
    movl mp1_missile_list, %edi                
    
	loopy:
		cmpl $0, %edi                               
		je end_g
		pushl NEXT(%edi)                           		
		pushl %edi
		call mp1_free    # free each element of linked list                       
		addl $4, %esp
		popl %edi
		jmp loopy # loop to iterate linked list
    
	end_g:
		movl $0, %eax                               
		popl %edi
		popl %esi
		popl %ebx  # calle teardown
		leave
	ret

