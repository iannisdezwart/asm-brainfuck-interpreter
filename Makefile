app: app.s
	gcc -no-pie -o app -g app.s

clean:
	rm -f app.o app