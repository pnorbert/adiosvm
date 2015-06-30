include ../make.settings

## Set ADIOS_DIR here or before doing make
override ADIOS_FINC=-I${ADIOS_DIR}/include
override ADIOS_FLIB=`${ADIOS_DIR}/bin/adios_config -l -f`

default: 
	@echo "Make targets: adios hdf5 steps"
	@echo "  hdf5:   build example with HDF5   (heat_read_hdf5.F90)"
	@echo "  adios:  build example with ADIOS  (heat_read_adios.F90)"
	@echo "  steps:  build example with ADIOS step-by-step reading  (heat_read_steps.F90)"


all: default
help: default

heat_read_hdf5.o : heat_read_hdf5.F90
	${FC} ${FFLAGS} -c ${HDF5_FINC} $< 

%.o : %.F90 
	${FC} ${FFLAGS} -c ${ADIOS_FINC} $<

hdf5: print.o heat_read_hdf5.o
	libtool --mode=link --tag=FC ${FC} ${FFLAGS} -o heat_read_hdf5 $^ ${HDF5_FLIB} 
#	${FC} ${FFLAGS} -o heat_read_hdf5 $^ ${HDF5_FLIB} 

adios: print.o heat_read_adios.o
	${FC} ${FFLAGS} -o heat_read_adios $^ ${ADIOS_FLIB} 

steps: print.o heat_read_steps.o
	${FC} ${FFLAGS} -o heat_read_steps $^ ${ADIOS_FLIB} 


clean:
	rm -f *.o *.mod *.fh core.* fort.*
	rm -f heat_read_adios heat_read_hdf5 heat_read_steps

distclean: clean
	rm -rf *.png *.bp *.bp.dir
