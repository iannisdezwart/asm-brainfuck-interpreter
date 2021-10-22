#define BUF_IO
#define IO_BUF_SIZ $1024

##define DUMP_PROGRAM

##define DUMP_STACK
#define STACK_DUMP_SIZ $256

##define PRINT_NEXT_CHARS

.text
.global main
main:

	# author: Iannis de Zwart

	# ==================================================

	# description:

	# Welcome to the source code of my optimising brainfuck compiler
	# written in x86 GNU Assembly!

	# usage: ./app input.bf

	# This program will compile the input brainfuck file with optimisations
	# into a buffer of x86 instructions. This buffer is then called.

	# ==================================================

	# parameters:

	# (arg1) %rdi: int argc
	# (arg2) %rsi: char **argv

	# ==================================================

	# locals: (554288 bytes)

	# char mem[30000]            @   -30000(%rbp)
	#   * used as the brainfuck tape
	#   * will be zeroed before use

	# uint64_t program[524288]   @ -4464304(%rbp)
	#   * stores the x86 instructions
	#   * this buffer gets called from `main()`
	#   * the last instruction will be `ret`

	# char file_buf[524288]      @ -4988592(%rbp)
	#   * the entire bf file is loaded into this buffer
	#   * discarded after compilation
	#   * overlaps with write_buf

	# char cpy_loop_arr[256]     @ -4988848(%rbp)
	#   * used to calculate copy loops
	#   * discarded after compilation
	#   * overlaps with write_buf

	# char write_buf[IO_BUF_SIZ] @ -4988848(%rbp)
	#   * used to buffer output of the program
	#   * only needed during run time
	#   * overlaps with file_buf & cpy_loop_arr


	# prologue

	pushq %rbp
	movq %rsp, %rbp
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
	# EOF: 0

	# TODO: use an actual jump table or optimise with compiler explorer
	# for better performance. However, the compile time is really short, so
	# this probably isn't worth it.

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

#ifdef PRINT_NEXT_CHARS
	movb %al, %dil
	call print_next_char
#endif

	ret


cpl_bf_read_next_char:

	# read characters from the file_buf

	call next_char


	# jump table for the current character
	# '+': 43        '<': 60
	# ',': 44        '>': 62
	# '-': 45        '[': 91
	# '.': 46        ']': 93
	# EOF: 0

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

	# INS_DEC_PTR_N_LONG(n)

	movb $0x48, (%r14)  # from %rbx
	movb $0x81, 1(%r14) # do 4-byte
	movb $0xeb, 2(%r14) # sub
	negw %bx            # (get the absolute value of n)
	movzwl %bx, %ebx    # (pad n with zeroes)
	movl %ebx, 3(%r14)  # of n

	addq $7, %r14             # increment the instr_ptr
	jne cpl_bf_read_next_char # read the next char


cpl_bf_dec_ptr_n_short:

	# INS_DEC_PTR_N_SHORT(n)

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

	# INS_INC_PTR_N_LONG(n)

	movb $0x48, (%r14)  # from %rbx
	movb $0x81, 1(%r14) # do 4-byte
	movb $0xc3, 2(%r14) # add
	movzwl %bx, %ebx    # (pad n with zeroes)
	movl %ebx, 3(%r14)  # of n

	addq $7, %r14             # increment the instr_ptr
	jne cpl_bf_read_next_char # read the next char


cpl_bf_inc_ptr_n_short:

	# INS_INC_PTR_N_SHORT(n)

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

	movb $1, %bl       # 1 -> combined chg_val argument
	jmp cpl_bf_chg_val


cpl_bf_dec_val:

	movb $-1, %bl      # -1 -> combined chg_val argument
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


cpl_bf_chg_val_n:

	# INS_CHG_VAL(n)

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

	# INS_OUT()

