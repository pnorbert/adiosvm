#!/usr/bin/env python
from __future__ import absolute_import, division, print_function, unicode_literals

import adios2
import argparse
import numpy as np


def SetupArgs():
    parser = argparse.ArgumentParser()

    parser.add_argument("--infile", "-f", help="Name of the bp file", required=True)
#    parser.add_argument("--xmlfile", "-x", help="Name of the XML confgi file", required=True)
    parser.add_argument("--varname", "-v", help="Name of variable read", default="T")

    parser.add_argument("--nx", '-nx', help="Number of reading process in X dimension", type=int, default=1)
    parser.add_argument("--ny", '-ny', help="Number of reading process in Y dimension", type=int, default=1)

    parser.add_argument("--nompi", "-nompi", help="ADIOS was installed without MPI", action="store_true")

    args = parser.parse_args()
    return args


class MPISetup(object):

    size = 1
    rank = {'world': 0,
            'x': 0,
            'y': 0}

    def __init__(self, args):

        if not args.nompi:

            from mpi4py import MPI

            self.comm_world = MPI.COMM_WORLD
            self.size = self.comm_world.Get_size()
            self.rank['world'] = self.comm_world.Get_rank()
            if self.size != (args.nx * args.ny):
                raise ValueError("nx * ny != num processes")

            if (args.ny > 1) and (args.nx > 1):
                comm_x = self.comm_world.Split(self.rank['world'] % args.nx, self.rank['world'])
            else:
                comm_x = self.comm_world.Split(self.rank['world'] / args.nx, self.rank['world'])
            comm_y = self.comm_world.Split(self.rank['world']/args.ny, self.rank['world'])

            self.rank['x'] = comm_x.Get_rank()
            self.rank['y'] = comm_y.Get_rank()

        else:
            if args.nx != 1:
                raise ValueError("nx must = 1 without MPI")
            if args.ny != 1:
                raise ValueError("ny must = 1 without MPI")


def Locate(rank, nproc, datasize):
    extra = 0
    if (rank == nproc - 1):
        extra = datasize % nproc
    num = datasize // nproc
    start = num * rank
    size = num + extra
    return start, size


def SubDivide(fp, args, mpi):
    datashape = np.zeros(2, dtype=np.int64)
    start = np.zeros(2, dtype=np.int64)
    size = np.zeros(2, dtype=np.int64)

    var = fp.available_variables()
    dshape = var[args.varname]['Shape'].split(',')
    for i in range(len(dshape)):
        datashape[i] = int(dshape[i])

    start[0], size[0] = Locate(mpi.rank['y'], args.ny, datashape[0])
    start[1], size[1] = Locate(mpi.rank['x'], args.nx, datashape[1])

    return start, size, datashape


if __name__ == "__main__":

    # Parse command line arguments
    args = SetupArgs()


    # Equally partition the data if parallelization is requested
    mpi = MPISetup(args)


    # Read the data from this object
    if not args.nompi:
        fr = adios2.open(args.infile, "r", mpi.comm_world, "adios2.xml", "heat")
    else:
        fr = adios2.open(args.infile, "r", "adios2.xml", "heat")


    # Get the ADIOS selections
    start, size, fullshape = SubDivide(fr, args, mpi)


    # Read through the steps, one at a time
    step = 0
    while (not fr.eof()):
        data = fr.read(args.varname, start, size, endl=True)


        # Print a couple simple diagnostics
        avg = np.average(data)
        std = np.std(data)
        for i in range(mpi.size):
            mpi.comm_world.Barrier()
            if i == mpi.rank['world']:
                print("step:{0}, rank: {1}, start: {4}, dims: {5}, avg: {2:.3f}, std: {3:.3f}".format(step, mpi.rank['world'], avg, std, start, size))

        step += 1

    fr.close()

