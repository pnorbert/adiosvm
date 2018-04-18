
default: 
	@echo "Make targets at this level are for cleaning only:"
	@echo "  clean-code  :  recursively delete objects and binaries"
	@echo "  clean-data  :  recursively delete files created by the examples"
	@echo "  distclean   :  clean-code and clean-data"

all: default
help: default

subdirs = simulation analysis stage_write

clean-data:
	rm -f *.o *.mod *.fh core.*
	rm -f fort.* 
	rm -f *.png minmax 
	rm -rf *.bp *.bp.dir *.idx
	rm -f *.h5
	rm -f conf
	for dir in $(subdirs); do echo "Clean $${dir}"; (cd $${dir}; make clean-data); done

clean-code:
	rm -f *.o *.mod *.fh core.*
	rm -f heat_transfer_fort 
	rm -f heat_transfer_adios1 heat_transfer_adios1_gpp heat_transfer_adios1_noxml
	rm -f heat_transfer_adios2  heat_transfer_noxml
	rm -f heat_transfer_hdf5_a heat_transfer_hdf5_b heat_transfer_phdf5
	for dir in $(subdirs); do echo "Clean $${dir}"; (cd $${dir}; make clean-data); done

distclean: clean-code clean-data





