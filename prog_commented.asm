# ECOAR - Code 39 - barcode decoding
# Szymon Galecki - 282 420
# date: 11.05.2021 2:48 AM

# only 24-bits 600x50 pixels BMP files are supported
.eqv BMP_FILE_SIZE 90122
.eqv BYTES_PER_ROW 1800

.data
newline: .asciiz "\n"
patterns: .word 0x34, 0x121, 0x61, 0x160, 0x31, 0x130, 0x70, 0x25, 0x124, 0x64, 0x109, 0x49, 0x148, 0x19, 0x118, 0x58, 0x58, 0x10c, 0x4c, 0x1c, 0x103, 0x43, 0x142, 0x13, 0x112, 0x52, 0x7, 0x106, 0x46, 0x16, 0x181, 0xc1, 0x1c0, 0x91, 0x190, 0xd0, 0x85, 0x184, 0xc4, 0xa8, 0xa2, 0x8a, 0x2a, 0x94
characters: .asciiz "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "-", ".", " ", "$", "/", "+", "%", "*" 


# space for the 600x50px 24-bits bmp image
.align 4
res:	.space 2
image:	.space BMP_FILE_SIZE

# change name of the file below, put it in the same directory
# mars.jar must also be in the same directory 
fname:	.asciiz "1.bmp"
output: .space 100


.text		
open_file:
	li	$v0, 13
	la	$a0, fname
	li	$a1, 0
	li	$a2, 0
	syscall
	
check_descriptor:
	bltz	$v0, exit
	move 	$s0, $v0

read_file:
	li $v0, 14
	move $a0, $s0
	la $a1, image
	li $a2, BMP_FILE_SIZE
	syscall
	
close_file:
	li $v0, 16
	move $a0, $s0
   	syscall

set_up:
	la	$t9, image				# address of image to $t9
	li	$t7, 25 					# line number to be read - 25		
	li	$t6, 1800				# line size: 90000 / 50 = 1800 (50 - image height)
	mul	$t7, $t7, $t6				# 25 lines down - 25 * 1800
	addu	$t9, $t9, $t7				# add 25 * 1800 to bitmap address to move to line #30
	li	$t8, 0 					# $t8 - pixel iterator, moves left to right
	la	$a3, output				# output is stored at $a3			
	

# from the start/stop sign *, get pixel value of "NARROW" and "WIDE" for future decoding
search_narrow_bar:
	lb	$t0, ($t9)				# load byte stored at $t9 to $t0	
	beqz	$t0, narrow_bar_found			# branch if equal to zero to narrow_bar_found 
	
move_right:
	addiu	$t9, $t9, 3				# increment image memory address
	addiu	$t8, $t8, 1				# increment pixel count
	beq	$t8, 599, exit				# if pixel count == 599, there were no black pixels on the chosen line
	j	search_narrow_bar			# loop: jump to search_narrow_bar

narrow_bar_found:						
	li	$t1, 1					# width counter - $t1
	la	$t7, ($t9)				# load image memory address to $t7
	li	$t8, 20					# 20 to $t8
	
read_narrow_bar:
	addiu	$t7, $t7, 3				# increment image memory address
	lb	$t0, ($t7)				# load byte stored at $t7 to $t0
	bnez	$t0, end_of_narrow_bar			# branch if not equal to zero, if $t0 == 0 - pixel not black
	addiu	$t1, $t1, 1				# increment width counter
	beq	$t1, $t8, exit				# if width == 20 px, branch to exit
	j	read_narrow_bar				# loop: jump to read_narrow_bar

end_of_narrow_bar:
	la	$t5, ($t1)				# store "NARROW" at $t5						
	
wide_space_found: 
	li	$t1, 1					# set width to 1 as the first white pixel was reached
	
read_wide_space:
	addiu	$t7, $t7, 3				# increment image memory address
	lb	$t0, ($t7)				# load byte stored at $t7 to $t0	
	beqz	$t0, end_of_wide_space			# branch if equal to zero, if $t0 == 0 - pixel not white
	addiu	$t1, $t1, 1				# increment width counter
	beq	$t1, $t8, exit				# if width == 20 px, branch to exit
	j	read_wide_space				# loop: jump to read_wide_space

end_of_wide_space:
	la	$t6, ($t1)				# store "WIDE" at $t6
		
check_width:
	bge	$t5, $t6, exit				# if NARROW >= WIDE - exit
# end of obtaining "NARROW" and "WIDE"
	

pattern_set_up:
	xor	$s0, $s0, $s0 				# pattern
	xor	$s1, $s1, $s1 				# number of shifts
	li	$s2, 1					# 1 to $s2
	li	$s3, 0					# 0 to $s3

get_to_next_bar:
	lb	$t0, ($t9)				# load byte stored at $t9 to $t0	
	beqz	$t0, prepare				# reached beginning of next encoded character 
	
move_cursor_right:
	addiu	$t9, $t9, 3				# increment image memory address
	addiu	$t8, $t8, 1				# increment pixel count
	beq	$t8, 299, exit				# if pixel count == 599, there were no black pixels on line
	j	get_to_next_bar				# loop: jump to get_to_next_bar
	
prepare:
	li	$t1, 0					# 0 to $t1, reset the width - key parameter
	lb	$t2, ($t9) 				# current color to $t2

get_bar_space:
	lb	$t0, ($t9)				# load current color to $t0
	bne	$t0, $t2, color_switch			# if color changed - we got the bar/space
	
	addiu	$t1, $t1, 1				# increment pixel count - width of bar/space	
	addiu	$t9, $t9, 3				# increment image memory address
				
	j	get_bar_space				# loop: jump to get_bar_space
	
color_switch:
	beq	$t1, $t5, narrow				# branch if equal: width == narrow
	beq	$t1, $t6, wide				# branch if equal: width == wide
	
narrow:								
	or	$s0, $s0, $s3				# $s0 = or($s0, $s3) = or($s0, 0)
	addiu	$s1, $s1, 1				# increment module counter
	beq	$s1, 9, pattern_finished 		# width of character - 11 modules -> branch to pattern_finished
	sll	$s0, $s0, 1				# shift pattern stored at $s0, one to the left
	j	prepare					# loop: jump to prepare
	
wide:
	or	$s0, $s0, $s2				# $s0 = or($s0, $s2) = or($s0, 1)
	addiu	$s1, $s1, 1				# increment module counter
	beq	$s1, 9, pattern_finished			# width of character - 11 modules -> branch to pattern_finished
	sll	$s0, $s0, 1				# shift pattern stored at $s0, one to the left
	j	prepare					# loop: jump to prepare
	
pattern_finished:
	li	$t1, 0					# list iterator
	la	$t2, patterns				# patterns list 
	la	$t3, characters				# characters list
	
compare:
	lw	$t4, ($t2)				# load first code to $t4
	beq	$s0, $t4, equal				# if pattern at $s0 == code at $t4 -> branch to equal
	bne	$s0, $t4, not_equal			# if pattern at $s0 != code at $t4 -> branch to not_equal					

equal:
	li $v0, 4					# print string
	move $a0, $t3 					# print value at the array pointer
	syscall						
	j	pattern_set_up				# reset pattern, go back to reading

not_equal:
	addiu	$t1, $t1, 1				# increment list iterator
	beq	$t1, 44, exit				# if we are out of list ranges, exit
	addiu	$t2, $t2, 4				# next pattern from patterns
	addiu	$t3, $t3, 2				# next character from characters
	j	compare					# compare again
	

exit:
	li	$v0, 10					# terminate program
	syscall
