#!/usr/bin/env python
from __future__ import absolute_import, division, print_function, unicode_literals

"""
Example:

$ mpirun -n 1 python ./heat_transfer.py -i inputstream -o outputstream -v varname

The plotting part is serial, so in practice use 1 process only. 
However the decomposition and read part works in parallel in this script.
"""

import adios2
import argparse

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import decomp


def SetupArgs():
    parser = argparse.ArgumentParser()

    parser.add_argument("--instream", "-i", help="Name of the input stream", required=True)
    parser.add_argument("--outfile", "-o", help="Name of the output file", default="screen")
    parser.add_argument("--varname", "-v", help="Name of variable read", default="T")
    parser.add_argument("--nompi", "-nompi", help="ADIOS was installed without MPI", action="store_true")

    args = parser.parse_args()
    args.nx = 1
    args.ny = 1
    return args



def Plot2D(args, fr, data, fullshape, step, fontsize, displaysec):
    gs = gridspec.GridSpec(1, 1)
    fig = plt.figure(1, figsize=(8,10))
    ax = fig.add_subplot(gs[0, 0])
#ax.imshow(data, origin='lower', extent=[0, fullshape[1], 0, fullshape[0]], cmap=plt.get_cmap('inferno'), vmin=0, vmax=200)
    colorax = ax.imshow(data, origin='lower', extent=[0, fullshape[1], 0, fullshape[0]], cmap=plt.get_cmap('rainbow'))
    fig.colorbar(colorax, orientation='horizontal')

    for i in range(args.ny):
        y = fullshape[0] / args.ny * i
        ax.plot([0, fullshape[1]], [y, y], color='black')

    for i in range(args.nx):
        x = fullshape[1] / args.nx * i
        ax.plot([x, x], [0, fullshape[0]], color='black')

    ax.set_title("Timestep = {0}".format(step), fontsize=fontsize)
    ax.set_xlabel("x")
    ax.set_ylabel("y")

    plt.ion()
    if (args.outfile == "screen"):
        plt.show()
        plt.pause(displaysec)
    else:
        imgfile = args.outfile+"{0:0>3}".format(step)+".png"
        fig.savefig(imgfile)

    plt.clf()


if __name__ == "__main__":

    # fontsize on plot
    fontsize = 22
    displaysec = 0.01

    # Parse command line arguments
    args = SetupArgs()

    # Setup up 2D communicators if MPI is installed
    mpi = decomp.MPISetup(args)

    # Read the data from this object
    with adios2.open(args.instream, "r", mpi.comm_world, "adios2.xml", "VizInput") as fr:

        # Read through the steps, one at a time
        for fr_step in fr:
            
            inpstep = fr_step.currentstep()
            
            if inpstep == 0:
            # Get the ADIOS selections -- equally partition the data if parallelization is requested
                start, size, fullshape = mpi.Partition(fr_step, args)

            data = fr_step.read(args.varname, start, size)

            # Print a couple simple diagnostics
            avg = np.average(data)
            std = np.std(data)
            print("step:{0}, rank: {1}, avg: {2:.3f}, std: {3:.3f}".format(inpstep, mpi.rank['world'], avg, std))
            Plot2D(args, fr_step, data, fullshape, inpstep, fontsize, displaysec)