#ifdef BUF_IO

	# copy the current byte to the write buffer

	movb $0x8a,  (%r14)  # move (%rbx)
	movb $0x03, 1(%r14)  # into %al

	movb $0x43, 2(%r14)  # move
	movb $0x88, 3(%r14)  # %al
	movb $0x04, 4(%r14)  # into
	movb $0x37, 5(%r14)  # %r15[%r14]

	# increment the write buffer pointer

	movb $0x49, 6(%r14)  # add
	movb $0x83, 7(%r14)  # into
	movb $0xc6, 8(%r14)  # %r14
	movb $1,    9(%r14)  # 1

	# check the buffer size

	movb $0x41, 10(%r14) # cmp
	movb $0x81, 11(%r14) # to %r14
	movb $0xfe, 12(%r14) # the 4-byte value
	movl IO_BUF_SIZ, 13(%r14) # IO_BUF_SIZE

	# skip write if buffer size != IO_BUF_SIZ

	movb $0x75, 17(%r14) # jne
	movb $21,   18(%r14) # 21 bytes

	# write the bytes

	movb $0xbf, 19(%r14) # move into %edi (fd)
	movl $1,    20(%r14) # the literal value 1 (for stdout)

	movb $0x4c, 24(%r14) # move
	movb $0x89, 25(%r14) # %r15
	movb $0xfe, 26(%r14) # into %rsi

	movb $0x4c, 27(%r14) # move
	movb $0x89, 28(%r14) # %r14
	movb $0xf2, 29(%r14) # into %rdx

	movb $0xb8, 30(%r14) # move to %eax (syscall)
	movl $1,    31(%r14) # the literal value 1 (for SYS_WRITE)

	movb $0x0f, 35(%r14) # syscall
	movb $0x05, 36(%r14)

	# set buffer size to 0

	movb $0x4d, 37(%r14) # xor
	movb $0x31, 38(%r14) # %r14
	movb $0xf6, 39(%r14) # with %r14

	addq $40, %r14            # increment the instr_ptr
	jmp cpl_bf_read_next_char # read the next char

#else

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

#endif


cpl_bf_in:

	# INS_IN()

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

	# check special loops: [+], [-], [<], [>]

	cmpb $93, 1(%r15)         # compare 3rd byte to ']'
	jne cpl_bf_cpy_loop_check # if it doesn't match, scan copy loop

	cmpb $43, (%r15)          # compare 2nd byte to '+'
	je cpl_bf_clear_loop      # if it matches, handle clear loop

	cmpb $45, (%r15)          # compare 2nd byte to '-'
	je cpl_bf_clear_loop      # if it matches, handle clear loop

	cmpb $60, (%r15)          # compare 2nd byte to '<'
	je cpl_bf_left_z_loop     # if it matches, handle [<] left zero loop

	cmpb $62, (%r15)          # compare 2nd byte to '>'
	je cpl_bf_right_z_loop    # if it matches, handle [>] right zero loop

	jmp cpl_bf_jmp_fwd_1      # neither a special loop, nor a copy loop: skip


cpl_bf_cpy_loop_check:

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

	# copy instruction
	# INS_CPY(off, fac)

	movb $0x0f,  (%r14)  # movzbl
	movb $0xb6, 1(%r14)  # (%rbx)
	movb $0x03, 2(%r14)  # into %eax

	movb $0x48, 3(%r14)  # move 64-bit value
	movb $0xbf, 4(%r14)  # into %rdi
	movq %r12, 5(%r14)   # the offset

	movb $0x69, 13(%r14)  # imull
	movb $0xc0, 14(%r14)  # into %eax
	movb (%rbx), %sil     # (load the factor)
	movl %esi, 15(%r14)   # the factor

	movb $0x00, 19(%r14)  # movb
	movb $0x04, 20(%r14)  # %al
	movb $0x3b, 21(%r14)  # into %rbx[%rdi]

	addq $22, %r14        # increment the instr_ptr


cpl_bf_jmp_fwd_cpy_loop_end_2:

	addq $1, %rbx   # increment the cpy_loop_ptr
	cmpq %r10, %rbx # if cpy_loop_ptr != cpy_loop_arr + 256, next iter
	jne cpl_bf_jmp_fwd_cpy_loop_end_1


cpl_bf_zero_byte:

	# zero the current byte
	# INS_ZERO()

	movb $0xc6, (%r14)   # movb
	movb $0x03, 1(%r14)  # into (%rbx)
	movb $0x00, 2(%r14)  # the value 0

	addq $3, %r14             # increment the instr_ptr
	jmp cpl_bf_read_next_char # read the next char


