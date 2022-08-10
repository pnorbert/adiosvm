#!/usr/bin/env python3
from __future__ import absolute_import, division, print_function, unicode_literals
### import adios2
import argparse
from time import sleep
from mpi4py import MPI
import numpy as np

def SetupArgs():
    parser = argparse.ArgumentParser()
    parser.add_argument("--instream", "-i", help="Name of the input stream", required=True)
    parser.add_argument("--varname", "-v", help="Name of variable read", default="U")
    args = parser.parse_args()
    return args

def OpenStream(comm_app, streamname):
    fr = [0, 1]
    # ADIOS2 open stream
    ### fr = adios2.open(streamname, "r", comm_app, "adios2.xml", "SimulationOutput")
    return fr

def InquireStep(fr_step, varname, read_step):
    # Fake the read here but should
    # - inquire the variable args.varname
    # - get the shape of the variable
    fullshape = [64,64,64]
    cur_step = read_step 
    sim_step = read_step*10

    # ADIOS2 processing info
    ### cur_step = fr_step.current_step()
    ### vars_info = fr_step.available_variables()
#   ### print (vars_info)

    ### shape3_str = vars_info[args.varname]["Shape"].split(',')
    ### fullshape = list(map(int,shape3_str))
    ### sim_step = fr_step.read("step")
    return fullshape, cur_step, sim_step

def ReadData(fr_step, varname, rank, read_step):
    # Fake the data read here 
    data = np.zeros(shape=(count1,fullshape[1],fullshape[2]))
    data[0,0,0] = -rank-read_step-1.0
    data[count1-1,fullshape[1]-1,fullshape[2]-1] = rank+read_step+2.0

    # ADIOS2 read data 
    #### data = fr.read(args.varname, start, count)
    return data

def CloseStream():
    # ADIOS2 close stream
    ### fr.close()
    return


if __name__ == "__main__":
    args = SetupArgs()

    # Setup up communicators if MPI is installed
    comm_app = MPI.COMM_WORLD.Split(3, MPI.COMM_WORLD.Get_rank()) 
    comm_size = comm_app.Get_size()
    rank = comm_app.Get_rank()
    
    fr = OpenStream(comm_app, args.instream)

    # Read through the steps, one at a time
    read_step = 0
    for fr_step in fr:

        fullshape, cur_step, sim_step = InquireStep(fr_step, args.varname, read_step)

        # 1D decomposition of the 3D array
        count1 = int(fullshape[0]/comm_size)
        start1 = count1 * rank
        if (rank == comm_size - 1):
            # last process need to read all the rest of slices
            count1 = fullshape[0] - count1 * (comm_size - 1)
        start = [ start1, 0, 0]
        count = [ count1, fullshape[1], fullshape[2] ]

        if rank == 0:
            print("Read step {0} processing simulation output step {1} or computation step {2}".format(read_step,cur_step, sim_step), flush=True)
        sleep(0.1)
        comm_app.Barrier()

        data = ReadData(fr_step, args.varname, rank, read_step)
 
        print("step {0} rank {1} data min = {2} max = {3}".format(read_step, rank, data.min(), data.max()), flush=True)

        read_step = read_step + 1
        sleep(0.1)
        comm_app.Barrier()
        
    CloseStream()

