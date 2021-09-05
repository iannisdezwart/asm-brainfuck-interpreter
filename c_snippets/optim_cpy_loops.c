#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
	char cpy_arr[100] = {};
	char *cpy_ptr = cpy_arr + 50;

	if (argc < 2)
	{
		fputs("usage: ./program \"input string [->+<]\"", stderr);
		exit(0);
	}

	char *str = argv[1];
	char *str_end;

	if (str[0] != '[')
	{
		puts("doesn't start with [");
		goto end;
	}

	// if (str[1] != '-')
	// {
	// 	puts("doesn't start with [-");
	// 	strcpy(out_ptr, str);
	// 	goto end;
	// }

	// *cpy_ptr = -1;

	// Check if this is a 1d loop

	for (char *c = str + 1; *c != '\0'; c++)
	{
		if (cpy_ptr < cpy_arr)
		{
			puts("cpy_ptr offset < max");
			goto end;
		}

		if (cpy_ptr >= cpy_arr + 100)
		{
			puts("cpy_ptr offset > max");
			goto end;
		}

		if (*c == '[')
		{
			puts("2d loop");
			goto end;
		}

		else if (*c == '<')
		{
			cpy_ptr--;
		}

		else if (*c == '>')
		{
			cpy_ptr++;
		}

		else if (*c == '-')
		{
			(*cpy_ptr)--;
		}

		else if (*c == ',')
		{
			puts("found a ,");
			goto end;
		}

		else if (*c == '.')
		{
			puts("found a .");
			goto end;
		}

		else if (*c == '+')
		{
			(*cpy_ptr)++;
		}

		if (*c == ']')
		{
			str_end = c;
		}
	}

	if (cpy_ptr != cpy_arr + 50)
	{
		puts("doesn't end at the start");
		goto end;
	}

	if (*cpy_ptr != -1)
	{
		puts("start didn't decrement by 1");
		goto end;
	}

	for (cpy_ptr = cpy_arr; cpy_ptr != cpy_arr + 100; cpy_ptr++)
	{
		if (*cpy_ptr != 0 && cpy_ptr != cpy_arr + 50)
		{
			printf("CPY(x%hhu, @%ld)\n", *cpy_ptr, cpy_ptr - cpy_arr - 50);
		}
	}

	printf("ZERO(@0)\n");

	end:;
}