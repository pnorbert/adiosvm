CXX=mpicxx
ADIOS2_DIR?=

analysis: analysis.cpp
	${CXX} analysis.cpp -I ${ADIOS2_DIR}/include/ -L ${ADIOS2_DIR}/lib/ -l adios2 -ladios2_sst -ladios2_evpath -ladios2_ffs -ladios2_dill -ladios2_atl


.PHONY:
all: analysis
clean:
	rm -f *.o
cleanall: clean
	rm -f analysis

