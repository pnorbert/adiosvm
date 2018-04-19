include make.settings

## Set ADIOS_DIR here or before doing make
override ADIOS_INC=-I${ADIOS_DIR}/include
override ADIOS_LIB=`${ADIOS_DIR}/bin/adios2-config --libs`
#-L/opt/libfabric/1.6.0/lib -lfabric

default: help
all: heatSimulation heatAnalysis heatVisualization


INC=${ADIOS_INC}


help:
	@echo "Make targets: "
	@echo " all:         build the examples "
	@echo " clean-code:  delete files from the build process"
	@echo " clean-data:  delete files from running the examples"
	@echo " distclean:   clean-code and clean-data"


%.o : %.cpp
	${CXX} ${CXXFLAGS} -c ${INC} -o $@ $< 


heatSimulation: simulation/HeatTransfer.o simulation/IO_adios2.o simulation/Settings.o simulation/heatSimulation.o
	${CXX} ${CXXFLAGS} -o heatSimulation $^ ${ADIOS_LIB} 


heatAnalysis: analysis/heatAnalysis.o analysis/AnalysisSettings.o 
	${CXX} ${CXXFLAGS} -o heatAnalysis $^ ${ADIOS_LIB} 


USE_VTKM_FLAG := $(strip $(USE_VTKM))

ifeq ($(USE_VTKM_FLAG),ON)

    override CXXFLAGS += -DHAVE_VTKM
    override INC += ${VTKM_INC}

heatVisualization: visualization/heatVisualization.o visualization/VizSettings.o visualization/VizOutputVtkm.o
	${CXX} ${CXXFLAGS} -o heatVisualization $^ ${ADIOS_LIB} ${VTKM_LIB}

else

heatVisualization: visualization/heatVisualization.o visualization/VizSettings.o visualization/VizOutputPrint.o
	${CXX} ${CXXFLAGS} -o heatVisualization $^ ${ADIOS_LIB} 

endif


clean-code:
	rm -f simulation/*.o analysis/*.o visualization/*.o core.*
	rm -f heatSimulation heatAnalysis heatVisualization

clean-data:
	rm -f *.png *.pnm T.txt core core.*
	rm -rf *.bp *.bp.dir 
	rm -f *.h5
	rm -f *.sst *.insitumpi
	rm -f conf *.bpflx

clean: clean-code

distclean: clean-code clean-data


