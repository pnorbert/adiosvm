.PHONY: clean

CC      := mpicc
CFLAGS  := -g -O0 $(shell adios_config -c) # -D_USE_GNUPLOT #-D_GNUPLOT_INTERACTIVE
LDFLAGS := $(shell adios_config -l)

all: arrays_write arrays_read

arrays_write: arrays_write.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

arrays_read: arrays_read.c
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

clean:
	rm -f arrays_write arrays_read *.o *.*~ arrays_*.txt reader*.bp *.png
	rm -rf *.dSYM

