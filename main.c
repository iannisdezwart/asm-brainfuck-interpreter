#include <stdio.h>

void interpret_brainfuck(char *file); // Implemented in Assembly

int main(int argc, char **argv)
{
	interpret_brainfuck(argv[1]); // Doesn't return
}