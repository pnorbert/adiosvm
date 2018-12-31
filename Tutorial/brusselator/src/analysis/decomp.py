import numpy as np


def Locate(rank, nproc, datasize):
    extra = 0
    if (rank == nproc - 1):
        extra = datasize % nproc
    num = datasize // nproc
    start = num * rank
    size = num + extra
    return start, size


class MPISetup(object):

    readargs = []
    size = 1
    rank = {'world': 0,
            'x': 0,
            'y': 0}


    def __init__(self, args):

        self.nx = args.nx
        self.ny = args.ny

        if not args.nompi:

            from mpi4py import MPI

            color = 3
            self.comm_world = MPI.COMM_WORLD.Split(color, MPI.COMM_WORLD.Get_rank()) 
            self.size = self.comm_world.Get_size()
            self.rank['world'] = self.comm_world.Get_rank()
            if self.size != (self.nx * self.ny):
                raise ValueError("nx * ny != num processes")

            if (self.ny > 1) and (self.nx > 1):
                comm_x = self.comm_world.Split(self.rank['world'] % self.nx, self.rank['world'])
            else:
                comm_x = self.comm_world.Split(self.rank['world'] / self.nx, self.rank['world'])
            comm_y = self.comm_world.Split(self.rank['world']/self.ny, self.rank['world'])

            self.rank['x'] = comm_x.Get_rank()
            self.rank['y'] = comm_y.Get_rank()

            self.readargs.append(self.comm_world)

        else:
            if self.nx != 1:
                raise ValueError("nx must = 1 without MPI")
            if self.ny != 1:
                raise ValueError("ny must = 1 without MPI")

#            self.readargs.extend([args.xmlfile, "heat"])


    def Partition(self, fp, args):
        datashape = np.zeros(3, dtype=np.int64)
        start = np.zeros(3, dtype=np.int64)
        size = np.zeros(3, dtype=np.int64)

#print("dir fp {0}".format(dir(fp)))
        var = fp.availablevariables()
#        print("var {0}".format(var))
#        print('key')
#        print('type {0}'.format(type(var)))
#print("args varname {0}".format(args.varname))
#print('var keys')
#        print(var.keys())
        data = var[str(args.varname)]
        dshape = var[str(args.varname)]['Shape'].split(',')
        for i in range(len(dshape)):
            datashape[i] = int(dshape[i])

        start[0], size[0] = Locate(self.rank['y'], self.ny, datashape[0])
        start[1], size[1] = Locate(self.rank['x'], self.nx, datashape[1])

        return start, size, datashape
