.data

read_file_mode:
	.string "r"

fmt_ld:
	.string "%ld\n"

fmt_d:
	.string "%d\n"

fmt_hd:
	.string "%hd\n"

fmt_hhd:
	.string "%hhd\n"

fmt_c:
	.string "%c\n"

str_hello:
	.string "hello"

fmt_ins_cpy:
	.string "CPY(@%hhd, x%hhd)\n"

str_ins_inc_ptr:
	.string "INS_INC_PTR"

str_ins_dec_ptr:
	.string "INS_DEC_PTR"

str_ins_chg_ptr:
	.string "INS_CHG_PTR"

str_ins_inc_val:
	.string "INS_INC_VAL"

str_ins_dec_val:
	.string "INS_DEC_VAL"

str_ins_chg_val:
	.string "INS_CHG_VAL"

str_ins_out:
	.string "INS_OUT"

str_ins_in:
	.string "INS_IN"

str_ins_jmp_fwd:
	.string "INS_JMP_FWD"

str_ins_jmp_bck:
	.string "INS_JMP_BCK"

str_ins_zero:
	.string "INS_ZERO"

str_ins_cpy:
	.string "INS_CPY"

.text
.global main
main:

	# parameters:
	# (arg1) %rdi: int argc
	# (arg2) %rsi: char **argv

	movq %rsp, %rbp

	# locals: (554288 bytes)
	# char mem[30000]          @   -30000(%rbp)
	# uint64_t program[524288] @ -4464304(%rbp)
	# char file_buf[524288]    @ -4988592(%rbp)
	# char cpy_loop_arr[256]   @ -4988848(%rbp)

	subq $4988848, %rsp      # allocate locals


	# open the file and put the fd into %rax

	movq 8(%rsi), %rdi # file_name -> %rdi (arg1)
	movq $0, %rsi      # read-only flag -> %rsi (arg2)
	movq $2, %rax      # open file system call
	syscall            # get the fd


	# read the file into the buffer

	leaq -4988592(%rbp), %r15 # ptr to start of file_buf -> %r15
	movq %rax, %rdi           # fd -> %rdi (arg1)
	movq %r15, %rsi           # file_buf -> %rsi (arg2)
	movq $524288, %rdx        # read size -> %rdx (arg3)
	movq $0, %rax             # read file system call
	syscall

	# fd is already in %rdi (arg1)
	movq $3, %rax # close file system call
	syscall       # closes fd


compile_bf:

	leaq -4464304(%rbp), %r14 # initialise the instr_ptr into %14
	jmp cpl_bf_read_next_char # start reading chars


next_char:
	movb (%r15), %al # next char -> %al
	addq $1, %r15    # increment file_buf ptr

	# jump table for the current character
	# '+': 43        '<': 60
	# ',': 44        '>': 62
	# '-': 45        '[': 91
	# '.': 46        ']': 93

	# TODO: use an actual jump table or optimise with compiler explorer
	# for better performance

	# return if the char is valid

	cmpb $43, %al
	je next_char_ret

	cmpb $44, %al
	je next_char_ret

	cmpb $45, %al
	je next_char_ret

	cmpb $46, %al
	je next_char_ret

	cmpb $60, %al
	je next_char_ret

	cmpb $62, %al
	je next_char_ret

	cmpb $91, %al
	je next_char_ret

	cmpb $93, %al
	je next_char_ret

	cmpb $0, %al
	jne next_char # if the char is invalid, read the next char


next_char_ret:

	ret



cpl_bf_read_next_char:

	# read characters from the file_buf

	call next_char

	// movb (%r15), %al # next char -> %al
	// addq $1, %r15    # increment file_buf ptr

	// pushq %rax
	// movq $fmt_c, %rdi
	// movb %al, %sil
	// xorq %rax, %rax
	// call printf
	// popq %rax

	# jump table for the current character
	# '+': 43        '<': 60
	# ',': 44        '>': 62
	# '-': 45        '[': 91
	# '.': 46        ']': 93

	cmpb $43, %al
	je cpl_bf_inc_val

	cmpb $44, %al
	je cpl_bf_in

	cmpb $45, %al
	je cpl_bf_dec_val

	cmpb $46, %al
	je cpl_bf_out

	cmpb $60, %al
	je cpl_bf_dec_ptr

	cmpb $62, %al
	je cpl_bf_inc_ptr

	cmpb $91, %al
	je cpl_bf_jmp_fwd

	cmpb $93, %al
	je cpl_bf_jmp_bck

	cmpb $0, %al
	je cpl_bf_exit

	# skip unknown characters

	// jmp cpl_bf_read_next_char


