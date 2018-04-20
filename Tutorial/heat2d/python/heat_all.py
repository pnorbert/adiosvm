#!/usr/bin/env python
from __future__ import absolute_import, division, print_function, unicode_literals

"""
Example:

$ mpirun -n P python ./heat_transfer.py N M bpfile varname [varname [...]]
"""

import adios2
import argparse

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import decomp


def SetupArgs():
    parser = argparse.ArgumentParser()

    parser.add_argument("--infile", "-f", help="Name of the bp file", required=True)
    parser.add_argument("--outfile", "-o", help="Name of the output bp file", required=True)
#    parser.add_argument("--xmlfile", "-x", help="Name of the XML confgi file", required=True)

    parser.add_argument("--varname", "-v", help="Name of variable read", default="T")

    parser.add_argument("--nx", '-nx', help="Number of reading process in X dimension", type=int, default=1)
    parser.add_argument("--ny", '-ny', help="Number of reading process in Y dimension", type=int, default=1)

    parser.add_argument("--nompi", "-nompi", help="ADIOS was installed without MPI", action="store_true")
    parser.add_argument("--plot", "-p", help="Make a plot of the input data", action="store_true")

    args = parser.parse_args()
    return args



def Plot2D(args, fullshape, step, fontsize, displaysec):
    data = fr.read(args.varname, [0, 0], fullshape, step, 1)
    gs = gridspec.GridSpec(1, 1)
    fig = plt.figure(1, figsize=(8,10))
    ax = fig.add_subplot(gs[0, 0])

    ax.imshow(data, origin='lower', extent=[0, fullshape[1], 0, fullshape[0]] )

    for i in range(args.ny):
        y = fullshape[0] / args.ny * i
        ax.plot([0, fullshape[1]], [y, y], color='black')

    for i in range(args.nx):
        x = fullshape[1] / args.nx * i
        ax.plot([x, x], [0, fullshape[0]], color='black')

    ax.set_title("Timestep = {0}".format(step), fontsize=fontsize)
    for i in range(mpi.size):
        ax.text(Start[i][1], Start[i][0], "rank: {0}".format(i), fontsize=fontsize)

    ax.set_xlabel("x")
    ax.set_ylabel("y")

    plt.ion()
    plt.show()
    plt.pause(displaysec)
    plt.clf()


if __name__ == "__main__":

    # fontsize on plot
    fontsize = 22
    displaysec = 3

    # Parse command line arguments
    args = SetupArgs()

    # Setup up 2D communicators if MPI is installed
    mpi = decomp.MPISetup(args)


    # Read the data from this object
    fr = adios2.open(args.infile, "r", *mpi.readargs)

    # Calculate difference between steps, and write to this object
    fw = adios2.open(args.outfile, "w", *mpi.readargs)


    # Get the ADIOS selections -- equally partition the data if parallelization is requested
    start, size, fullshape = mpi.Partition(fr, args)
    Start = mpi.comm_world.gather(start, root=0)


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
                print("step:{0}, rank: {1}, avg: {2:.3f}, std: {3:.3f}".format(step, mpi.rank['world'], avg, std))


        if (mpi.rank['world'] == 0) and (args.plot):
            Plot2D(args, fullshape, step, fontsize, displaysec)


        if (step > 0):
            dt = data - olddata
            fw.write("d{0}".format(args.varname), dt, fullshape, start, size, endl=True)
        olddata = np.copy(data)

        step += 1

    fr.close()
    fw.close()

