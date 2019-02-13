include ../Makefile.inc

all: var_checks norm_calc norm_calc2
	@echo -n "\n------ DONE BUILDING ANALYSIS analysis/norm_calc ------\n"

norm_calc: var_checks norm_calc.cpp
	@set -e; ${CXX} ${CXXFLAGS} norm_calc.cpp -o norm_calc  ${ADIOS2_CXXFLAGS} ${ADIOS2_CXXLIB}

norm_calc2: var_checks norm_calc2.cpp
	@set -e; ${CXX} ${CXXFLAGS} norm_calc2.cpp -o norm_calc2 ${ADIOS2_CXXFLAGS} ${ADIOS2_CXXLIB}

clean:
	rm -f *.o norm_calc norm_calc2
cleanall: clean

.PHONY: all clean cleanall