cpl_bf_inc_ptr:

	movw $1, %bx       # 1 -> combined chg_val argument
	jmp cpl_bf_chg_ptr # optimise subsequent '+'s and '-'s

cpl_bf_dec_ptr:

	movw $-1, %bx      # 1 -> combined chg_val argument
	jmp cpl_bf_chg_ptr # optimise subsequent '+'s and '-'s


# combines subsequent '+'s and '-'s into a single chg_val instr

cpl_bf_chg_ptr:

	call next_char

	cmpb $60, %al             # check if the next char is '<'
	je cpl_bf_chg_ptr_dec     # if so, increment the arg
	cmpb $62, %al             # else, if the next char is '>'
	je cpl_bf_chg_ptr_inc     # decrement the arg

	subq $1, %r15             # decrement file_buf ptr

	# now we're going to compile the CHG_PTR instruction

	testw %bx, %bx           # test the arg
	je cpl_bf_read_next_char # if arg == 0, skip compilation
	jns cpl_bf_inc_ptr_n     # if arg > 0, compile into INC_PTR_N


cpl_bf_dec_ptr_n:

	# arg must be < 0, compile into DEC_PTR_N

	cmpw $-127, %bx
	jge cpl_bf_dec_ptr_n_short # arg: [ -127, -1 ], compile into DEC_PTR_N_SHORT

	# arg must be: ( <-, -128 ], compile into DEC_PTR_N_LONG


cpl_bf_dec_ptr_n_long:

	movb $0x48, (%r14)  # from %rbx
	movb $0x81, 1(%r14) # do 4-byte
	movb $0xeb, 2(%r14) # sub
	negw %bx            # (get the absolute value of n)
	movzwl %bx, %ebx    # (pad n with zeroes)
	movl %ebx, 3(%r14)  # of n

	addq $7, %r14             # increment the instr_ptr
	jne cpl_bf_read_next_char # read the next char


cpl_bf_dec_ptr_n_short:

	movb $0x48, (%r14)  # from %rbx
	movb $0x83, 1(%r14) # do 1-byte
	movb $0xeb, 2(%r14) # sub
	negw %bx            # (get the absolute value of n)
	movb %bl, 3(%r14)   # of n

	addq $4, %r14             # increment the instr_ptr
	jne cpl_bf_read_next_char # read the next char


cpl_bf_inc_ptr_n:

	cmpw $127, %bx
	jle cpl_bf_inc_ptr_n_short # arg: [ 1, 127 ], compile into INC_PTR_N_SHORT

	# arg must be: [ 128, -> ), compile into DEC_PTR_N_LONG


cpl_bf_inc_ptr_n_long:

	movb $0x48, (%r14)  # from %rbx
	movb $0x81, 1(%r14) # do 4-byte
	movb $0xc3, 2(%r14) # add
	movzwl %bx, %ebx    # (pad n with zeroes)
	movl %ebx, 3(%r14)  # of n

	addq $7, %r14             # increment the instr_ptr
	jne cpl_bf_read_next_char # read the next char


cpl_bf_inc_ptr_n_short:

	movb $0x48, (%r14)  # from %rbx
	movb $0x83, 1(%r14) # do 1-byte
	movb $0xc3, 2(%r14) # add
	movb %bl, 3(%r14)   # of n

	addq $4, %r14             # increment the instr_ptr
	jne cpl_bf_read_next_char # read the next char


cpl_bf_chg_ptr_inc:

	addw $1, %bx       # increment the arg
	jmp cpl_bf_chg_ptr # and check if we can extend the chg_val


cpl_bf_chg_ptr_dec:

	subw $1, %bx       # decrement the arg
	jmp cpl_bf_chg_ptr # and check if we can extend the chg_val


cpl_bf_inc_val:

	movb $1, %bl              # 1 -> combined chg_val argument
	jmp cpl_bf_chg_val


cpl_bf_dec_val:

	movb $-1, %bl             # -1 -> combined chg_val argument
	jmp cpl_bf_chg_val


# combines subsequent '+'s and '-'s into a single chg_val instr

cpl_bf_chg_val:

	call next_char

	cmpb $43, %al             # check if the next char is '+'
	je cpl_bf_chg_val_inc     # if so, increment the arg
	cmpb $45, %al             # else, if the next char is '-'
	je cpl_bf_chg_val_dec     # decrement the arg

	subq $1, %r15             # decrement file_buf ptr

	# now we're going to compile the CHG_VAL instruction

	testb %bl, %bl            # test the arg
	je cpl_bf_read_next_char  # if arg == 0, skip


