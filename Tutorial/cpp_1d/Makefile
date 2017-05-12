include make.settings

## Set ADIOS_DIR here or before doing make
override ADIOS_INC=-I${ADIOS_DIR}/include
override ADIOS_LIB=`${ADIOS_DIR}/bin/adios_config -l`

default: writer reader

all: default
help: default



%.o : %.cpp 
	${CXX} ${CXXFLAGS} ${ADIOS_INC} -c $< 

writer: writer.o
	${CXX} ${LDFLAGS} -o writer $^ ${ADIOS_LIB} 

reader: reader.o
	${CXX} ${LDFLAGS} -o reader $^ ${ADIOS_LIB} 

clean:
	rm -f *.o core.* writer reader

distclean: clean
	rm -f *[0-9].txt
	rm -f *.png minmax 
	rm -rf *.bp *.bp.dir *.idx
	rm -f *.h5
	rm -f conf



