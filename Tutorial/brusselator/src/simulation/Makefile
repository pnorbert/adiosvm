# Set options to allow for conditional compilation, use only one of the options below
# These are processed using the C pre-processor
#
#

include ../Makefile.inc

SOURCES = brusselator.f90 initialdata.f90 savedata.f90 getgrid.f90 \
		 linear.f90 nonlinear1.f90 nonlinear2.f90 

OBJECTS = brusselator.o initialdata.o savedata.o getgrid.o \
		 linear.o nonlinear1.o nonlinear2.o 

all : var_checks Brusselator
	@echo -n "\n------ DONE BUILDING SIMULATION simulation/Brusselator ------\n"

2decomp_fft: var_checks
	cd 2decomp_fft; $(MAKE)

Brusselator: var_checks 2decomp_fft  $(OBJECTS)
		${FC} -o Brusselator  $(OBJECTS) $(LIBS)

brusselator.o : brusselator.f90 savedata.o
		${FC} -c $(FFLAGS) $(INCLUDES) brusselator.f90

savedata.o : savedata.f90
		${FC} -c $(FFLAGS) $(INCLUDES) savedata.f90

initialdata.o : initialdata.f90
		${FC} -c $(FFLAGS) $(INCLUDES) initialdata.f90

getgrid.o : savedata.o  getgrid.f90
		${FC} -c $(FFLAGS) $(INCLUDES) getgrid.f90

linear.o : linear.f90
		${FC} -c $(FFLAGS) $(INCLUDES) linear.f90

nonlinear1.o : nonlinear1.f90
		${FC} -c $(FFLAGS) $(INCLUDES) nonlinear1.f90

nonlinear2.o : nonlinear2.f90
		${FC} -c $(FFLAGS) $(INCLUDES) nonlinear2.f90

clean:
	rm -f *.o *.mod
	rm -f Brusselator

cleanall: clean
	cd 2decomp_fft; ${MAKE} clean

.PHONY: 2decomp_fft clean cleanall

