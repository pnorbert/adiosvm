include ../make.settings

## Set ADIOS1_DIR here or before doing make
override ADIOS1_INC=`${ADIOS1_DIR}/bin/adios_config -c`
override ADIOS1_CLIB=`${ADIOS1_DIR}/bin/adios_config -l`


default: test_range 
all: default

OBJS = utils.o decompose_block.o 

%.o: %.c
	${CC} ${CFLAGS} -c ${ADIOS1_INC} $<

test_range: ${OBJS} test_range.o
	OMPI_CXX=${OMPI_CXX} ${LINKER} ${LDFLAGS} -o test_range ${OBJS} test_range.o ${ADIOS1_CLIB}

#test_query: ${OBJS} test_query.o
#	${LINKER} ${LDFLAGS} -o test_query ${OBJS} test_query.o ${ADIOS1_CLIB}

clean:
	rm -f *.o *.mod *.fh core.*
	rm -f test_range test_query


distclean: clean
	rm -f log.* *.bp *.png

