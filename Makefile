CC= gcc
CFLAGS= -std=c99 -pedantic -Wall -Wextra -Werror -Wvla

SRC=$(wildcard *.c)
OBJ=$(SRC:.c=.o)
STATIC=libprogram.a
SHARED=libprogram.so
BIN=program

all: $(BIN) $(STATIC) $(SHARED)

static: $(STATIC)
$(STATIC): $(OBJ)
	$(AR) csr $@ $^

shared: $(SHARED)
$(SHARED): $(OBJ)
	$(CC) -fPIC -shared -o $@ $^

exe: $(BIN)
$(BIN): $(OBJ)
	$(CC) $(CFLAGS) $^ -o $@

clean:
	$(RM) $(OBJ) $(BIN) $(STATIC) $(SHARED)

# $(wildcard *.c) take all .c files
# $(SRC:.c=.o) translate all .c to .o
# Static for static library
# Shared for shared library
# $< take first dependencie
# $^ take all dependencies
# $@ take target
