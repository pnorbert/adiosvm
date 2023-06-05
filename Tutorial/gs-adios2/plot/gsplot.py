#!/usr/bin/env python3

#
# gsplot with stream reading using a BeginStep/EndStep loop
# This script can process steps concurrently with the simulation
#

from __future__ import absolute_import, division, print_function, unicode_literals
import argparse
import numpy as np
from mpi4py import MPI
import adios2
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from os import fstat
import decomp
#import time
#import os


def SetupArgs():
    parser = argparse.ArgumentParser()
    parser.add_argument("--instream", "-i",
                        help="Name of the input stream", required=True)
    parser.add_argument("--outfile", "-o",
                        help="Name of the output file", default="screen")
    parser.add_argument("--varname", "-v",
                        help="Name of variable read", default="U")
    parser.add_argument("--displaysec", "-dsec",
                        help="Float representing gap between plot window refresh", default=0.1)
    parser.add_argument(
        "--nompi", "-nompi", help="ADIOS was installed without MPI", action="store_true")
    parser.add_argument(
        "--plane", "-plane", help="The 2D plane to be displayed/stored xy/yz/xz/all", default='yz')
    args = parser.parse_args()

    args.displaysec = float(args.displaysec)
    if args.plane not in ('xz', 'yz', 'xy', 'all'):
        raise "Input argument --plane must be one of xz/yz/xy/all"

    args.nx = 1
    args.ny = 1
    args.nz = 1

    return args


def Plot2D(plane_direction, data, args, fullshape, step, fontsize):
    # Plotting part
    displaysec = args.displaysec
    gs = gridspec.GridSpec(1, 1)
    fig = plt.figure(1, figsize=(8, 8))
    ax = fig.add_subplot(gs[0, 0])
    colorax = ax.imshow(data, origin='lower', interpolation='quadric', extent=[
                        0, fullshape[1], 0, fullshape[0]], cmap=plt.get_cmap('gist_ncar'))
    cbar = fig.colorbar(colorax, orientation='horizontal')
    cbar.ax.tick_params(labelsize=fontsize-4)
    ax.plot([0, fullshape[1]], [0, 0], color='black')
    ax.plot([0, 0], [0, fullshape[0]], color='black')
    ax.set_title("{0}, {1} plane, step {2}".format(
        args.varname, plane_direction, step), fontsize=fontsize)
    ax.set_xlabel(plane_direction[0], fontsize=fontsize)
    ax.set_ylabel(plane_direction[1], fontsize=fontsize)
    plt.tick_params(labelsize=fontsize-8)
    plt.ion()
    if (args.outfile == "screen"):
        plt.show()
        plt.pause(displaysec)
    elif (args.outfile == "debug"):
        print(plane_direction+":")
        print(data)
    elif args.outfile.endswith(".bp"):
        if step == 0:
            global adios
            global ioWriter
            global var
            global writer
            adios = adios2.ADIOS(mpi.comm_app)
            ioWriter = adios.DeclareIO("VizOutput")
            var = ioWriter.DefineVariable(args.varname, data.shape, [
                                          0, 0], data.shape, adios2.ConstantDims, data)
            writer = ioWriter.Open(args.outfile, adios2.Mode.Write)

        writer.BeginStep()
        writer.Put(var, data, adios2.Mode.Sync)
        writer.EndStep()
    else:
        imgfile = args.outfile + \
            "{0:0>5}".format(step)+"_" + plane_direction + ".png"
        fig.savefig(imgfile)

    plt.clf()


if __name__ == "__main__":
    # fontsize on plot
    fontsize = 24
    # header size in bytes in data file
    headersize = 24

    args = SetupArgs()
#    print(args)

    # Setup up 2D communicators if MPI is installed
    if args.nompi:
        adios = adios2.ADIOS("adios2.xml")
    else:
        mpi = decomp.MPISetup(args, 3)
        myrank = mpi.rank['app']
        if mpi.size > 1:
            if myrank == 0:
                print("ERROR: gsplot is meant to run on a single process. " +
                      "It uses MPI to be able to share communicator with gray-scott " +
                      "when using an MPI-based ADIOS staging engine")
            quit()
        adios = adios2.ADIOS("adios2.xml", mpi.comm_app)

    # Read the data from this object
    io = adios.DeclareIO("SimulationOutput")
    fr = io.Open(args.instream, adios2.Mode.Read)

    # Read through the steps, one at a time
    plot_step = 0
    while True:
        status = fr.BeginStep()
        if status == adios2.StepStatus.EndOfStream:
            print("-- no more steps found --")
            break
        elif status == adios2.StepStatus.NotReady:
            sleep(1)
            continue
        elif status == adios2.StepStatus.OtherError:
            print("-- error with stream --")

        cur_step = fr.CurrentStep()
        vars = io.AvailableVariables()
        step = int(vars["step"]["Min"])

        for name, info in vars.items():
            print("variable_name: " + name)
            for key, value in info.items():
                print("\t" + key + ": " + value)
            print("\n")

        print("GS Plot step {0} output step {1} simulation step {2}".format(
              plot_step, cur_step, step), flush=True)

        vu = io.InquireVariable(args.varname)
        shape3 = vu.Shape()

        if args.plane in ('xy', 'all'):
            data = np.empty([shape3[0], shape3[1]], dtype=np.float64)
            vu.SetSelection([[0, 0, int(shape3[2]/2)],
                            [shape3[0], shape3[1], 1]])
            fr.Get(vu, data, adios2.Mode.Sync)
            Plot2D('xy',  data, args, shape3, step, fontsize)

        if args.plane in ('xz', 'all'):
            data = np.empty([shape3[0], shape3[2]], dtype=np.float64)
            vu.SetSelection([[0, int(shape3[1]/2), 0],
                            [shape3[0], 1, shape3[2]]])
            fr.Get(vu, data, adios2.Mode.Sync)
            Plot2D('xz',  data, args, shape3, step, fontsize)

        if args.plane in ('yz', 'all'):
            data = np.empty([shape3[1], shape3[2]], dtype=np.float64)
            vu.SetSelection([[int(shape3[0]/2), 0, 0],
                            [1, shape3[1], shape3[2]]])
            fr.Get(vu, data, adios2.Mode.Sync)
            Plot2D('yz',  data, args, shape3, step, fontsize)

        fr.EndStep()
        plot_step = plot_step + 1

    fr.Close()