cpl_bf_clear_loop:

	addq $2, %r15        # move file_buf ptr to the char after the ']'
	jmp cpl_bf_zero_byte # zero (%rbx)


cpl_bf_right_z_loop:

	# INS_FIND_RIGHT_ZERO()

	addq $2, %r15        # move file_buf ptr to the char after the ']'

	movb $0xeb,  (%r14)  # jmp
	movb $4,    1(%r14)  # 4 bytes

	# increment the tape pointer

	movb $0x48, 2(%r14)  # add
	movb $0x83, 3(%r14)  # into
	movb $0xc3, 4(%r14)  # %rbx
	movb $1,    5(%r14)  # the value 1

	# check if the current pointed byte is 0

	movb $0x80, 6(%r14)  # cmp
	movb $0x3b, 7(%r14)  # to (%rbx)
	movb $0,    8(%r14)  # the value 0

	# jump to increment again if it's not 0

	movb $0x75, 9(%r14)  # jne
	movb $-9,  10(%r14)  # 9 bytes back

	addq $11, %r14            # increment the instr_ptr
	jmp cpl_bf_read_next_char # read the next char


cpl_bf_left_z_loop:

	# INS_FIND_LEFT_ZERO()

	addq $2, %r15        # move file_buf ptr to the char after the ']'

	movb $0xeb,  (%r14)  # jmp
	movb $4,    1(%r14)  # 4 bytes

	# decrement the tape pointer

	movb $0x48, 2(%r14)  # subtract
	movb $0x83, 3(%r14)  # from
	movb $0xeb, 4(%r14)  # %rbx
	movb $1,    5(%r14)  # the value 1

	# check if the current pointed byte is 0

	movb $0x80, 6(%r14)  # cmp
	movb $0x3b, 7(%r14)  # to (%rbx)
	movb $0,    8(%r14)  # the value 0

	# jump to decrement again if it's not 0

	movb $0x75, 9(%r14)  # jne
	movb $-9,  10(%r14)  # 9 bytes back

	addq $11, %r14            # increment the instr_ptr
	jmp cpl_bf_read_next_char # read the next char


cpl_bf_jmp_fwd_1:

	# INS_JMP_FWD(addr)

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

	# INS_JMP_BCK(addr)

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

	# at the end of execution, pass control back to main
	# INS_EXIT()

	movb $0xc3, (%r14)  # ret


	# fall through to executing the compiled code


exec_bf:

	# zero initialise the tape

	leaq -30000(%rbp), %rbx  # store a pointer to the start of the memory in %rbx
	movq %rbx, %rdi          # pointer to start of memory -> %rdi (arg1)
	movq $30000, %rsi        # put the number of elements of the memory into %rsi (arg2)
	call bzero               # zero the memory


	# print the compiled x86 opcode buffer

#ifdef DUMP_PROGRAM
	leaq -4464304(%rbp), %rdi
	movq %r14, %rsi
	call print_prgm
#endif


#ifdef BUF_IO

	# store pointer to output buffer and output buffer index

	leaq -4988848(%rbp), %r15  # pointer to the start of the output buffer
	movq $0, %r14              # output buffer index = 0

#endif


	# call the program

	leaq -4464304(%rbp), %rax  # pointer to the start of the program buffer
	call *%rax                 # call the pointer


#ifdef BUF_IO

	# print the remaining output

	cmpq $0, %r14   # check if there are bytes to write
	je skip_io      # if not, skip

	movl $1, %edi   # stdout file descriptor
	movq %r15, %rsi # write buffer
	movq %r14, %rdx # number of bytes to write
	movl $1, %eax   # SYS_WRITE
	syscall

#endif


skip_io:


	# print the output stack

#ifdef DUMP_STACK
	leaq -30000(%rbp), %rdi
	movq STACK_DUMP_SIZ, %rsi
	call print_stack
#endif

	# epilogue for main()

	movq %rbp, %rsp
	popq %rbp


	# exit the program

	xorq %rax, %rax # exit code 0
	ret
