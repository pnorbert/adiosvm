#!/usr/bin/env python3
from adios2 import Adios, Stream  # pylint: disable=import-error
import argparse
import numpy as np  # pylint: disable=import-error
import matplotlib.pyplot as plt  # pylint: disable=import-error
import matplotlib.gridspec as gridspec  # pylint: disable=import-error


def SetupArgs():
    parser = argparse.ArgumentParser()
    parser.add_argument("--instream", "-i", help="Heat data with transformation", required=True)
    parser.add_argument("--inorig", "-g", help="Original Heat data without transformation",
                        required=True)
    parser.add_argument("--outfile", "-o", help="Output image name prefix", default="screen")
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


def Plot2D(data, args, varname, outfilename, fullshape, step, fontsize):
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

    ax.set_title(f"{varname}, step {step}", fontsize=fontsize)
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
        writer.write(varname, data, data.shape, [0, 0], data.shape)
        writer.end_step()
    else:
        imgfile = outfilename + "{0:0>5}".format(step) + ".png"
        fig.savefig(imgfile)

    plt.clf()


if __name__ == "__main__":
    # fontsize on plot
    fontsize = 24

    args = SetupArgs()
    #    print(args)

    # Read the data from this object
    adios = Adios()
    io = adios.declare_io("writer")
    fr = Stream(io, args.instream, "r")
    forig = Stream(args.inorig, "r")

    if args.outfile.endswith(".bp"):
        global writer
        writer = Stream(args.outfile, "w")

    # Get the ADIOS selections -- equally partition the data if parallelization is requested

    # Read through the steps, one at a time
    plot_step = 0
    for _ in fr.steps():
        forig.begin_step()  # same progress rate as with other file
        # print(f"loop status = {fr_step.step_status()} "
        #       f"step = {fr.current_step()} counter={fr.loop_index()}")
        v = fr.inquire_variable(args.varname)
        fullshape = v.shape()
        start = [0, 0]
        count = [fullshape[0], fullshape[1]]

        cur_step = fr.current_step()
        sim_step = fr.read("iteration")
        orig_step = forig.read("iteration")

        if orig_step != sim_step:
            print(f"ERROR: two input files with different iterations encountered in {plot_step}."
                  f" Original file = {orig_step}, input file = {sim_step}"
                  )
            break

        print(f"Heat Plot step {plot_step:>4} processing simulation output step {cur_step:>4} "
              f"or iteration {sim_step:>4}")
        if plot_step == 0:
            print(f"{args.varname} shape = {fullshape}")

        v.set_selection([start, count])
        data = fr.read(v)
        Plot2D(data, args, args.varname, args.outfile, fullshape, sim_step, fontsize)

        print("Get original data var")
        vorig = forig.inquire_variable(args.varname)
        print(f"Set selection on orig var {vorig.name()}")
        vorig.set_selection([start, count])
        print(f"Read orig var")
        dorig = forig.read(vorig)
        print(f"Calculate error")
        derror = np.abs(data - dorig)

        print(f"Plot error")
        Plot2D(derror, args, "err_" + args.varname, "err_" + args.outfile, fullshape, sim_step, fontsize)
        plot_step = plot_step + 1
        forig.end_step()

    fr.close()
    forig.close()
    if args.outfile.endswith(".bp"):
        writer.close()
