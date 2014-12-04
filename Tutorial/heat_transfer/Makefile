include make.settings

## Set ADIOS_DIR here or before doing make
override ADIOS_FINC=-I${ADIOS_DIR}/include
override ADIOS_FLIB=`${ADIOS_DIR}/bin/adios_config -l -f`

default: 
	@echo "Make targets: fort adios hdf5 phdf5"
	@echo "  fort:   build example with text output(io_fort.F90)"
	@echo "  adios:  build example with ADIOS  (io_adios.F90)"
	@echo "  hdf5:   build example with HDF5   (io_hdf5.F90)"
	@echo "  phdf5:  build example with Parallel HDF5  (io_phdf5.F90)"


all: default
help: default


%.o : %.F90 
	${FC} ${FFLAGS} -c ${ADIOS_FINC} $<

fort: heat_vars.o io_fort.o heat_transfer.o
	${FC} ${FFLAGS} -o heat_transfer_fort $^ ${ADIOS_FLIB} 

adios: heat_vars.o io_adios.o heat_transfer.o
	${FC} ${FFLAGS} -o heat_transfer_adios $^ ${ADIOS_FLIB} 


clean:
	rm -f *.o *.mod *.fh core.*
	rm -f heat_transfer_fort heat_transfer_adios 
	rm -f heat_transfer_hdf5 heat_transfer_phdf5

distclean: clean
	rm -f fort.*
	rm -rf *.png *.bp *.bp.dir