cpl_bf_inc_val_n:

	movb $0x80, (%r14)  # to (%rbx)
	movb $0x03, 1(%r14) # do 1-byte add
	movb %bl, 2(%r14)   # of n
	addq $3, %r14             # increment the instr_ptr
	jne cpl_bf_read_next_char # read the next char

cpl_bf_chg_val_inc:

	addb $1, %bl       # increment the arg
	jmp cpl_bf_chg_val # and check if we can extend the chg_val


cpl_bf_chg_val_dec:

	subb $1, %bl       # decrement the arg
	jmp cpl_bf_chg_val # and check if we can extend the chg_val


cpl_bf_out:

	movb $0xbf, (%r14)   # move into %edi (fd)
	movl $1, 1(%r14)     # the literal value 1 (for stdout)

	movb $0x48, 5(%r14)  # move
	movb $0x89, 6(%r14)  # %rbx (pointer to the current cell)
	movb $0xde, 7(%r14)  # into %rsi (pointer to data to write)

	movb $0xba, 8(%r14)  # move to %edx (write size)
	movl $1, 9(%r14)     # the size of 1

	movb $0xb8, 13(%r14) # move to %eax (syscall)
	movl $1, 14(%r14)    # the literal value 1 (for SYS_WRITE)

	movb $0x0f, 18(%r14) # syscall
	movb $0x05, 19(%r14)

	addq $20, %r14            # increment the instr_ptr
	jmp cpl_bf_read_next_char # read the next char


cpl_bf_in:

	movb $0xbf, (%r14)   # move into %edi (fd)
	movl $0, 1(%r14)     # the literal value 0 (for stdin)

	movb $0x48, 5(%r14)  # move
	movb $0x89, 6(%r14)  # %rbx (pointer to the current cell)
	movb $0xde, 7(%r14)  # into %rsi (pointer to buffer to read into)

	movb $0xba, 8(%r14)  # move to %edx (read size)
	movl $1, 9(%r14)     # the size of 1

	movb $0xb8, 13(%r14) # move to %eax (syscall)
	movl $0, 14(%r14)    # the literal value 0 (for SYS_READ)

	movb $0x0f, 18(%r14) # syscall
	movb $0x05, 19(%r14)

	addq $20, %r14            # increment the instr_ptr
	jmp cpl_bf_read_next_char # read the next char


cpl_bf_jmp_fwd:

	# check for copy loop pattern

	leaq -4988848(%rbp), %rdi # cpy_loop_arr start addr -> %rdi (arg1)
	movq $256, %rsi           # number of elements -> %rsi (arg2)
	call bzero                # zero the memory

	leaq -4988720(%rbp), %rdx # init cpy_loop_ptr (%rdx) to cpy_loop_arr + 128
	movq %r15, %rcx           # copy the file_buf ptr into %rcx

cpl_bf_jmp_fwd_cpy_loop:

	leaq -4988848(%rbp), %rax # move cpy_loop_arr start addr into %rax
	cmpq %rdx, %rax           # compare the cpy_loop_ptr to the cpy_loop_arr
	ja cpl_bf_jmp_fwd_1       # if cpy_loop_ptr < cpy_loop_arr: skip cpy_loop

	leaq -4988592(%rbp), %rax # move cpy_loop_arr end addr into %rdx
	cmpq %rdx, %rax           # compare the cpy_loop_ptr to the cpy_loop_arr
	jbe cpl_bf_jmp_fwd_1      # if cpy_loop_ptr >= cpy_loop_arr end: skip cpy_loop

	cmpb $91, (%rcx)          # compare the current byte to '['
	je cpl_bf_jmp_fwd_1       # if cur_byte == '[': skip cpy_loop

	# TODO: support [+] clearloop

	cmpb $60, (%rcx)              # compare the current byte to '<'
	jne cpl_bf_jmp_fwd_cpy_loop_1 # if cur_byte != '<': skip '<' handler
	subq $1, %rdx                 # cpy_loop_ptr--
	jmp cpl_bf_jmp_fwd_cpy_loop_5 # next iter


