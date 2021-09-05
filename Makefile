app: main.c app.o
	gcc -no-pie main.c app.o -o app -g

app.o: app.s
	cpp app.s > app.pp.s
	gcc -c app.pp.s -o app.o -g
	rm app.pp.s

clean:
	rm -f app.o app