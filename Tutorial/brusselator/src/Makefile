include Makefile.inc

.PHONY: all simulation analysis clean cleanall

all : var_checks simulation analysis
	@echo -n "\n------ Simulation and analysis built in their respective directories ------\n"

simulation: var_checks
	cd simulation; ${MAKE}

analysis: var_checks
	@set -e; cd analysis; ${MAKE}

clean:
	cd simulation; ${MAKE} clean
	cd analysis; ${MAKE} clean

cleanall:
	cd simulation; ${MAKE} cleanall
	cd analysis; ${MAKE} cleanall

clean-data:
	rm -rf *.bp* *.h5 *.sst *.png