cpl_bf_jmp_fwd_cpy_loop_1:

	cmpb $62, (%rcx)              # compare the current byte to '>'
	jne cpl_bf_jmp_fwd_cpy_loop_2 # if cur_byte != '>': skip '>' handler
	addq $1, %rdx                 # cpy_loop_ptr++

	jmp cpl_bf_jmp_fwd_cpy_loop_5 # next iter


cpl_bf_jmp_fwd_cpy_loop_2:

	cmpb $45, (%rcx)              # compare the current byte to '-'
	jne cpl_bf_jmp_fwd_cpy_loop_3 # if cur_byte != '-': skip '-' handler
	subb $1, (%rdx)               # *(cpy_loop_ptr)--
	jmp cpl_bf_jmp_fwd_cpy_loop_5 # next iter


cpl_bf_jmp_fwd_cpy_loop_3:

	cmpb $43, (%rcx)              # compare the current byte to '+'
	jne cpl_bf_jmp_fwd_cpy_loop_4 # if cur_byte != '+': skip '+' handler
	addq $1, (%rdx)               # *(cpy_loop_ptr)++
	jmp cpl_bf_jmp_fwd_cpy_loop_5 # next iter


cpl_bf_jmp_fwd_cpy_loop_4:

	cmpb $44, (%rcx)               # compare the current byte to ','
	je cpl_bf_jmp_fwd_1            # if cur_byte == ',': skip cpy_loop
	cmpb $46, (%rcx)               # compare the current byte to '.'
	je cpl_bf_jmp_fwd_1            # if cur_byte == '.': skip cpy_loop
	cmpb $93, (%rcx)               # compare the current byte to ']'
	je cpl_bf_jmp_fwd_cpy_loop_end # end the cpy_loop


cpl_bf_jmp_fwd_cpy_loop_5:

	addq $1, %rcx                # increment the running file_buf ptr
	jmp cpl_bf_jmp_fwd_cpy_loop  # next iteration


cpl_bf_jmp_fwd_cpy_loop_end:

	leaq -4988720(%rbp), %rax # load cpy_loop_arr + 128
	cmpq %rax, %rdx           # load cpy_loop_ptr
	jne cpl_bf_jmp_fwd_1      # if didn't end where started: skip cpy_loop

	cmpb $-1, (%rdx)          # check if start decremented by 1
	jne cpl_bf_jmp_fwd_1      # if not: skip cpy_loop

	# now we're 100% sure this is a copy loop

	addq $1, %rcx   # move running file_buf ptr to the char after the ']'
	movq %rcx, %r15 # running file_buf ptr -> file_buf ptr

	# for (cpy_ptr = cpy_arr; cpy_ptr != cpy_arr + 256; cpy_ptr++)

	leaq -4988848(%rbp), %rdx # move cpy_loop_arr start into %rdx
	leaq -4988592(%rbp), %r10 # move cpy_loop_arr end into %r10
	leaq -4988720(%rbp), %r13 # move cpy_loop_arr middle into %r13
	movq %rdx, %rbx           # init cpy_loop_ptr (%rbx) to cpy_loop_arr start


cpl_bf_jmp_fwd_cpy_loop_end_1:

	movsbl (%rbx), %esi # *cpy_loop_ptr -> %esi, extending sign
	testb %sil, %sil    # if *cpy_loop_ptr == 0, skip
	je cpl_bf_jmp_fwd_cpy_loop_end_2

	cmpq %rbx, %r13     # if cpy_loop_ptr == cpy_loop_arr middle, skip
	je cpl_bf_jmp_fwd_cpy_loop_end_2

	movq %rbx, %r12       # cpy_loop_ptr -> offset (%r12)
	subq %rdx, %r12       # offset -= cpy_loop_arr start
	subq $128, %r12       # offset -= 128

	// pushq %rdx
	// pushq %r10
	// movq $fmt_ins_cpy, %rdi
	// movb %r12b, %sil
	// movb (%rbx), %dl
	// xorq %rax, %rax
	// call printf
	// popq %r10
	// popq %rdx

	# copy instruction

	movb $0x0f,  (%r14)  # movzbl
	movb $0xb6, 1(%r14)  # (%rbx)
	movb $0x03, 2(%r14)  # into %eax

	movb $0x48, 3(%r14)  # move 64-bit value
	movb $0xbf, 4(%r14)  # into %rdi
	movq %r12, 5(%r14)   # the offset

	movb $0x69, 13(%r14)  # imull
	movb $0xc0, 14(%r14)  # into %eax
	movb (%rbx), %sil    # (load the factor)
	movl %esi, 15(%r14)  # the factor

	movb $0x00, 19(%r14) # movb
	movb $0x04, 20(%r14) # %al
	movb $0x3b, 21(%r14) # into %rbx[%rdi]

	addq $22, %r14        # increment the instr_ptr


