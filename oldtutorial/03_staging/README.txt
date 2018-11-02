== Compile ==
There are two options:
Option #1 - write to bp files (reader_NNN.bp)
Option #2 - draw a plot by using gnuplot
       #2a  - save plot to a file
       #2b  - show plots interactively one by one

Default is #1. To enable #2, use -D_USE_GNUPLOT macro when compiling
(See Makefile).
For #2b, use -D_GNUPLOT_INTERACTIVE macro when compiling

== Run == 
Need to use the same number of processes for writing (arrays_write)
and reading (arrays_reading)

$ mpirun -np 2 ./arrays_read

in another terminal, run the writer

$ mpirun -np 2 ./arrays_writer


## $ mpiexec  --mca mpi_warn_on_fork 0 -n 1 arrays_read
## $ mpiexec  --mca mpi_warn_on_fork 0 -n 1 arrays_write

== Plotting
If used GNUPLOT, you have the plots done, otherwise, run
$ ./plot.sh

== See generated images:

$ eog .


