CFLAGS=-std=c99 -O2 -pedantic -Wall
CC=gcc

.PHONY:all
all: readfile

.PHONY:clean
clean:
	rm -rf readfile

readfile: readfile.c
	$(CC) $(CFLAGS) -o readfile $^
