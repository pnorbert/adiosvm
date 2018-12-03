include ../Makefile.inc

all: var_checks norm_calc norm_calc2 fft3d_calc
	@echo -n "\n------ DONE BUILDING ANALYSIS analysis/norm_calc ------\n"

norm_calc: var_checks norm_calc.cpp
	@set -e; ${CXX} ${CXXFLAGS} norm_calc.cpp -o norm_calc -I ${ADIOS2_DIR}/include/ ${ADIOS2_LIB}

norm_calc2: var_checks norm_calc2.cpp
	@set -e; ${CXX} ${CXXFLAGS} norm_calc2.cpp -o norm_calc2 -I ${ADIOS2_DIR}/include/ ${ADIOS2_LIB}

fft3d_calc: var_checks fft3d_calc.cpp
	${CXX} ${CXXFLAGS} ${FFTW_INC} fft3d_calc.cpp -o fft3d_calc -I ${ADIOS2_DIR}/include/ ${ADIOS2_LIB} ${PFFTW_LIB}

clean:
	rm -f *.o norm_calc
cleanall: clean

.PHONY: all clean cleanall

