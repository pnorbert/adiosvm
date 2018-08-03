2DECOMP_DIR=$(CURDIR)

.PHONY: src clean 

all: src 

src:
	mkdir -p lib include
	cd src; $(MAKE)

clean:
	cd src; $(MAKE) $@
	rm -rf include/* lib/*

