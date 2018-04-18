include ../make.settings

## Set ADIOS1_DIR here or before doing make
override ADIOS1_INC=`${ADIOS1_DIR}/bin/adios_config -c`
override ADIOS1_CLIB=`${ADIOS1_DIR}/bin/adios_config -l`


default: stage_write 
all: default

OBJS = utils.o decompose_block.o 

%.o: %.c
	${CC} ${CFLAGS} -c ${ADIOS1_INC} $<

stage_write: ${OBJS} stage_write.o
	${CC} ${LDFLAGS} -o stage_write ${OBJS} stage_write.o ${ADIOS1_CLIB}

test_decompose: ${OBJS} test_decompose.o 
	${CC} ${LDFLAGS} -o test_decompose ${OBJS} test_decompose.o ${ADIOS1_CLIB}


clean-code:
	rm -f *.o *.mod *.fh core.*
	rm -f stage_write

clean-data: 
	rm -f log.* dataspaces.conf conf srv.lck 
	rm -rf *.png *.bp *.bp.dir

distclean: clean-code clean-data
clean: clean-code clean-data

