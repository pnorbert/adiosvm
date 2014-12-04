#!/usr/bin/env python
"""
Example:

$ python ./heat_transfer.py
"""

import adios as ad
import numpy as np

""" 
Read all
"""
T = ad.readvar("heat.bp", "T")
print ">>> shape:", T.shape
print T

""" 
Read step by step
"""
f = ad.file("heat.bp")
v = f.var['T']

for i in range(v.nsteps):
    temp = v.read(from_steps=i)
    print ">>> step:", i
    print ">>> shape:", temp.shape
    print temp

f.close()

