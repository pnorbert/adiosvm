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
    parser.add_argument("--istart", "-istart", help="Integer representing starting plane index", default=1)
    parser.add_argument("--displaysec", "-dsec", help="Float representing gap between plot window refresh", default=0.1)
    parser.add_argument("--nx", "-nx", help="Integer representing process decomposition in the x direction",default=1)
    parser.add_argument("--ny", "-ny", help="Integer representing process decomposition in the y direction",default=1)
    parser.add_argument("--plane", "-plane", help="The 2D plane to be displayed/stored xy/yz/xz/all", default='all')
    args = parser.parse_args()

    args.istart = int(args.istart)
    args.displaysec = float(args.displaysec)
    args.nx = int(args.nx)
    args.ny = int(args.ny)

    if args.plane not in ('xz', 'yz', 'xy', 'all'):
        raise "Input argument --plane must be one of xz/yz/xy/all"

    return args


def Plot2D(plane_direction, data, args, fullshape, step, fontsize):
    # Plotting part
    displaysec = args.displaysec
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

    ax.set_title("{0} plane, Timestep {1}".format(plane_direction, step), fontsize=fontsize)
    ax.set_xlabel("x")
    ax.set_ylabel("y")
    plt.ion()
    print ("Step: {0}".format(step))
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
        imgfile = args.outfile+"{0:0>3}".format(step)+"_" + plane_direction + ".png"
        fig.savefig(imgfile)

    plt.clf()


def read_data(args, fr, start_coord, size_dims):
    var1 = args.varname
    var2 = args.varname2
    data1= fr.read(var1, start_coord, size_dims )
    data2= fr.read(var2, start_coord, size_dims)
    data = np.sqrt(data1*data1+data2*data2)
    data = np.squeeze(data)
    return data


if __name__ == "__main__":
    # fontsize on plot
    fontsize = 22

    args = SetupArgs()
    print(args)

    # Setup up 2D communicators if MPI is installed
    mpi = decomp.MPISetup(args)

    # Read the data from this object
    fr = adios2.open(args.instream, "r", MPI.COMM_WORLD,"adios2.xml", "VizInput")
    vars_info = fr.availablevariables()

    print("vars_info {0}".format(vars_info))

    shape3_str = vars_info[args.varname]["Shape"].split(',')
    shape3 = list(map(int,shape3_str))
 
    # Get the ADIOS selections -- equally partition the data if parallelization is requested
    start, size, fullshape = mpi.Partition(fr, args)

    # Read through the steps, one at a time
    for fr_step in fr:
        cur_step= fr_step.currentstep()

        if args.plane in ('xy', 'all'):
            data = read_data (args, fr_step, [0,0,args.istart], [shape3[0],shape3[1],1])
            Plot2D ('xy', data, args, fullshape, cur_step, fontsize)
        
        if args.plane in ('xz', 'all'):
            data = read_data (args, fr_step, [0,args.istart,0], [shape3[0],1,shape3[2]])
            Plot2D ('xz', data, args, fullshape, cur_step, fontsize)
        
        if args.plane in ('yz', 'all'):
            data = read_data (args, fr_step, [args.istart,0,0], [1,shape3[1],shape3[2]])
            Plot2D ('yz',  data, args, fullshape, cur_step, fontsize)

    fr.close()

