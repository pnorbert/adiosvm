#!/usr/bin/env python3
from __future__ import absolute_import, division, print_function, unicode_literals
import argparse
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from os import fstat
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
        "--plane", "-plane", help="The 2D plane to be displayed/stored xy/yz/xz/all", default='yz')
    args = parser.parse_args()

    args.displaysec = float(args.displaysec)
    if args.plane not in ('xz', 'yz', 'xy', 'all'):
        raise "Input argument --plane must be one of xz/yz/xy/all"

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
    else:
        imgfile = args.outfile + \
            "{0:0>5}".format(step)+"_" + plane_direction + ".png"
        fig.savefig(imgfile)

    plt.clf()


def read_data(args, fr, step, start_coord, size_dims):

    var1 = args.varname
    data = fr.read(var1, start_coord, size_dims)
    data = np.squeeze(data)
    return data


if __name__ == "__main__":
    # fontsize on plot
    fontsize = 24
    # header size in bytes in data file
    headersize = 24

    args = SetupArgs()
#    print(args)

    # Read the data from this object
    print("open {0}...".format(args.instream))
    fr = open(args.instream, "rb")
    fileSize = fstat(fr.fileno()).st_size
    header = fr.read(headersize)
    shape3 = np.frombuffer(header, dtype=np.uint64, count=3, offset=0)
    print("size of U = {0}x{1}x{2}".format(shape3[0], shape3[1], shape3[2]))

    nelems = (int)(shape3[0]*shape3[1]*shape3[2])
    varsize = nelems*8
    nsteps_d = (fileSize-headersize)/varsize
    nsteps = (int)(nsteps_d)
    if ((np.float64)(nsteps) != (np.float64)(nsteps_d)):
        print("ERROR: file size {0} is unexpected".format(fileSize))
    print("found {0} steps".format(nsteps))

    # Read through the steps, one at a time
    for step in range(0, nsteps):
        print("GS Plot step {0}".format(step), flush=True)

        start_offset = headersize + step*varsize
        # print("read {0} elems ({1} bytes) from offset {2}".format(
        #     nelems, nelems*8, start_offset))
        u = np.fromfile(fr, dtype=np.float64,
                        count=nelems).reshape(
            shape3[0], shape3[1], shape3[2])

        if args.plane in ('xy', 'all'):
            data = u[:, :, int(shape3[2]/2)]
            Plot2D('xy', data, args, shape3, step, fontsize)

        if args.plane in ('xz', 'all'):
            data = u[:, int(shape3[1]/2), :]
            Plot2D('xz', data, args, shape3, step, fontsize)

        if args.plane in ('yz', 'all'):
            data = u[int(shape3[0]/2), :, :]
            Plot2D('yz',  data, args, shape3, step, fontsize)

    fr.close()