cpl_bf_jmp_fwd_cpy_loop_end_2:

	addq $1, %rbx   # increment the cpy_loop_ptr
	cmpq %r10, %rbx # if cpy_loop_ptr != cpy_loop_arr + 256, next iter
	jne cpl_bf_jmp_fwd_cpy_loop_end_1

	// cmpb $45, (%r15)     # check for '[-]' pattern
	// jne cpl_bf_jmp_fwd_1 # if the next char is not '-', do normal fwd_jmp
	// cmpb $93, 1(%r15)    # check next char
	// jne cpl_bf_jmp_fwd_1 # if it's not ']', do normal fwd_jmp

	# zero the current byte

	movb $0xc6, (%r14)   # movb
	movb $0x03, 1(%r14)  # into (%rbx)
	movb $0x00, 2(%r14)  # the value 0

	addq $3, %r14             # increment the instr_ptr
	// addq $2, %r15             # increment file_buf ptr
	jmp cpl_bf_read_next_char # read the next char


cpl_bf_jmp_fwd_1:

	// movq $str_hello, %rdi
	// call puts

	pushq %r14           # push the instr_ptr

	movb $0x48, (%r14)   # move 64-bit value
	movb $0xb8, 1(%r14)  # into %rax
	# leave room for the address

	movb $0x80, 10(%r14) # cmpb
	movb $0x3b, 11(%r14) # (%rbx)
	movb $0x00, 12(%r14) # to 0

	movb $0x75, 13(%r14) # jne
	movb $0x02, 14(%r14) # relative 2 bytes fwd

	movb $0xff, 15(%r14) # jmp
	movb $0xe0, 16(%r14) # to *%rax

	addq $17, %r14            # increment the instr_ptr
	jmp cpl_bf_read_next_char # read the next char


cpl_bf_jmp_bck:

	popq %rax            # pop the instr_ptr of the matching jmp_fwd

	movb $0x48, (%r14)   # move 64-bit value
	movb $0xb8, 1(%r14)  # into %rax
	movq %rax, 2(%r14)   # the address of the matching '[' instruction

	movb $0x80, 10(%r14) # cmpb
	movb $0x3b, 11(%r14) # (%rbx)
	movb $0x00, 12(%r14) # to 0

	movb $0x74, 13(%r14) # je
	movb $0x02, 14(%r14) # relative 2 bytes fwd

	movb $0xff, 15(%r14) # jmp
	movb $0xe0, 16(%r14) # to *%rax

	movq %r14, 2(%rax)   # put the instr_ptr into the fwd_jmp address
	addq $17, %r14       # increment the instr_ptr

	jmp cpl_bf_read_next_char # read the next char


cpl_bf_exit:

	// movb $0xb8, (%r14)  # movl into %eax
	// movl $60, 1(%r14)   # literal 60 (for SYS_EXIT)

	// movb $0xbf, 5(%r14) # movl into %edi
	// movl $0, 6(%r14)    # literal 0 (success exit code)

	// movb $0x0f, 10(%r14) # syscall
	// movb $0x05, 11(%r14)

	// addq $12, %r14       # increment the instr_ptr

	movb $0xc3, (%r14)  # ret

	# fall through to executing the compiled code


exec_bf:

	leaq -30000(%rbp), %rbx  # store a pointer to the start of the memory in %rbx
	movq %rbx, %rdi          # pointer to start of memory -> %rdi (arg1)
	movq $30000, %rsi        # put the number of elements of the memory into %rsi (arg2)
	call bzero               # zero the memory

	# print the compiled x86 opcode buffer

	// leaq -4464304(%rbp), %rdi
	// movq %r14, %rsi
	// call print_prgm

	leaq -4464304(%rbp), %r14  # reset the instr_ptr
	call *%r14                 # execute the compiled code

	# print the output stack

	// leaq -30000(%rbp), %rdi
	// movq $256, %rsi
	// call print_stack
	jmp ins_exit


exec_bf_next_instr:

	movq (%r14), %rax # fetch the next instruction
	jmpq *%rax        # jump to the instruction label


