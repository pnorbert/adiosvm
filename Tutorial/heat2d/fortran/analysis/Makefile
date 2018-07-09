include ../make.settings

## Set ADIOS1_DIR here or before doing make
override ADIOS1_FINC=-I${ADIOS1_DIR}/include
override ADIOS1_FLIB=`${ADIOS1_DIR}/bin/adios_config -l -f`

override ADIOS2_FINC=-I${ADIOS2_DIR}/include/fortran
override ADIOS2_FLIB=`${ADIOS2_DIR}/bin/adios2-config --libs` -ladios2_f

default: 
	@echo "Make targets: adios2_stream  hdf5  adios2_file  adios1_stream  adios1_file"
	@echo "  adios2_stream: build example with ADIOS 2.x step-by-step reading  (heatAnalysis_adios2_stream.F90)"
	@echo "  adios2_file:   build example with ADIOS 2.x for file-only read (heatAnalysis_adios2_file.F90)"
	@echo "  hdf5_file:     build example with HDF5 for file-only read  (heatAnalysis_hdf5_file.F90)"
	@echo "  adios1_stream: build example with ADIOS 1.x step-by-step reading  (heatAnalysis_adios1_stream.F90)"
	@echo "  adios1_file:   build example with ADIOS 1.x for file-only read (heatAnalysis_adios1_file.F90)"


all: default
help: default

heatAnalysis_hdf5_file.o : heatAnalysis_hdf5_file.F90
	${FC} ${FFLAGS} -c ${HDF5_FINC} $< 

print.o : print.F90
	${FC} ${FFLAGS} -c $< 

%2.o : %.F90 
	${FC} ${FFLAGS} -c ${ADIOS2_FINC} $<

%1.o : %.F90 
	${FC} ${FFLAGS} -c ${ADIOS1_FINC} $<

hdf5_file: print.o heatAnalysis_hdf5_file.F90
	libtool --mode=link --tag=FC ${FC} ${FFLAGS} ${HDF5_FINC} -o heatAnalysis_hdf5_file $^ ${HDF5_FLIB} 
#	${FC} ${FFLAGS} -o heatAnalysis_hdf5_file $^ ${HDF5_FLIB} 

adios2_file: print.o heatAnalysis_adios2_file.F90
	${FC} ${FFLAGS} -o heatAnalysis_adios2_file ${ADIOS2_FINC} $^ ${ADIOS2_FLIB} 

adios2_stream: print.o heatAnalysis_adios2_stream.F90
	${FC} ${FFLAGS} -o heatAnalysis_adios2_stream ${ADIOS2_FINC} $^ ${ADIOS2_FLIB} 


adios1_file: print.o heatAnalysis_adios1_file.F90
	${FC} ${FFLAGS} -o heatAnalysis_adios1_file ${ADIOS1_FINC} $^ ${ADIOS1_FLIB} 

adios1_stream: print.o heatAnalysis_adios1_stream.F90
	${FC} ${FFLAGS} -o heatAnalysis_adios1_stream ${ADIOS1_FINC} $^ ${ADIOS1_FLIB} 



clean-code:
	rm -f *.o *.mod *.fh core.* fort.* 
	rm -f heatAnalysis_adios2_file heatAnalysis_adios2_stream
	rm -f heatAnalysis_adios1_file heatAnalysis_adios1_stream heatAnalysis_hdf5_file
	rm -rf .libs

clean-data: 
	rm -rf *.png *.pnm *.bp *.bp.dir

distclean: clean-code clean-data
clean: clean-code clean-data

