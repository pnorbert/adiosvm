CXX=mpicxx
ADIOS2_DIR?=

norm_calc: norm_calc.cpp
	${CXX} norm_calc.cpp -o norm_calc -I ${ADIOS2_DIR}/include/ -L ${ADIOS2_DIR}/lib/ -l adios2 -ladios2_sst -ladios2_evpath -ladios2_ffs -ladios2_dill -ladios2_atl


.PHONY:
all: norm_calc
clean:
	rm -f *.o
cleanall: clean
	rm -f norm_calc

