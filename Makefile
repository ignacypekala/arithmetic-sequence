CC=gcc
CPP=g++
CFLAGS=-Wall -Wextra -std=c23 -O2
CPPFLAGS=-Wall -Wextra -std=c++23 -O2

.PHONY: clean all
all: arithmetic_sequence_example_c arithmetic_sequence_example_cpp

arithmetic_sequence.o: arithmetic_sequence.asm
	nasm -f elf64 -w+all -w+error -o $@ $<

arithmetic_sequence_example_c: arithmetic_sequence_example_c.o arithmetic_sequence.o
	$(CC) -z noexecstack -o $@ $^

arithmetic_sequence_example_c.o: arithmetic_sequence_example.c
	$(CC) -c $(CFLAGS) -o $@ $< 

arithmetic_sequence_example_cpp: arithmetic_sequence_example_cpp.o arithmetic_sequence.o 
	$(CPP) -z noexecstack -o $@ $^ -lgmp

arithmetic_sequence_example_cpp.o: arithmetic_sequence_example.cpp
	$(CPP) -c $(CPPFLAGS) -o $@ $<

clean:
	rm -f *.o arithmetic_sequence_example_c arithmetic_sequence_example_cpp
