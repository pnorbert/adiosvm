include ../Makefile.inc

all: norm_calc
	@echo -e "\n------ DONE BUILDING ANALYSIS ------\n"

norm_calc: norm_calc.cpp
	${CXX} ${CXXFLAGS} norm_calc.cpp -o norm_calc -I ${ADIOS2_DIR}/include/ ${ADIOS2_LIB}

clean:
	rm -f *.o norm_calc
cleanall: clean

.PHONY: all clean cleanall

