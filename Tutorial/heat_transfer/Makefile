include make.settings

## Set ADIOS_DIR here or before doing make
override ADIOS_FINC=-I${ADIOS_DIR}/include
override ADIOS_FLIB=`${ADIOS_DIR}/bin/adios_config -l -f`

override ADIOS2_FINC=-I${ADIOS2_DIR}/include/fortran
override ADIOS2_FLIB=`${ADIOS2_DIR}/bin/adios2-config --libs` -ladios2_f

default: 
	@echo "Make targets: fort hdf5 phdf5 adios1 adios2 noxml"
	@echo "  fort:     build example with text output(io_fort.F90)"
	@echo "  hdf5_a:   build example with HDF5, separate timesteps (io_hdf5_a.F90)"
	@echo "  hdf5_b:   build example with HDF5, combined timesteps (io_hdf5_b.F90)"
	@echo "  phdf5:    build example with Parallel HDF5  (io_phdf5.F90)"
	@echo "  adios1:   build example with ADIOS  (io_adios_gpp.F90)"
	@echo "  adios2:   build example with ADIOS2  (io_adios2.F90)"
	@echo "  noxml:    build example with ADIOS  (io_adios_noxml.F90)"

all: default
help: default


io_hdf5_a.o : io_hdf5_a.F90 
	${FC} ${FFLAGS} -c ${HDF5_FINC} $< 

io_hdf5_b.o : io_hdf5_b.F90 
	${FC} ${FFLAGS} -c ${HDF5_FINC} $< 

io_phdf5.o : io_phdf5.F90 
	${FC} ${FFLAGS} -c ${PHDF5_FINC} $< 

gwrite_heat.fh: heat_transfer.xml
	${ADIOS_DIR}/bin/gpp.py heat_transfer.xml
	rm -f gread_heat.fh

io_adios_gpp.o : gwrite_heat.fh io_adios_gpp.F90 
	${FC} ${FFLAGS} -c ${ADIOS_FINC} io_adios_gpp.F90 

io_adios.o : io_adios.F90 
	${FC} ${FFLAGS} -c ${ADIOS_FINC} $<
	
io_adios2.o : io_adios2.F90 
	${FC} ${FFLAGS} -c ${ADIOS2_FINC} $<  

io_adios_noxml.o : io_adios_noxml.F90 
	${FC} ${FFLAGS} -c ${ADIOS_FINC} $< 

%.o : %.F90 
	${FC} ${FFLAGS} -c $< 

fort: heat_vars.o io_fort.o heat_transfer.o
	${FC} ${FFLAGS} -o heat_transfer_fort $^ 

hdf5_a: heat_vars.o io_hdf5_a.o heat_transfer.o
	libtool --mode=link --tag=FC ${FC} ${FFLAGS} -o heat_transfer_hdf5_a $^ ${HDF5_FLIB} 

hdf5_b: heat_vars.o io_hdf5_b.o heat_transfer.o
	libtool --mode=link --tag=FC ${FC} ${FFLAGS} -o heat_transfer_hdf5_b $^ ${HDF5_FLIB} 

phdf5: heat_vars.o io_phdf5.o heat_transfer.o
	libtool --mode=link --tag=FC ${FC} ${FFLAGS} -o heat_transfer_phdf5 $^ ${PHDF5_FLIB} 

adios1: heat_vars.o io_adios_gpp.o heat_transfer.o
	${FC} ${FFLAGS} -o heat_transfer_adios1 $^ ${ADIOS_FLIB} 

adios2: heat_vars.o io_adios2.o heat_transfer.o
	${FC} ${FFLAGS} -o heat_transfer_adios2 $^ ${ADIOS2_FLIB} 

noxml: heat_vars.o io_adios_noxml.o heat_transfer.o
	${FC} ${FFLAGS} -o heat_transfer_noxml $^ ${ADIOS_FLIB} 

clean:
	rm -f *.o *.mod *.fh core.*
	rm -f heat_transfer_fort 
	rm -f heat_transfer_adios1 heat_transfer_adios2  heat_transfer_noxml
	rm -f heat_transfer_hdf5_a heat_transfer_hdf5_b heat_transfer_phdf5

distclean: clean
	rm -f fort.* 
	rm -f *.png minmax 
	rm -rf *.bp *.bp.dir *.idx
	rm -f *.h5
	rm -f conf



