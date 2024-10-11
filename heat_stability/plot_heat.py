#!/usr/bin/env python3
from adios2 import Adios, Stream  # pylint: disable=import-error
import argparse
import numpy as np  # pylint: disable=import-error
import matplotlib.pyplot as plt  # pylint: disable=import-error
import matplotlib.gridspec as gridspec  # pylint: disable=import-error


def SetupArgs():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--instream", "-i", help="Name of the input stream", required=True
    )
    parser.add_argument(
        "--outfile", "-o", help="Name of the output file", default="screen"
    )
    parser.add_argument("--varname", "-v", help="Name of variable to read", default="T")
    parser.add_argument(
        "--displaysec",
        "-dsec",
        help="Float representing gap between plot window refresh",
        default=0.1,
    )
    args = parser.parse_args()
    args.displaysec = float(args.displaysec)
    return args


def Plot2D(data, args, fullshape, step, fontsize):
    # Plotting part
    displaysec = args.displaysec
    gs = gridspec.GridSpec(1, 1)
    fig = plt.figure(1, figsize=(8, 8))
    ax = fig.add_subplot(gs[0, 0])
    colorax = ax.imshow(
        data,
        origin="lower",
        interpolation="quadric",
        extent=[0, fullshape[1], 0, fullshape[0]],
        cmap=plt.get_cmap("gist_ncar"),
    )
    cbar = fig.colorbar(colorax, orientation="horizontal")
    cbar.ax.tick_params(labelsize=fontsize - 4)

    ax.set_title(f"{args.varname}, step {step}", fontsize=fontsize)
    ax.set_xlabel("y", fontsize=fontsize)
    ax.set_ylabel("x", fontsize=fontsize)
    plt.tick_params(labelsize=fontsize - 8)
    plt.ion()
    if args.outfile == "screen":
        plt.show()
        plt.pause(displaysec)
    elif args.outfile.endswith(".bp"):
        global writer
#        print("plot to file, step = ", step)
#        if step == 0:
#            writer = Stream(args.outfile, "w")
#
        writer.begin_step()
        writer.write(args.varname, data, data.shape, [0, 0], data.shape)
        writer.end_step()
    else:
        imgfile = args.outfile + "{0:0>5}".format(step) + ".png"
        fig.savefig(imgfile)

    plt.clf()


def read_data(args, fr, start_coord, size_dims):
    var1 = args.varname
    data = fr.read(var1, start_coord, size_dims)
    data = np.squeeze(data)
    return data


if __name__ == "__main__":
    # fontsize on plot
    fontsize = 24

    args = SetupArgs()
    #    print(args)

    # Read the data from this object
    adios = Adios()
    io = adios.declare_io("writer")
    fr = Stream(io, args.instream, "r")

    if args.outfile.endswith(".bp"):
        global writer
        writer = Stream(args.outfile, "w")

    # Get the ADIOS selections -- equally partition the data if parallelization is requested

    # Read through the steps, one at a time
    plot_step = 0
    for _ in fr.steps():
        # print(f"loop status = {fr_step.step_status()} "
        #       f"step = {fr.current_step()} counter={fr.loop_index()}")
        v = fr.inquire_variable(args.varname)
        fullshape = v.shape()
        start = [0, 0]
        count = [fullshape[0], fullshape[1]]

        cur_step = fr.current_step()
        sim_step = fr.read("iteration")

        print(f"Heat Plot step {plot_step:>4} processing simulation output step {cur_step:>4} "
              f"or iteration {sim_step:>4}")
        if plot_step == 0:
            print(f"{args.varname} shape = {fullshape}")

        v.set_selection([start, count])
        data = fr.read(v)
        Plot2D(data, args, fullshape, sim_step, fontsize)
        plot_step = plot_step + 1

    fr.close()
    if args.outfile.endswith(".bp"):
        writer.close()
