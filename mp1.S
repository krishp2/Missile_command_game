
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

	SHIFTBITS = 16




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
	pushl %edi

	pushl %eax
	pushl %ecx
	pushl %edx 
	call update_missiles
	popl %edx
	popl %ecx
	popl %eax

	pushl %eax
	pushl %ecx
	pushl %edx 
	call Redraw_base
	popl %edx
	popl %ecx
	popl %eax 

	pushl %eax
	pushl %ecx
	pushl %edx
	call Redraw_crosshairs
	popl %edx
	popl %ecx
	popl %eax 

	popl %edi
	popl %esi
	popl %ebx
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

	movl 8(%esp), %esi
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

update_missiles:
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx
	pushl %esi
	pushl %edi

	movl mp1_missile_list, %ebx # ebx --> missle (dont change)

	loop_start_update_missile:
	cmpl $0, %ebx
	je end_missile
	

	movl X(%ebx), %edx # edx -> x
	movl Y(%ebx), %edi # edi -> y
	shrl $16, %edx  # accesing the video mode 16 bits (high)
	shrl $16, %edi  # accesing the video mode 16 bits (high)
	movl %edi, %eax # change to y if doei r isnt work
	imul $160, %eax 
	imul $2, %edx
	addl %edx, %eax
	movl $0x20,%ecx


	pushl %edx
	call mp1_poke
	popl %edx


	
	movl EXPLODED(%ebx), %edi # edi -> exploded
	cmpl $0, %edi # missle not exploded 
	jne currently_exploding  # FALGGGGGGG
	

	# ----- -------- sus -----update val????---------------------
	movl X(%ebx), %edx # edx --> x
	addl VX(%ebx), %edx # ebx --> VX
	shrl $16 , %edx
	

	movl Y(%ebx), %edi # edi --> y
	addl VY(%ebx), %edi
	shrl $16 , %edi
	
	# ---------------------------------------------------------

	cmpl $0, %edx # x<0
	jl OUT_of_bound
	cmpl $0, %edi # y<0
	jl OUT_of_bound
	cmpl $79,%edx # x>76
	jg OUT_of_bound
	cmpl $24, %edi # y>24
	jg OUT_of_bound
	jmp all_good


	OUT_of_bound:
	pushl %eax
	pushl %ecx
	pushl %edx
	call mp1_missile_remove
	popl %edx
	popl %ecx
	popl %eax

	all_good:
	
	movl VX(%ebx) , %edx
	addl %edx, X(%ebx)

	movl VY(%ebx) , %edi
	addl %edi, Y(%ebx)


	movl X(%ebx), %edx # %edx -> x 
	shrl $16, %edx
	movl Y(%ebx), %edi # %edi -> y
	shrl $16, %edi
	
	cmpl DEST_X(%ebx), %edx
	jne NOT_reached2
	cmpl DEST_Y(%ebx), %edi
	jne NOT_reached2

	currently_exploding:
	# jmp NOT_reached2
	
	movl X(%ebx), %edx # edx -> x
	movl Y(%ebx), %edi # edi -> y
	shrl $16, %edx  # accesing the video mode 16 bits (high)
	shrl $16, %edi  # accesing the video mode 16 bits (high)
	movl %edi, %eax # change to y if doesnt work
	imul $160, %eax 
	imul $2, %edx
	addl %edx, %eax
	xor %cl ,%cl
	movb $EXPLOSION, %cl

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
	je skip_notify
	pushl %edx
	call mp1_notify_user
	popl %edx

	skip_notify:
	movl EXPLODED(%ebx), %edi
	subl $1, %edi
	movl %edi, EXPLODED(%ebx)
	cmpl $0, %edi
	je pre_missile_remove
	movl NEXT(%ebx), %ebx
	jmp loop_start_update_missile

	
   #---

	NOT_reached2:

	movl X(%ebx), %edx # edx -> x
	movl Y(%ebx), %edi # edi -> y
	shrl $16, %edx # accesing the video mode 16 bits (high)
	shrl $16, %edi # accesing the video mode 16 bits (high)
	movl %edi, %eax # change to y if doesnt work
	imul $160, %eax 
	imul $2, %edx
	addl %edx, %eax

	xor %cl ,%cl
	movb C(%ebx) , %cl

	pushl %edx
	call mp1_poke
	popl %edx 
	jmp end_missile_remove

	pre_missile_remove:
	movl X(%ebx), %edx # edx -> x
	movl Y(%ebx), %edi # edi -> y
	shrl $16, %edx  # accesing the video mode 16 bits (high)
	shrl $16, %edi  # accesing the video mode 16 bits (high)
	movl %edi, %eax # change to y if doesnt work
	imul $160, %eax 
	imul $2, %edx
	addl %edx, %eax
	movb $0x20,%cl


	pushl %edx
	call mp1_poke
	popl %edx
	mp1_missile_remove:
	# jmp end_missile_remove 

	cmpl mp1_missile_list, %ebx
	movl mp1_missile_list, %edx	
	je remove_head

	loop_in:
	movl NEXT(%edx), %esi		
	cmpl %esi, %ebx	
	je loop_out
	movl NEXT(%edx), %ecx
	jmp loop_in

	loop_out:
	movl NEXT(%ebx), %edi 
	movl %edi, NEXT(%edx)
	movl %edi, %ebx

	pushl %esi
	call mp1_free
	addl $4, %esp

	jmp loop_start_update_missile# skip null head 

	remove_head:
	movl mp1_missile_list, %esi	
	pushl %esi				
	movl NEXT(%esi), %esi		
	movl %esi, mp1_missile_list
	call mp1_free				
	addl $4, %esp
	movl mp1_missile_list, %ebx

	jmp loop_start_update_missile
	#----end ----
	end_missile_remove:

	movl NEXT(%ebx), %ebx
	jmp loop_start_update_missile

	end_missile:
	popl %edi
	popl %esi
	popl %ebx
	leave
	ret
	#-------------------------------------------------------------------------------------------------

