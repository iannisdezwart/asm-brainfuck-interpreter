#include <bits/stdc++.h>

#define COMM_OLD "./app_old bf_programs/hanoi.bf > /dev/null"
#define COMM_NEW "./app bf_programs/hanoi.bf > /dev/null"
#define BATCHES 20

std::pair<size_t, size_t> bench()
{
	auto start_old = std::chrono::high_resolution_clock::now();

	system(COMM_OLD);

	auto end_old = std::chrono::high_resolution_clock::now();

	auto start_new = std::chrono::high_resolution_clock::now();

	system(COMM_NEW);

	auto end_new = std::chrono::high_resolution_clock::now();

	return {
		std::chrono::duration_cast<std::chrono::microseconds>(
			end_old - start_old).count(),
		std::chrono::duration_cast<std::chrono::microseconds>(
			end_new - start_new).count()
	};
}

int main()
{
	size_t mean_old = 0;
	size_t mean_new = 0;

	for (size_t i = 0; i < BATCHES; i++)
	{
		std::pair<size_t, size_t> batch = bench();
		mean_old += batch.first;
		mean_new += batch.second;

		printf("batch %03ld: %06ldus (old) vs %06ldus (new)\n",
			i, batch.first, batch.second);
	}

	mean_old /= BATCHES;
	mean_new /= BATCHES;

	printf("avg runtime for old: %06ldus\n", mean_old);
	printf("avg runtime for new:  %06ldus\n", mean_new);
}