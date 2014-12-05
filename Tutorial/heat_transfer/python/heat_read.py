#!/usr/bin/env python
"""
Example:

$ python ./heat_transfer.py bpfile varname [varname [...]]
"""

import adios as ad
import numpy as np
import sys

def usage():
    print "USAGE: %s bpfile varname" % sys.argv[0]

fname = ""

if len(sys.argv) < 3:
    usage()
    sys.exit(1)
else:
    fname = sys.argv[1]
    varnames = sys.argv[2:]

""" 
Read all
"""
print ">>> Read full data"
for vname in varnames:
    v = ad.readvar(fname, vname)
    print ">>> name:", vname
    print ">>> shape:", v.shape
    print ">>> values:"
    print v

""" 
Read step by step
"""
print ""
print ">>> Read step by step"

f = ad.file(fname)

for i in range(f.current_step, f.last_step):
    print ">>> step:", i
    for vname in varnames:
        v = f.var[vname]
        val = v.read(from_steps=i)
        print ">>> name:", vname
        print ">>> shape:", v.dims
        print ">>> values:"
        print val

f.close()

