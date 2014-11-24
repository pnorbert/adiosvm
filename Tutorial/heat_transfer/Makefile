include make.settings

## Set ADIOS_DIR here or before doing make
override ADIOS_FINC=`${ADIOS_DIR}/bin/adios_config -c -f`
override ADIOS_FLIB=`${ADIOS_DIR}/bin/adios_config -l -f`

default: heat_transfer
all: default

heat_transfer.o : heat_transfer.F90 
	${FC} ${FFLAGS} -c ${ADIOS_FINC} heat_transfer.F90  $<

heat_transfer:  heat_transfer.o
	${FC} ${FFLAGS} -o heat_transfer heat_transfer.o ${ADIOS_FLIB} 


clean:
	rm -f *.o *.mod *.fh core.*
	rm -f heat_transfer

distclean: clean
	rm -rf *.png *.bp *.bp.dir

