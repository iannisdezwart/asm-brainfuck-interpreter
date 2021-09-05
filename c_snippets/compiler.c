#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <strings.h>

#define STACK_PUSH(A) (*stack_ptr++ = A)
#define STACK_POP()   (*--stack_ptr)

#define INC_PTR 0
#define DEC_PTR 1
#define INC_VAL 2
#define DEC_VAL 3
#define OUT     4
#define IN      5
#define JMP_FWD 6
#define JMP_BCK 7
#define EXIT    8

void interpret_brainfuck(char *file_name /* %rdi */)
{
	char mem[30000]; // -30000(%rbp)
	uint64_t program[524288]; // -554288(%rbp)
	uint64_t *stack[512];

	FILE *fp; // %r15

	fp = fopen(
		file_name, // %rdi
		"r"        // $read_f_mode_str
	);

	// EOL file_name %rdi

	// Compile the file

	int c; // %rax
	uint64_t *instr_ptr = program; // %r14
	uint64_t **stack_ptr = stack;

	while ((c = getc(fp) /* c -> %rax */) != EOF)
	{
		switch (c)
		{
			case '>': *instr_ptr++ = INC_PTR; break;
			case '<': *instr_ptr++ = DEC_PTR; break;
			case '+': *instr_ptr++ = INC_VAL; break;
			case '-': *instr_ptr++ = DEC_VAL; break;
			case '.': *instr_ptr++ = OUT;     break;
			case ',': *instr_ptr++ = IN;      break;
			default:                          break;

			case '[':
			{
				STACK_PUSH(instr_ptr);
				instr_ptr[0] = JMP_FWD;
				instr_ptr += 2; // Jump address will be filled in later
				break;
			}

			case ']':
			{
				uint64_t *jump_addr = STACK_POP(); // %rax
				instr_ptr[0] = JMP_BCK;
				instr_ptr[1] = jump_addr;
				jump_addr[1] = instr_ptr; // Fill in forward jump address
				instr_ptr += 2;
				break;
			}
		}
	}

	// EOL c %rax
	// EOL fp %r15

	*instr_ptr++ = EXIT;

	// Execute the program

	char *mem_ptr = mem; // %rbx
	bzero(mem_ptr, 30000);
	instr_ptr = program;

next_instr:
	switch (instr_ptr[0])
	{
		case INC_PTR: mem_ptr++;            instr_ptr++; break;
		case DEC_PTR: mem_ptr--;            instr_ptr++; break;
		case INC_VAL: (*mem_ptr)++;         instr_ptr++; break;
		case DEC_VAL: (*mem_ptr)--;         instr_ptr++; break;
		case OUT:     putchar(*mem_ptr);    instr_ptr++; break;
		case IN:      *mem_ptr = getchar(); instr_ptr++; break;

		case JMP_FWD:
		{
			instr_ptr += 2;

			if (!*mem_ptr)
			{
				uint64_t *jmp_fwd_addr = instr_ptr[-1]; // %rax
				instr_ptr = jmp_fwd_addr;
			}

			break;
		}

		case JMP_BCK:
		{
			instr_ptr += 2;

			if (*mem_ptr)
			{
				uint64_t *jmp_bck_addr = instr_ptr[-1]; // %rax
				instr_ptr = jmp_bck_addr;
			}

			break;
		}

		case EXIT: exit(0); 
	}

	goto next_instr;
}

int main(int argc, char **argv)
{
	interpret_brainfuck(argv[1]);
}