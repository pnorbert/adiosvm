.PHONY: all simulation analysis clean cleanall

all : simulation analysis
	@echo -n "\n------ Simulation and analysis built in their respective directories ------\n"

simulation:
	cd simulation; ${MAKE}

analysis:
	cd analysis; ${MAKE}

clean:
	cd simulation; ${MAKE} clean
	cd analysis; ${MAKE} clean

cleanall:
	cd simulation; ${MAKE} cleanall
	cd analysis; ${MAKE} cleanall

