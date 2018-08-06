#!/usr/bin/env python
from __future__ import absolute_import, division, print_function, unicode_literals

"""
Example:

$ mpirun -n 1 python ./heat_transfer.py -f inputstream -o outputstream -v varname
"""

import adios2
import argparse

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import decomp
import time


def SetupArgs():
    parser = argparse.ArgumentParser()

    parser.add_argument("--instream", "-i", help="Name of the input stream", required=True)
    parser.add_argument("--outfile", "-o", help="Name of the output file", default="screen")
    parser.add_argument("--varname", "-v", help="Name of variable read", default="u_real")
    parser.add_argument("--varname2", "-v2", help="Name of variable read", default="u_imag")
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
#    colorax = ax.imshow(data, origin='lower', extent=[0, fullshape[1], 0, fullshape[0]], cmap=plt.get_cmap('seismic'),vmin=13.0,vmax=15.0)
    colorax = ax.imshow(data, origin='lower', extent=[0, fullshape[1], 0, fullshape[0]], cmap=plt.get_cmap('tab20c'))
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
    fr = adios2.open(args.instream, "r", mpi.comm_world, "adios2_config.xml", "VizInput")
    #import pdb; pdb.set_trace()

    # Get the ADIOS selections -- equally partition the data if parallelization is requested
    start, size, fullshape = mpi.Partition(fr, args)

    # Read through the steps, one at a time
    step = 0
    while (not fr.eof()):
        inpstep = fr.currentstep()
        start = [64,0,0]
        size = [1,128,128]
        print ('start:', start)
        print ('size:', size)
        data1= fr.read(args.varname, start, size )
        avg = np.average(data1)
        std = np.std(data1)
        print("d1:step:{0}, rank: {1}, avg: {2:.3f}, std: {3:.3f}".format(inpstep, mpi.rank['world'], avg, std))
        data2= fr.read(args.varname2, start, size, endl=True)
        avg = np.average(data2)
        std = np.std(data2)
        print("d2:step:{0}, rank: {1}, avg: {2:.3f}, std: {3:.3f}".format(inpstep, mpi.rank['world'], avg, std))
#        data = data1*data1 - data2*data2
        data = np.sqrt(data1*data1-data2*data2)
        data = np.squeeze(data)
        #import pdb; pdb.set_trace()

        # Print a couple simple diagnostics
        avg = np.average(data)
        std = np.std(data)
        print("step:{0}, rank: {1}, avg: {2:.3f}, std: {3:.3f}".format(inpstep, mpi.rank['world'], avg, std))
        Plot2D(args, fr, data, fullshape, inpstep, fontsize, displaysec)

        step += 1

    fr.close()

