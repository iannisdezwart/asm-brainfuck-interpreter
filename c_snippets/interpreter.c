#include <stdio.h>

void interpret_brainfuck(char *file_name)
{
	FILE *file;
	int c;
	char mem[3000] = {};
	char *ptr = mem;

	file = fopen(file_name, "r");

	while ((c = fgetc(file)) != EOF)
	{
		switch (c)
		{
			case '>':
				ptr++;
				break;

			case '<':
				ptr--;
				break;

			case '+':
				(*ptr)++;
				break;

			case '-':
				(*ptr)--;
				break;

			case '.':
				putchar(*ptr);
				break;

			case ',':
				*ptr = getchar();
				break;

			case '[':
				if (*ptr == 0)
				{
					int loop = 1;

					while (loop > 0)
					{
						int ch = fgetc(file);

						if (ch == '[')
						{
							loop++;
						}
						else if (ch == ']')
						{
							loop--;
						}
					}
				}

				break;

			case ']':
				if (*ptr)
				{
					int loop = 1;

					while (loop > 0)
					{
						fseek(file, -2, SEEK_CUR);
						int ch = fgetc(file);

						if (ch == '[')
						{
							loop--;
						}
						else if (ch == ']')
						{
							loop++;
						}
					}
				}

				break;
		}
	}
}

int main(int argc, char **argv)
{
	interpret_brainfuck(argv[1]);
}
