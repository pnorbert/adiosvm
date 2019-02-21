include ../make.settings

override ADIOS2_FINC=-I${ADIOS2_DIR}/include/fortran
override ADIOS2_FINC=`${ADIOS2_DIR}/bin/adios2-config --fortran-flags`
override ADIOS2_FLIB=`${ADIOS2_DIR}/bin/adios2-config --fortran-libs`

default: 
	@echo "Make targets: fort  hdf5_a  hdf5_b  phdf5  adios2"
	@echo "  fort:         build example with text output(io_fort.F90)"
	@echo "  hdf5_a:       build example with HDF5, separate timesteps (io_hdf5_a.F90)"
	@echo "  hdf5_b:       build example with HDF5, combined timesteps (io_hdf5_b.F90)"
	@echo "  phdf5:        build example with Parallel HDF5  (io_phdf5.F90)"
	@echo "  adios2:       build example with ADIOS 2.x (io_adios2.F90)"

all: default
help: default


io_hdf5_a.o : io_hdf5_a.F90 
	${FC} ${FFLAGS} -c ${HDF5_FINC} $< 

io_hdf5_b.o : io_hdf5_b.F90 
	${FC} ${FFLAGS} -c ${HDF5_FINC} $< 

io_phdf5.o : io_phdf5.F90 
	${FC} ${FFLAGS} -c ${PHDF5_FINC} $< 

io_adios2.o : io_adios2.F90 
	${FC} ${FFLAGS} -c ${ADIOS2_FINC} $<  

heat_vars.o : heat_vars.F90 
	${FC} ${FFLAGS} -c $< 

fort: heat_vars.o io_fort.o heatSimulation.o
	${FC} ${FFLAGS} -o heatSimulation_fort $^ 

hdf5_a: heat_vars.o io_hdf5_a.o heatSimulation.F90
	libtool --mode=link --tag=FC ${FC} ${FFLAGS} -o heatSimulation_hdf5_a $^ ${HDF5_FLIB} 

hdf5_b: heat_vars.o io_hdf5_b.o heatSimulation.F90
	libtool --mode=link --tag=FC ${FC} ${FFLAGS} -o heatSimulation_hdf5_b $^ ${HDF5_FLIB} 

phdf5: heat_vars.o io_phdf5.o heatSimulation.F90
	libtool --mode=link --tag=FC ${FC} ${FFLAGS} -o heatSimulation_phdf5 $^ ${PHDF5_FLIB} 

adios2: heat_vars.o io_adios2.o heatSimulation.F90
	${FC} ${FFLAGS} -o heatSimulation_adios2 $^ ${ADIOS2_FLIB} 

clean-code:
	rm -f *.o *.mod *.fh core.*
	rm -f heatSimulation_fort 
	rm -f heatSimulation_adios2
	rm -f heatSimulation_hdf5_a heatSimulation_hdf5_b heatSimulation_phdf5
	rm -rf .libs

clean-data: 
	rm -f fort.* 
	rm -f *.png *.pnm minmax 
	rm -rf *.bp *.bp.dir *.idx
	rm -f *.h5
	rm -f conf

distclean: clean-code clean-data
clean: clean-code clean-data



