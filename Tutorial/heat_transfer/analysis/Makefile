include ../make.settings

## Set ADIOS1_DIR here or before doing make
override ADIOS1_FINC=-I${ADIOS1_DIR}/include
override ADIOS1_FLIB=`${ADIOS1_DIR}/bin/adios_config -l -f`

override ADIOS2_FINC=-I${ADIOS2_DIR}/include/fortran
override ADIOS2_FLIB=`${ADIOS2_DIR}/bin/adios2-config --libs` -ladios2_f

default: 
	@echo "Make targets: adios2  hdf5  steps2  adios1  steps1"
	@echo "  hdf5:   build example with HDF5   (heat_read_hdf5.F90)"
	@echo "  adios2: build example with ADIOS 2.x (heat_read_adios2.F90)"
	@echo "  steps2: build example with ADIOS 2.x step-by-step reading  (heat_read_steps.F90)"
	@echo "  adios1: build example with ADIOS 1.x (heat_read_adios1.F90)"
	@echo "  steps1: build example with ADIOS 1.x step-by-step reading (heat_read_adios1.F90)"


all: default
help: default

heat_read_hdf5.o : heat_read_hdf5.F90
	${FC} ${FFLAGS} -c ${HDF5_FINC} $< 

print.o : print.F90
	${FC} ${FFLAGS} -c $< 

%2.o : %.F90 
	${FC} ${FFLAGS} -c ${ADIOS2_FINC} $<

%1.o : %.F90 
	${FC} ${FFLAGS} -c ${ADIOS1_FINC} $<

hdf5: print.o heat_read_hdf5.F90
	libtool --mode=link --tag=FC ${FC} ${FFLAGS} ${HDF5_FINC} -o heat_read_hdf5 $^ ${HDF5_FLIB} 
#	${FC} ${FFLAGS} -o heat_read_hdf5 $^ ${HDF5_FLIB} 

adios2: print.o heat_read_adios2.F90
	${FC} ${FFLAGS} -o heat_read_adios2 ${ADIOS2_FINC} $^ ${ADIOS2_FLIB} 

steps2: print.o heat_read_steps2.F90
	${FC} ${FFLAGS} -o heat_read_steps2 ${ADIOS2_FINC} $^ ${ADIOS2_FLIB} 


adios1: print.o heat_read_adios1.F90
	${FC} ${FFLAGS} -o heat_read_adios1 ${ADIOS1_FINC} $^ ${ADIOS1_FLIB} 

steps1: print.o heat_read_steps1.F90
	${FC} ${FFLAGS} -o heat_read_steps1 ${ADIOS1_FINC} $^ ${ADIOS1_FLIB} 


clean-code:
	rm -f *.o *.mod *.fh core.* fort.*
	rm -f heat_read_adios1 heat_read_adios2 heat_read_hdf5 heat_read_steps1 heat_read_steps2

clean-data: 
	rm -rf *.png *.bp *.bp.dir

distclean: clean-code clean-data
clean: clean-code clean-data

