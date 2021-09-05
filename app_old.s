#define EXIT_SUCCESS 0

.data

fmt_str:
	.string "%s\n"

fmt_num:
	.string "%ld\n"

fmt_ch:
	.string "%c\n"

read_file_mode:
	.string "r"

empty_str:
	.string ""

.text
.global interpret_brainfuck


interpret_brainfuck:
	# parameters:
	# (arg1) %rdi: char *file_name

	# open the file and save the fd into %r15

	# file_name is already in %rdi (arg1)
	movq $read_file_mode, %rsi # put file mode string into %rsi (arg2)
	call fopen                 # get the fd
	movq %rax, %r15            # fd -> %r15


	# create memory for the brainfuck program

	subq $30000, %rbp      # allocate 30000 bytes of memory for the brainfuck program
	leaq -30000(%rbp), %rbx # store a pointer to the start of the memory in %rbx
	movq %rbx, %rdi        # pointer to start of memory -> %rdi (arg1)
	movq $30000, %rsi      # put the number of elements of the memory into %rsi (arg2)
	call bzero             # zero the memory


next_char:

	# read characters from the file

	movq %r15, %rdi # move the fd into %rdi (arg1)
	call fgetc      # get the next char


	# jump table for the current character
	# '+': 43        '<': 60
	# ',': 44        '>': 62
	# '-': 45        '[': 91
	# '.': 46        ']': 93

	cmpq $43, %rax
	je ch_increment
	cmpq $44, %rax
	je ch_read
	cmpq $45, %rax
	je ch_decrement
	cmpq $46, %rax
	je ch_write
	cmpq $60, %rax
	je ch_left
	cmpq $62, %rax
	je ch_right
	cmpq $91, %rax
	je ch_begin_loop
	cmpq $93, %rax
	je ch_end_loop

	# when any other character is found, exit

	jmp exit


ch_increment:
	# increment pointed memory cell

	movb (%rbx), %cl # current value -> %cx
	incb %cl         # %cx++
	movb %cl, (%rbx) # move the incremented value back into the cell
	jmp next_char


ch_decrement:
	# decrement pointed memory cell

	movb (%rbx), %cl # current value -> %cx
	decb %cl         # %cx--
	movb %cl, (%rbx) # move the decremented value back into the cell
	jmp next_char


ch_read:

	# read character into pointed memory cell

	call getchar     # read char into %rax
	movb %al, (%rbx) # put the char into the cell
	jmp next_char


ch_write:

	# write character from pointed memory cell to stdout

	movb (%rbx), %dil # current value -> %di
	call putchar      # print the char
	jmp next_char


ch_left:

	# decrement the memory pointer

	decq %rbx
	jmp next_char


ch_right:

	# increment the memory pointer

	incq %rbx
	jmp next_char


ch_begin_loop:

	# begin the current loop

	cmpb $0, (%rbx)  # check the value of the current pointed memory cell
	jne next_char    # go ahead if it is not zero

	# now we are going to find the matching ']' character and jump to it

	movq $1, %r14 # loop_cnt = 1

ch_begin_loop_loop:

	# get the character at this position

	movq %r15, %rdi # fp -> %rdi (arg1)
	call fgetc

	cmpq $91, %rax # check if the character is '['
	jne ch_begin_maybe_right_bracket
	incq %r14 # loop_cnt++
	jmp ch_begin_loop_loop


ch_begin_maybe_right_bracket:
	cmpq $93, %rax # check if the character is ']'
	jne ch_begin_loop_loop_check
	decq %r14 # loop_cnt--


ch_begin_loop_loop_check:
	cmpq $0, %r14 # check if we found the matching '[' character
	je next_char  # if we did, we continue interpreting the next character
	jmp ch_begin_loop_loop # else, we continue the loop


ch_end_loop:

	# end the current loop

	cmpb $0, (%rbx)  # check the value of the current pointed memory cell
	je next_char     # go ahead if it is zero

	# now we are going to find the matching '[' character and jump to it

	movq $1, %r14 # loop_cnt = 1

ch_end_loop_loop:

	# move back one position on the file stream

	movq %r15, %rdi # fp -> %rdi (arg1)
	movq $-2, %rsi  # offset -2 -> %esi (arg2)
	movl $1, %edx   # SEEK_SET -> %edx (arg3)
	call fseek


	# get the character at this position

	movq %r15, %rdi # fp -> %rdi (arg1)
	call fgetc

	cmpq $91, %rax # check if the character is '['
	jne ch_end_maybe_right_bracket
	decq %r14 # loop_cnt--
	jmp ch_end_loop_loop_check

ch_end_maybe_right_bracket:
	cmpq $93, %rax # check if the character is ']'
	jne ch_end_loop_loop_check
	incq %r14 # loop_cnt++
	jmp ch_end_loop_loop


ch_end_loop_loop_check:
	cmpq $0, %r14 # check if we found the matching '[' character
	je next_char  # if we did, we continue interpreting the next character
	jmp ch_end_loop_loop # else, we continue the loop


exit:

	# print newline

	movq $empty_str, %rdi
	call puts


	# exit the program

	movl $1, %eax # exit
	movl $0, %ebx # with code 0
	int $0x80
