# Set options to allow for conditional compilation, use only one of the options below
# These are processed using the C pre-processor
#
#
OPTIONS= 
CPP=-cpp
	# All settings here for use Muite Laptop

	COMPILER =  mpif90  
	decompdir=./2decomp_fft
	FFTW_LINK=./fftwinstall
	FFTW_DIR?=
	ADIOS2_DIR?=
	# compilation settings, optimization, precision, parallelization
	FLAGS = -O3 -DADIOS2
	
	INCLUDES = -I${FFTW_DIR}/include -I${decompdir}/include -I${ADIOS2_DIR}/include/fortran

	FFTW_LIB = -L${FFTW_DIR}/lib -lfftw3
	DECOMPLIB = -L${decompdir}/lib -l2decomp_fft
	ADIOS2_LIB =-L${ADIOS2_DIR}/lib -ladios2_f -ladios2 -ladios2_sst -ladios2_evpath -ladios2_ffs -ladios2_dill -ladios2_atl
	LIBS = ${FFTW_LIB} ${DECOMPLIB} ${ADIOS2_LIB}

# libraries
# source list for main program

SOURCES = brusselator.f90 initialdata.f90 savedata.f90 getgrid.f90 \
		 linear.f90 nonlinear1.f90 nonlinear2.f90 

OBJECTS = brusselator.o initialdata.o savedata.o getgrid.o \
		 linear.o nonlinear1.o nonlinear2.o 


Brusselator: $(OBJECTS)
		${COMPILER} -o Brusselator  $(FLAGS) $(FLAGS) $(CPP) $(OBJECTS) $(LIBS)

brusselator.o : brusselator.f90 savedata.o
		${COMPILER} -c $(FLAGS) $(CPP) $(INCLUDES) brusselator.f90

savedata.o : savedata.f90
		${COMPILER} -c $(FLAGS) $(CPP) $(INCLUDES) savedata.f90

initialdata.o : initialdata.f90
		${COMPILER} -c $(FLAGS) $(CPP) $(INCLUDES) initialdata.f90

getgrid.o : savedata.o  getgrid.f90
		${COMPILER} -c $(FLAGS) $(CPP) $(INCLUDES) getgrid.f90

linear.o : linear.f90
		${COMPILER} -c $(FLAGS) $(CPP) $(INCLUDES) linear.f90

nonlinear1.o : nonlinear1.f90
		${COMPILER} -c $(FLAGS) $(CPP) $(INCLUDES) nonlinear1.f90

nonlinear2.o : nonlinear2.f90
		${COMPILER} -c $(FLAGS) $(CPP) $(INCLUDES) nonlinear2.f90


clean:
	rm -f *.o *.mod
clobber:	
	rm -f Brusselator

