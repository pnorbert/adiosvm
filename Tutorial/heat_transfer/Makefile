include make.settings

## Set ADIOS_DIR here or before doing make
override ADIOS_FINC=-I${ADIOS_DIR}/include
override ADIOS_FLIB=`${ADIOS_DIR}/bin/adios_config -l -f`

default: 
	@echo "Make targets: adios mpiio hdf5 phdf5"
	@echo "  adios:  build example with ADIOS  (io_adios.F90)"
	@echo "  mpiio:  build example with MPI-IO (io_mpiio.F90)"
	@echo "  hdf5:   build example with HDF5   (io_hdf5.F90)"
	@echo "  phdf5:  build example with Parallel HDF5  (io_phdf5.F90)"


all: default
help: default


%.o : %.F90 
	${FC} ${FFLAGS} -c ${ADIOS_FINC} $<

adios: heat_vars.o io_adios.o heat_transfer.o
	${FC} ${FFLAGS} -o heat_transfer $^ ${ADIOS_FLIB} 


clean:
	rm -f *.o *.mod *.fh core.*
	rm -f heat_transfer

distclean: clean
	rm -rf *.png *.bp *.bp.dir

