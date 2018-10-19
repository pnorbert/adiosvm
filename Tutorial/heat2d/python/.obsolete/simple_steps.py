#!/usr/bin/env python
from __future__ import absolute_import, division, print_function, unicode_literals

import adios2
import argparse
import numpy as np
from mpi4py import MPI

varname = 'T'
infile = 'heat.bp'
outfile = 'delta.bp'

# Open file for reading
fr = adios2.open(infile, "r", MPI.COMM_WORLD, "adios2.xml", "SimulationOutput")

# Get the list of variables
var = fr.available_variables()
print(var)

# Get the dimensions of T in string format
dshapestr = var['T']['Shape'].split(',')

# convert into int array
dims = np.zeros(2, dtype=np.int64)
for i in range(len(dshapestr)):
    dims[i] = int(dshapestr[i])


# Open file for writing
fw = adios2.open(outfile, "w", MPI.COMM_WORLD, "adios2.xml", "AnalysisOutput")

# Read through the steps, one at a time
step = 0
while (not fr.eof()):
    data = fr.read(varname, [0,0], dims, endl=True)

    # Print a couple simple diagnostics
    avg = np.average(data)
    std = np.std(data)
    print("step:{0}, start: {3}, dims: {4}, avg: {1:.3f}, std: {2:.3f}".format(step, avg, std, [0,0], dims))

    # Calculate difference
    if (step > 0):
        dt = data - olddata
        fw.write("d{0}".format(varname), dt, dims, [0,0], dims, endl=True)
    olddata = np.copy(data)

    step += 1

fr.close()
fw.close()
