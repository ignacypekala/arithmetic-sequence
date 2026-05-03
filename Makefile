CC=gcc
CPP=g++
NASMFLAGS=-f elf64 -w+all -w+error
CFLAGS=-Wall -Wextra -std=c23 -O2
CPPFLAGS=-Wall -Wextra -std=c++23 -O2

NASMFLAGS += -g
CFLAGS += -g
CPPFLAGS += -g


.PHONY: clean all
all: arithmetic_sequence_example_c arithmetic_sequence_example_cpp

# arithmetic_sequence.o: arithmetic_sequence.c
# 	$(CC) -c $(CFLAGS) -o $@ $<
arithmetic_sequence.o: arithmetic_sequence.asm
	nasm $(NASMFLAGS) -o $@ $<

arithmetic_sequence_example_c: arithmetic_sequence_example_c.o arithmetic_sequence.o
	$(CC) -z noexecstack -o $@ $^

arithmetic_sequence_example_c.o: arithmetic_sequence_example.c test_data.c
	$(CC) -c $(CFLAGS) -o $@ $< 

arithmetic_sequence_example_cpp: arithmetic_sequence_example_cpp.o arithmetic_sequence.o 
	$(CPP) -z noexecstack -o $@ $^ -lgmp

arithmetic_sequence_example_cpp.o: arithmetic_sequence_example.cpp
	$(CPP) -c $(CPPFLAGS) -o $@ $<

clean:
	rm -f *.o arithmetic_sequence_example_c arithmetic_sequence_example_cpp