#    while (temp != NULL && temp->data != key) {
#        prev = temp;
#        temp = temp->next;
#    }

#    // Unlink the node from linked list
#    prev->next = temp->next;
  
#   free(temp); // Free memory
#---------------------------------------remove---------------------------------------------------------

#---------------------------------------------------------------------------------------------

Redraw_base:
	pushl %ebp
	movl %esp, %ebp 
	pushl %ebx
	pushl %esi
	pushl %edi

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
	subl $2 , %eax
	imul $2, %eax
	addl $3840, %eax
	leal dead_base_pic, %edi
	shrl $8, %ebx # shift left 0x0000ff00 and 0x00ff0000

	jmp print_1


	draw_base_alive:
	movl $20, %eax # %eax -> 20 (first base)
	imul %edx, %eax
	subl $2 , %eax
	imul $2, %eax
	addl $3840, %eax
	leal base_pic, %edi
	shrl $8, %ebx # shift left 0x0000ff00 and 0x00ff0000
	jmp print_1

	print_1:
	movb (%edi,%esi,1), %cl
	pushl %edx
	call mp1_poke
	popl %edx

	incl %esi
	addl $2, %eax
	cmpl $5, %esi
	jb print_1
	addl $1, %edx
	jmp loop_start
	loop_end:
	popl %edi
	popl %esi
	popl %ebx
	leave 
		ret

# -----------------------------------------------------------------------
Redraw_crosshairs:
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx
	pushl %edi
	pushl %esi

	movl crosshairs_x, %ebx
	movl crosshairs_y, %edi
	movl %edi, %eax
	imul $160, %eax
	imul $2, %ebx
	addl %ebx, %eax

	movb $CROSSHAIR , %cl

	pushl %edx
	call mp1_poke
	popl %edx

	popl %esi
	popl %edi
	popl %ebx
	leave
		ret
#--------------------------------------------------------------------------------------
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

	popl %edi
	popl %esi
	popl %ebx
	leave
		ret
#-------------------------------------------------------------------------
mp1_ioctl_addmissile: 
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx
	pushl %esi
	pushl %edi

	movl 8(%ebp),%ebx # ebx --> local variable (struct missile)

	cmpl $0, %ebx
	je  no_point

	pushl $36
	call mp1_malloc
	add $4, %esp
	
	movl %eax, %edi
	cmpl $0, %eax # check if malloc failed
	je no_point
	
	
	movl 8(%ebp),%ebx # ebx --> local variable (struct missile)
	pushl $36
	pushl %ebx                                       # stuct missile
	pushl %eax # memory space
    call mp1_copy_from_user
	cmpl $0, %eax
	jne FAIL
	popl %eax
	popl %ebx

	# - add node to linked list -
	add_linked_list:					
	movl mp1_missile_list, %edx
	movl %edx, NEXT(%edi)
    movl %edi, mp1_missile_list
	
	movl $0 , %eax
	jmp PASS
	FAIL:
	pushl %esi
	call mp1_free
	popl %esi
	no_point:
	movl $-1, %eax

	PASS:
	popl %edi
	popl %esi
	popl %ebx
	leave
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

	popl %edi
	popl %esi
	popl %ebx
	movl $0, %eax
	leave
		ret

mp1_ioctl_getstatus:
	pushl %ebp
	movl %esp,%ebp
	pushl %ebx
	pushl %esi
	pushl %edi

	cmpl $0 , 8(%ebp)
	je fail_copy
	
	movl 8(%ebp), %edx
	
	cmpl $0 , %edx
	je fail_copy
	
	pushl $4
	call mp1_malloc
	addl $4, %esp
	
	cmpl $0, %eax
	je fail_copy

	movl %eax, %edi 

	movl base_alive ,%ebx
	cmpb $0 , %bl
	jne base_1_alive
come_back_base2:
	cmpb $0, %bh
	jne base_2_alive
come_back_base3:
	shrl $8, %ebx
	cmpb $0, %bh
	jne base_3_alive
	jmp go_over

base_1_alive:
	addl $1, %edx
	jmp come_back_base2
base_2_alive:
	addl $2, %edx
	jmp come_back_base3
base_3_alive:
	addl $4, %edx
	

go_over:	

	shll $16, %edx
	movw mp1_score, %dx

	movl %edx , add_status
	pushl $4
	pushl $add_status
	pushl 8(%ebp)
	call mp1_copy_to_user
	# popl %esp
	add $12, %esp

	cmpl $0, %eax
	jne fail_copy
	movl $0, %eax
	jmp pass_copy

fail_copy:
	movl $-1,%eax

pass_copy:
	
	popl %edi
	popl %esi
	popl %ebx
	leave

		ret
	
mp1_ioctl_endgame:
	pushl %ebp
    movl %esp, %ebp
    pushl %ebx
    pushl %esi
    pushl %edi
 
    movl mp1_missile_list, %edi                
    
	loopy:
    cmpl $0, %edi                               
    je end_g
    pushl NEXT(%edi)                           		
    pushl %edi
    call mp1_free                               
	addl $4, %esp
    popl %edi
    jmp loopy
    
	end_g:
    movl $0, %eax                               
    popl %edi
    popl %esi
    popl %ebx
    leave
	ret

