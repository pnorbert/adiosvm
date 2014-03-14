
# To modify this Makefile, edit Makefile_default.tpl file in ~/.skel/templates/
# and run skel makefile  

include /opt/adios/1.6.0/bin/../etc/skel/compiler_fragment.mk

#Use adios attached to skel, rather than adios in $PATH
#ADIOS_DIR=`adios_config -d`
ADIOS_DIR=/opt/adios/1.6.0/bin/..

ADIOS_CONFIG=${ADIOS_DIR}/bin/adios_config

LDFLAGS += `${ADIOS_CONFIG} -l` -L${ADIOS_DIR}/lib/skel -lskel 
CFLAGS += `${ADIOS_CONFIG} -c`
FCFLAGS += `${ADIOS_CONFIG} -fc`          
FCLIBS += `${ADIOS_CONFIG} -fl` -L${ADIOS_DIR}/lib/skel -lskel
               
APP=writer
CTESTS=
FTESTS=writer_skel_writer_write 

DEST_DIR=~/skel-deploy-dir/$(APP)/128

all: $(FTESTS) $(CTESTS)


$(CTESTS): $(CTESTS:=.c)
	$(CC) $(CFLAGS) -o $@ ${@}.c $(LDFLAGS)

$(FTESTS): $(FTESTS:=.f90)
	$(FC) $(FCFLAGS) -o $@ ${@}.f90 $(FCLIBS)


deploy:
	#Make sure this exists
	mkdir -p $(DEST_DIR)

	rm -f $(DEST_DIR)/submit*
	cp $(APP)_skel.xml $(DEST_DIR)/$(APP)_skel.xml.in
	cp $(CTESTS) submit* $(DEST_DIR)
	cp $(FTESTS) submit* $(DEST_DIR)
	cp $(prefix)/bin/set_method.sh $(DEST_DIR)
	cp $(prefix)/bin/skel_cat.py $(DEST_DIR)

clean:
	rm -f *.c
	rm -f *.f90
	#rm -f submit*
	rm -f $(CTESTS) $(FTESTS)


