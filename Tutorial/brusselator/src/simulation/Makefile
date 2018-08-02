# Set options to allow for conditional compilation, use only one of the options below
# These are processed using the C pre-processor
#
#
FC = mpif90
decompdir=./2decomp_fft
FFTW_DIR?=
ADIOS2_DIR?=
FLAGS=-cpp -O3 -DADIOS2

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
		${FC} -o Brusselator  $(OBJECTS) $(LIBS)

brusselator.o : brusselator.f90 savedata.o
		${FC} -c $(FLAGS) $(INCLUDES) brusselator.f90

savedata.o : savedata.f90
		${FC} -c $(FLAGS) $(INCLUDES) savedata.f90

initialdata.o : initialdata.f90
		${FC} -c $(FLAGS) $(INCLUDES) initialdata.f90

getgrid.o : savedata.o  getgrid.f90
		${FC} -c $(FLAGS) $(INCLUDES) getgrid.f90

linear.o : linear.f90
		${FC} -c $(FLAGS) $(INCLUDES) linear.f90

nonlinear1.o : nonlinear1.f90
		${FC} -c $(FLAGS) $(INCLUDES) nonlinear1.f90

nonlinear2.o : nonlinear2.f90
		${FC} -c $(FLAGS) $(INCLUDES) nonlinear2.f90


clean:
	rm -f *.o *.mod
cleanall: clean	
	rm -f Brusselator

