# ECOAR - Code 39 - barcode decoding
# Szymon Galecki - 282 420
# date: 11.05.2021 3:00 AM

# only 24-bits 600x50 pixels BMP files are supported
.eqv BMP_FILE_SIZE 90122
.eqv BYTES_PER_ROW 1800

.data
newline: .asciiz "\n"
patterns: .word 0x34, 0x121, 0x61, 0x160, 0x31, 0x130, 0x70, 0x25, 0x124, 0x64, 0x109, 0x49, 0x148, 0x19, 0x118, 0x58, 0x58, 0x10c, 0x4c, 0x1c, 0x103, 0x43, 0x142, 0x13, 0x112, 0x52, 0x7, 0x106, 0x46, 0x16, 0x181, 0xc1, 0x1c0, 0x91, 0x190, 0xd0, 0x85, 0x184, 0xc4, 0xa8, 0xa2, 0x8a, 0x2a, 0x94
characters: .asciiz "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "-", ".", " ", "$", "/", "+", "%", "*" 


.align 4
res:	.space 2
image:	.space BMP_FILE_SIZE
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
	la	$t9, image				
	li	$t7, 25 					
	li	$t6, 1800				
	mul	$t7, $t7, $t6			
	addu	$t9, $t9, $t7		
	li	$t8, 0 					
	la	$a3, output				
	
search_narrow_bar:
	lb	$t0, ($t9)					
	beqz	$t0, narrow_bar_found			
	
move_right:
	addiu	$t9, $t9, 3				
	addiu	$t8, $t8, 1				
	beq	$t8, 599, exit				
	j	search_narrow_bar			

narrow_bar_found:						
	li	$t1, 1					
	la	$t7, ($t9)				
	li	$t8, 20					
	
read_narrow_bar:
	addiu	$t7, $t7, 3				
	lb	$t0, ($t7)			
	bnez	$t0, end_of_narrow_bar			
	addiu	$t1, $t1, 1				
	beq	$t1, $t8, exit				
	j	read_narrow_bar			

end_of_narrow_bar:
	la	$t5, ($t1)									
	
wide_space_found: 
	li	$t1, 1					
	
read_wide_space:
	addiu	$t7, $t7, 3				
	lb	$t0, ($t7)				
	beqz	$t0, end_of_wide_space	
	addiu	$t1, $t1, 1				
	beq	$t1, $t8, exit				
	j	read_wide_space			

end_of_wide_space:
	la	$t6, ($t1)				
		
check_width:
	bge	$t5, $t6, exit				
	
pattern_set_up:
	xor	$s0, $s0, $s0 				
	xor	$s1, $s1, $s1 				
	li	$s2, 1					
	li	$s3, 0					

get_to_next_bar:
	lb	$t0, ($t9)					
	beqz	$t0, prepare				
	
move_cursor_right:
	addiu	$t9, $t9, 3				
	addiu	$t8, $t8, 1				
	beq	$t8, 299, exit			
	j	get_to_next_bar				
	
prepare:
	li	$t1, 0					
	lb	$t2, ($t9) 				

get_bar_space:
	lb	$t0, ($t9)				
	bne	$t0, $t2, color_switch			
	
	addiu	$t1, $t1, 1				
	addiu	$t9, $t9, 3				
				
	j	get_bar_space				
	
color_switch:
	beq	$t1, $t5, narrow				
	beq	$t1, $t6, wide				
	
narrow:								
	or	$s0, $s0, $s3				
	addiu	$s1, $s1, 1				
	beq	$s1, 9, pattern_finished 	
	sll	$s0, $s0, 1				
	j	prepare				
	
wide:
	or	$s0, $s0, $s2				
	addiu	$s1, $s1, 1				
	beq	$s1, 9, pattern_finished		
	sll	$s0, $s0, 1				
	j	prepare					
	
pattern_finished:
	li	$t1, 0					
	la	$t2, patterns				
	la	$t3, characters				
	
compare:
	lw	$t4, ($t2)			
	beq	$s0, $t4, equal				
	bne	$s0, $t4, not_equal							

equal:
	li $v0, 4				
	move $a0, $t3 					
	syscall						
	j	pattern_set_up				

not_equal:
	addiu	$t1, $t1, 1				
	beq	$t1, 44, exit				
	addiu	$t2, $t2, 4				
	addiu	$t3, $t3, 2				
	j	compare					
	

exit:
	li	$v0, 10					
	syscall
