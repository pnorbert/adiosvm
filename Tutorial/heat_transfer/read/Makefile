include ../make.settings

## Set ADIOS_DIR here or before doing make
override ADIOS_FINC=-I${ADIOS_DIR}/include
override ADIOS_FLIB=`${ADIOS_DIR}/bin/adios_config -l -f`

default: 
	@echo "Make targets: adios hdf5"
	@echo "  adios:  build example with ADIOS  (io_adios.F90)"
	@echo "  hdf5:   build example with HDF5   (io_hdf5.F90)"


all: default
help: default

heat_read_hdf5.o : heat_read_hdf5.F90
	${FC} ${FFLAGS} -c ${HDF5_FINC} $< 

%.o : %.F90 
	${FC} ${FFLAGS} -c ${ADIOS_FINC} $<

adios: print.o heat_read_adios.o
	${FC} ${FFLAGS} -o heat_read_adios $^ ${ADIOS_FLIB} 

hdf5: print.o heat_read_hdf5.o
	libtool --mode=link --tag=FC ${FC} ${FFLAGS} -o heat_read_hdf5 $^ ${HDF5_FLIB} 
#	${FC} ${FFLAGS} -o heat_read_hdf5 $^ ${HDF5_FLIB} 


clean:
	rm -f *.o *.mod *.fh core.* fort.*
	rm -f heat_read_adios heat_read_hdf5

distclean: clean
	rm -rf *.png *.bp *.bp.dir

