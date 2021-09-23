#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

void
print_prgm(unsigned char *prgm, unsigned char *prgm_end)
{
	size_t len = prgm_end - prgm;

	printf("PROGRAM (0x%lx bytes/%ld bytes):\n", len, len);
	puts("       00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F\n");

	for (size_t i = 0; i < len; i += 16)
	{
		printf("%04lx   ", i);

		for (size_t j = i; j < i + 16 && j < len; ++j)
		{
			printf("%02x ", prgm[j]);
		}

		printf("\n");
	}

	FILE *file = fopen("disass.bin", "w");
	fwrite(prgm, len, 1, file);
	fclose(file);
}

void
print_stack(unsigned char *stack, size_t len)
{
	printf("STACK (0x%lx bytes/%ld bytes):\n", len, len);
	puts("       00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F\n");

	for (size_t i = 0; i < len; i += 16)
	{
		printf("%04lx   ", i);

		for (size_t j = i; j < i + 16 && j < len; ++j)
		{
			printf("%02x ", stack[j]);
		}

		printf("\n");
	}
}