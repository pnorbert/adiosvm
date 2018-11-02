#!/usr/bin/env python
"""
Example:

$ mpirun -n P python ./heat_transfer.py N M bpfile varname [varname [...]]
"""

from mpi4py import MPI
import adios_mpi as ad
import numpy as np
import sys
import os
from time import sleep

def usage():
    print "USAGE: mpirun -n P %s N M bpfile varname [varname [...]]" % sys.argv[0]
    print "P:       number of MPI processes (should be less than N*M)"
    print "N:       number of processes in X dimension"
    print "M:       number of processes in Y dimension"
    print "bpfile:  name of bp file"
    print "varname: name of variable name"

fname = ""

comm = MPI.COMM_WORLD
rank = comm.Get_rank()
size = comm.Get_size()

if len(sys.argv) < 5:
    if rank == 0: usage()
    sys.exit(1)
else:
    N = int(sys.argv[1])
    M = int(sys.argv[2])
    fname = sys.argv[3]
    varnames = sys.argv[4:]

assert (size <= N*M)

rank_x = rank % N
rank_y = rank / N

""" 
Read step by step
"""
if rank == 0:
    print ""
    print ">>> Read step by step"

f = ad.file(fname, comm=MPI.COMM_WORLD)

for i in range(f.current_step, f.last_step):
    if rank == 0: print ">>> step: %d" % (i)

    for vname in varnames:
        v = f.var[vname]
        if rank == 0: print ">>> name: %s,  global dims: %s" % (vname, v.dims)
        if len(v.dims) != 2:
            if rank == 0: print ">>> Not a 2D array"
            continue

        count = np.array(v.dims)/np.array((N, M))
        offset = count * np.array((rank_x, rank_y))
        if rank_x == N-1:
            count[0] = v.dims[0] - count[0]*(N-1)
        if rank_y == M-1:
            count[1] = v.dims[1] - count[1]*(M-1)

        val = v.read(tuple(offset), tuple(count), from_steps=i)

        #print ">>> (%d, %d): offset=%s, count=%s, sum=%f" % (i, rank, tuple(offset), tuple(count), val.sum())

        ## For ordered output
        if rank == 0:
            print ">>> block (rank=%d): offset=%s, count=%s, sum=%f" % (rank, tuple(offset), tuple(count), val.sum())
        
        for k in range(size)[1:]:
            if rank == 0:
                comm.Recv(offset, source=k, tag=1000*i+10*k+1)
                comm.Recv(count, source=k, tag=1000*i+10*k+2)
                tmp = np.zeros(count, dtype=val.dtype)
                comm.Recv(tmp, source=k, tag=1000*i+10*k+3)
                print ">>> block (rank=%d): offset=%s, count=%s, sum=%f" % (k, tuple(offset), tuple(count), tmp.sum())
            else:
                comm.Send(offset, dest=0, tag=1000*i+10*k+1)
                comm.Send(count, dest=0, tag=1000*i+10*k+2)
                comm.Send(val, dest=0, tag=1000*i+10*k+3)

f.close()

