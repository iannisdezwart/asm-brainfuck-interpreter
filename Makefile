app: app.s
	cpp app.s > app.pp.s
	gcc -no-pie -o app -g app.pp.s debug.c
	rm app.pp.s

clean:
	rm -f app.o app

dump:
	objdump -D -m i386:x86-64 -b binary disass.bin