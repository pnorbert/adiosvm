#!/usr/bin/env python

#!/usr/bin/env python
from __future__ import absolute_import, division, print_function, unicode_literals
import adios2
import argparse
from mpi4py import MPI
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
import decomp
import time
import os


def SetupArgs():
    parser = argparse.ArgumentParser()
    parser.add_argument("--instream", "-i", help="Name of the input stream", required=True)
    parser.add_argument("--outfile", "-o", help="Name of the output file", default="screen")
    parser.add_argument("--varname", "-v", help="Name of variable read", default="u_real")
    parser.add_argument("--varname2", "-v2", help="Name of variable read", default="u_imag")
    parser.add_argument("--nompi", "-nompi", help="ADIOS was installed without MPI", action="store_true")
    parser.add_argument("--istart", "-istart", help="starting plane index", default=1)
    parser.add_argument("--isize", "-isize", help="size of a plane", required=True)
    parser.add_argument("--nx", "-nx", help="process decomposition in the x direction",default=1)
    parser.add_argument("--ny", "-ny", help="process decomposition in the y direction",default=1)
    args = parser.parse_args()

    args.istart = int(args.istart)
    args.isize = int(args.isize)
    args.nx = int(args.nx)
    args.ny = int(args.ny)

    return args


def Plot2D(args, data, fullshape, step, fontsize, displaysec, slice_direction):
    gs = gridspec.GridSpec(1, 1)
    fig = plt.figure(1, figsize=(8,10))
    ax = fig.add_subplot(gs[0, 0])
    colorax = ax.imshow(data, origin='lower', extent=[0, fullshape[1], 0, fullshape[0]], cmap=plt.get_cmap('gist_ncar'))
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
    print (step)
    if (args.outfile == "screen"):
        plt.show()
        plt.pause(displaysec)
    elif args.outfile.endswith(".bp"):
        if step == 0:
            global adios
            global ioWriter
            global var
            global writer
            adios = adios2.ADIOS(mpi.comm_world)
            ioWriter = adios.DeclareIO("VizOutput")
            var = ioWriter.DefineVariable("norm", data.shape, [0,0], data.shape, adios2.ConstantDims, data)
            writer = ioWriter.Open(args.outfile, adios2.Mode.Write)

        writer.BeginStep()
        writer.Put(var, data, adios2.Mode.Sync)
        writer.EndStep()
    else:
        imgfile = args.outfile+"{0:0>3}".format(step)+"_" + slice_direction + ".png"
        fig.savefig(imgfile)

    plt.clf()


def plot_slice (slice_dir, start_coord, size_dims, fr, args, fullshape, step, fontsize, displaysec,endl=False):
    var1 = args.varname
    var2 = args.varname2
    data1= fr.read(var1, start_coord, size_dims )
    data2= fr.read(var2, start_coord, size_dims, endl=endl)
    data = np.sqrt(data1*data1-data2*data2)
    data = np.squeeze(data)
    Plot2D(args, data, fullshape, step, fontsize, displaysec, "XY")


if __name__ == "__main__":
    # fontsize on plot
    fontsize = 22
    displaysec = 0.01

    args = SetupArgs()
    print(args)

    # Setup up 2D communicators if MPI is installed
    mpi = decomp.MPISetup(args)

    # Read the data from this object
    fr = adios2.open(args.instream, "r", MPI.COMM_WORLD,"adios2_config.xml", "VizInput")
    vars_info = fr.available_variables()
    print(vars_info[args.varname]["Shape"])
 
    # Get the ADIOS selections -- equally partition the data if parallelization is requested
    start, size, fullshape = mpi.Partition(fr, args)

    print ("printing mpi start and size")
    print (start, size)

    # Read through the steps, one at a time
    step = 0
    while (not fr.eof()):
        inpstep = fr.currentstep()
        
        #plot_slice ('xy', [0,0,args.istart], [args.isize,args.isize,1], fr, args, fullshape, step, fontsize, displaysec)
        #plot_slice ('xz', [0,args.istart,0], [args.isize,1,args.isize], fr, args, fullshape, step, fontsize, displaysec)
        plot_slice ('yz', [args.istart,0,0], [1,args.isize,args.isize], fr, args, fullshape, step, fontsize, displaysec,endl=True)

        step += 1

    fr.close()

