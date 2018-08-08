
# coding: utf-8

# In[1]:


#!/usr/bin/env python
from __future__ import absolute_import, division, print_function, unicode_literals

"""
Example:

$ mpirun -n 1 python ./heat_transfer.py -f inputstream -o outputstream -v varname
"""

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
    #def __init__(args):
    #def __init__(self):
    #args.instream = "./analysis/norms.bp"
    #args.outfile = "screen"
    ##args.outfile = "./2d-images"

    ##if not os.path.exists(os.path.dirname(args.outfile)):
    # #   os.makedirs(os.path.dirname(args.outfile))
    #args.varname = "u_real"
    #args.varname2 = "u_imag"
    #args.istart = 1
    #args.isize = 32
    #args.nx = 1
    #args.ny = 1
    #args.nompi = True
    parser = argparse.ArgumentParser()
    parser.add_argument("--instream", "-i", help="Name of the input stream", required=True)
    parser.add_argument("--outfile", "-o", help="Name of the output file", default="screen")
    parser.add_argument("--varname", "-v", help="Name of variable read", default="u_real")
    parser.add_argument("--varname2", "-v2", help="Name of variable read", default="u_imag")
    parser.add_argument("--nompi", "-nompi", help="ADIOS was installed without MPI", action="store_true")
    parser.add_argument("--istart", "-istart", help="starting plane", default=1)
    parser.add_argument("--isize", "-isize", help="size of aplane", required=True)
    parser.add_argument("--nx", "-nx", help="",default=1)
    parser.add_argument("--ny", "-ny", help="",default=1)
    args = parser.parse_args()
    return args

def set_args(args):
    return args


def Plot2DZ(args, fr, data, fullshape, step, fontsize, displaysec):

    gs = gridspec.GridSpec(1, 1)
    fig = plt.figure(1, figsize=(8,10))
    ax = fig.add_subplot(gs[0, 0])
#ax.imshow(data, origin='lower', extent=[0, fullshape[1], 0, fullshape[0]], cmap=plt.get_cmap('inferno'), vmin=0, vmax=200)
#    colorax = ax.imshow(data, origin='lower', extent=[0, fullshape[1], 0, fullshape[0]], cmap=plt.get_cmap('seismic'),vmin=13.0,vmax=15.0)
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
    if (args.outfile == "screen"):
        plt.show()
        plt.pause(displaysec)
    else:
        imgfile = args.outfile+"{0:0>3}".format(step)+"_Z.png"
        fig.savefig(imgfile)

    plt.clf()

def Plot2DY(args, fr, data, fullshape, step, fontsize, displaysec):

    gs = gridspec.GridSpec(1, 1)
    fig = plt.figure(1, figsize=(8,10))
    ax = fig.add_subplot(gs[0, 0])
#ax.imshow(data, origin='lower', extent=[0, fullshape[1], 0, fullshape[0]], cmap=plt.get_cmap('inferno'), vmin=0, vmax=200)
#    colorax = ax.imshow(data, origin='lower', extent=[0, fullshape[1], 0, fullshape[0]], cmap=plt.get_cmap('seismic'),vmin=13.0,vmax=15.0)
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
    if (args.outfile == "screen"):
        plt.show()
        plt.pause(displaysec)
    else:
        imgfile = args.outfile+"{0:0>3}".format(step)+"_Y.png"
        fig.savefig(imgfile)

    plt.clf()

def Plot2DX(args, fr, data, fullshape, step, fontsize, displaysec):

    gs = gridspec.GridSpec(1, 1)
    fig = plt.figure(1, figsize=(8,10))
    ax = fig.add_subplot(gs[0, 0])
#ax.imshow(data, origin='lower', extent=[0, fullshape[1], 0, fullshape[0]], cmap=plt.get_cmap('inferno'), vmin=0, vmax=200)
#    colorax = ax.imshow(data, origin='lower', extent=[0, fullshape[1], 0, fullshape[0]], cmap=plt.get_cmap('seismic'),vmin=13.0,vmax=15.0)
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
    if (args.outfile == "screen"):
        plt.show()
        plt.pause(displaysec)
    else:
        imgfile = args.outfile+"{0:0>3}".format(step)+"_X.png"
        fig.savefig(imgfile)

    plt.clf()

    
    

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
#    for name, info in vars_info.items():
#        print("variable_name: " + name)
#        for key, value in info.items():
#            print("\t" + key + ": " + value)
#        print("\n")
    print(vars_info[args.varname]["Shape"])
 
    # Get the ADIOS selections -- equally partition the data if parallelization is requested
    start, size, fullshape = mpi.Partition(fr, args)

    # Read through the steps, one at a time
    step = 0
    while (not fr.eof()):
        inpstep = fr.currentstep()
        
#SLICE i DIRECTION
        #istar = int(args.istart)
        #isiz = int(args.isize)
        #start = [0,0,istar]
        #size = [isiz,isiz,1]
        #data1= fr.read(args.varname, start, size )
        #data2= fr.read(args.varname2, start, size)
        #data = np.sqrt(data1*data1-data2*data2)
        #data = np.squeeze(data)
        #
        #Plot2DZ(args, fr, data, fullshape, step, fontsize, displaysec)

        #istar = int(args.istart)
        #isiz = int(args.isize)
        #start = [0,istar,0]
        #size = [isiz,1,isiz]
        #data1= fr.read(args.varname, start, size )
        #data2= fr.read(args.varname2, start, size)
        #data = np.sqrt(data1*data1-data2*data2)
        #data = np.squeeze(data)
        #
        #Plot2DY(args, fr, data, fullshape, inpstep, fontsize, displaysec)
        
        
        istar = int(args.istart)
        isiz = int(args.isize)
        start = [istar,0,0]
        size = [1,isiz,isiz]
        data1= fr.read(args.varname, start, size )
        data2= fr.read(args.varname2, start, size, endl=True)
        data = np.sqrt(data1*data1-data2*data2)
        data = np.squeeze(data)
        
        Plot2DX(args, fr, data, fullshape, step, fontsize, displaysec)
        
        
        
        step += 1

    fr.close()



