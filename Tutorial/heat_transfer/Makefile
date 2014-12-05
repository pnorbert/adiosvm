include make.settings

## Set ADIOS_DIR here or before doing make
override ADIOS_FINC=-I${ADIOS_DIR}/include
override ADIOS_FLIB=`${ADIOS_DIR}/bin/adios_config -l -f`

default: 
	@echo "Make targets: fort adios hdf5 phdf5"
	@echo "  fort:          build example with text output(io_fort.F90)"
	@echo "  adios:         build example with ADIOS  (io_adios.F90)"
	@echo "  hdf5:          build example with HDF5   (io_hdf5.F90)"
	@echo "  phdf5:         build example with Parallel HDF5  (io_phdf5.F90)"

all: default
help: default


io_hdf5.o : io_hdf5.F90 
	${FC} ${FFLAGS} -c ${HDF5_FINC} $< 

io_phdf5.o : io_phdf5.F90 
	${FC} ${FFLAGS} -c ${PHDF5_FINC} $< 

io_adios.o : io_adios.F90 
	${FC} ${FFLAGS} -c ${ADIOS_FINC} $< 

%.o : %.F90 
	${FC} ${FFLAGS} -c $< 

fort: heat_vars.o io_fort.o heat_transfer.o
	${FC} ${FFLAGS} -o heat_transfer_fort $^ 

hdf5: heat_vars.o io_hdf5.o heat_transfer.o
	libtool --mode=link --tag=FC ${FC} ${FFLAGS} -o heat_transfer_hdf5 $^ ${HDF5_FLIB} 

phdf5: heat_vars.o io_phdf5.o heat_transfer.o
	libtool --mode=link --tag=FC ${FC} ${FFLAGS} -o heat_transfer_phdf5 $^ ${PHDF5_FLIB} 

adios: heat_vars.o io_adios.o heat_transfer.o
	${FC} ${FFLAGS} -o heat_transfer_adios $^ ${ADIOS_FLIB} 


clean:
	rm -f *.o *.mod *.fh core.*
	rm -f heat_transfer_fort heat_transfer_adios 
	rm -f heat_transfer_hdf5 heat_transfer_phdf5
	rm -rf *.h5

distclean: clean
	rm -f fort.* 
	rm -f *.png minmax 
	rm -rf *.bp *.bp.dir *.idx



