
default: 
	@echo "Make targets  :"
	@echo "  adios2      :  build ADIOS examples"
	@echo "  hdf5        :  build HDF5 examples"
	@echo "  clean-code  :  recursively delete objects and binaries"
	@echo "  clean-data  :  recursively delete files created by the examples"
	@echo "  distclean   :  clean-code and clean-data"

all: default
help: default

adios2:
	cd simulation; make adios2
	cd analysis; make adios2_file adios2_stream

hdf5:
	cd simulation; make phdf5 hdf5_a hdf5_b
	cd analysis; make hdf5_file phdf5_file

subdirs = simulation analysis

clean-data:
	rm -f *.o *.mod *.fh core.*
	rm -f fort.* 
	rm -f *.png *.pnm minmax 
	rm -rf *.bp *.bp.dir *.idx
	rm -f *.h5
	rm -f conf *.sst *_insitumpi_*
	for dir in $(subdirs); do echo "Clean $${dir}"; (cd $${dir}; make clean-data); done

clean-code:
	rm -f *.o *.mod *.fh core.*
	for dir in $(subdirs); do echo "Clean $${dir}"; (cd $${dir}; make clean-code); done

distclean: clean-code clean-data





