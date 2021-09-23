.PHONY: app
app: app.s
	cpp app.s > app.pp.s
	gcc -no-pie -o app -g app.pp.s debug.c
	rm app.pp.s

.PHONY: bench
bench:
	g++ bench.cpp -o bench -O3

dump:
	objdump -D -m i386:x86-64 -b binary disass.bin