# list of instructions
#
# INC_PTR()
# 	4883c301 # addq $1, %rbx
#
# DEC_PTR()
# 	4883eb01 # subq $1, %rbx
#
# CHG_PTR(off)
# 	mem_ptr += off
#
# INC_VAL()
# 	(*mem_ptr)++
#
# DEC_VAL()
# 	(*mem_ptr)--
#
# CHG_VAL(off)
# 	(*mem_ptr) += off
#
# OUT(c)
# 	putchar(c)
#
# IN()
# 	*mem_ptr = getchar()
#
# JMP_FWD(addr)
# 	ins_ptr = addr


ins_inc_ptr:
	addq $1, %rbx # increment the mem_ptr
	addq $8, %r14 # increment the instr_ptr

	// movq $str_ins_inc_ptr, %rdi
	// call puts

	jmp exec_bf_next_instr


ins_dec_ptr:

	subq $1, %rbx # decrement the mem_ptr
	addq $8, %r14 # increment the instr_ptr

	// movq $str_ins_dec_ptr, %rdi
	// call puts

	jmp exec_bf_next_instr


ins_chg_ptr:

	movw 8(%r14), %r12w # get arg
	addw %r12w, %bx     # increment the mem_ptr by the arg
	addq $10, %r14      # increment the instr_ptr

	// movq $str_ins_chg_ptr, %rdi
	// call puts

	// movq $fmt_hd, %rdi
	// movw %r12w, %si
	// xorq %rax, %rax
	// call printf

	jmp exec_bf_next_instr


ins_inc_val:

	addb $1, (%rbx) # increment the byte
	addq $8, %r14   # increment the instr_ptr

	// movq $str_ins_inc_val, %rdi
	// call puts

	jmp exec_bf_next_instr


ins_dec_val:

	subb $1, (%rbx) # decrement the byte
	addq $8, %r14   # increment the instr_ptr

	// movq $str_ins_dec_val, %rdi
	// call puts

	jmp exec_bf_next_instr


ins_chg_val:

	movb 8(%r14), %r12b # get the arg
	addb %r12b, (%rbx)  # add the value of the arg into the byte
	addq $9, %r14       # increment the instr_ptr

	// movq $str_ins_chg_val, %rdi
	// call puts

	// movq $fmt_hhd, %rdi
	// movb %r12b, %sil
	// xorq %rax, %rax
	// call printf

	jmp exec_bf_next_instr


ins_out:

	movb (%rbx), %dil # load the byte
	call putchar      # print it
	addq $8, %r14     # increment the instr_ptr

	// movq $str_ins_out, %rdi
	// call puts

	jmp exec_bf_next_instr


ins_in:

	call getchar     # read byte into %eax
	movb %al, (%rbx) # store the byte
	addq $8, %r14    # increment the instr_ptr

	// movq $str_ins_in, %rdi
	// call puts

	jmp exec_bf_next_instr


ins_jmp_fwd:

	addq $16, %r14         # increment the instr_ptr
	cmpb $0, (%rbx)        # check the pointed memory cell
	jne exec_bf_next_instr # if it's not 0, go to the next instr
	movq -8(%r14), %r14    # else, set the instr_ptr to the the jmp address

	// movq $str_ins_jmp_fwd, %rdi
	// call puts

	jmp exec_bf_next_instr

ins_jmp_bck:

	addq $16, %r14        # increment the instr_ptr
	cmpb $0, (%rbx)       # check the pointed memory cell
	je exec_bf_next_instr # if it's 0, go to the next instr
	movq -8(%r14), %r14   # else, set the instr_ptr to the the jmp address

	// movq $str_ins_jmp_bck, %rdi
	// call puts

	jmp exec_bf_next_instr


ins_zero:

	movb $0, (%rbx) # set byte to zero
	addq $8, %r14   # increment the instr_ptr

	// movq $str_ins_zero, %rdi
	// call puts

	jmp exec_bf_next_instr


ins_cpy:

	movsbq 8(%r14), %rdx   # offset -> %rdx, extending sign
	movzbl 9(%r14), %eax   # factor -> %eax, pad with zeros for multiplication
	imulb (%rbx)           # multiply the byte into %eax
	addb %al, (%rbx, %rdx) # move the byte into mem_ptr[offset]

	// movq $fmt_ins_cpy, %rdi
	// movb 8(%r14), %sil
	// movb 9(%r14), %dl
	// xorq %rax, %rax
	// call printf

	addq $10, %r14         # increment the instr_ptr
	jmp exec_bf_next_instr


ins_exit:

	# exit the program

	movl $1, %eax # exit
	movl $0, %ebx # with code 0
	int $0x80
