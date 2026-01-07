#!/usr/bin/env python3
import math
import sys

import numpy as np
from mpi4py import MPI
import adios2


def print_usage():
    print(
        "Usage: heatSimulation   output  N  M   nx  ny   steps iterations [engine]\n"
        "  output: name of output data file/stream\n"
        "  N:      number of processes in X dimension\n"
        "  M:      number of processes in Y dimension\n"
        "  nx:     local array size in X dimension per processor\n"
        "  ny:     local array size in Y dimension per processor\n"
        "  steps:  the total number of steps to output\n"
        "  iterations: one step consist of this many iterations\n"
        "  engine: optional adios2 engine, BP5 or HDF5\n"
    )


def convert_to_uint(var_name, arg):
    try:
        value = int(arg, 10)
    except ValueError as exc:
        raise ValueError(f"Invalid value given for {var_name}: {arg}") from exc
    if value < 0:
        raise ValueError(f"Negative value given for {var_name}: {arg}")
    return value


class Settings:
    def __init__(self, argv, rank, nproc):
        if len(argv) < 8:
            raise ValueError("Not enough arguments")

        self.configfile = "adios2.xml"
        self.outputfile = argv[1]
        self.npx = convert_to_uint("N", argv[2])
        self.npy = convert_to_uint("M", argv[3])
        self.ndx = convert_to_uint("nx", argv[4])
        self.ndy = convert_to_uint("ny", argv[5])
        self.steps = convert_to_uint("steps", argv[6])
        self.iterations = convert_to_uint("iterations", argv[7])
        if len(argv) == 9:
            self.engine = argv[8]
        else:
            self.engine = "BP5"

        self.rank = rank
        self.nproc = nproc

        if self.npx * self.npy != self.nproc:
            raise ValueError("N*M must equal the number of processes")

        self.gndx = self.npx * self.ndx
        self.gndy = self.npy * self.ndy
        self.posx = self.rank % self.npx
        self.posy = self.rank // self.npx
        self.offsx = self.posx * self.ndx
        self.offsy = self.posy * self.ndy

        if self.posx == 0:
            self.rank_up = -1
        else:
            self.rank_up = self.rank - 1

        if self.posx == self.npx - 1:
            self.rank_down = -1
        else:
            self.rank_down = self.rank + 1

        if self.posy == 0:
            self.rank_left = -1
        else:
            self.rank_left = self.rank - self.npx

        if self.posy == self.npy - 1:
            self.rank_right = -1
        else:
            self.rank_right = self.rank + self.npx


class HeatTransfer:
    def __init__(self, settings):
        self.edgetemp = 100.0
        self.omega = 0.8
        self.m_s = settings

        shape = (self.m_s.ndx + 2, self.m_s.ndy + 2)
        self.m_T1 = np.empty(shape, dtype=np.float64)
        self.m_T2 = np.empty(shape, dtype=np.float64)
        self.m_TCurrent = self.m_T1
        self.m_TNext = self.m_T2

    def init(self, init_with_rank, comm):
        if init_with_rank:
            self.m_T1.fill(float(self.m_s.rank))
        else:
            pi = 4.0 * math.atan(1.0)
            hx = 2.0 * pi / self.m_s.gndx
            hy = 2.0 * pi / self.m_s.gndy
            minv = 1.0e30
            maxv = -1.0e30
            for i in range(self.m_s.ndx + 2):
                x = hx * (i - 1 + self.m_s.posx * self.m_s.ndx)
                for j in range(self.m_s.ndy + 2):
                    y = hy * (j - 1 + self.m_s.posy * self.m_s.ndy)
                    v = (
                        math.cos(8 * x)
                        + math.cos(6 * x)
                        - math.cos(4 * x)
                        + math.cos(2 * x)
                        - math.cos(x)
                        + math.sin(8 * y)
                        - math.sin(6 * y)
                        + math.sin(4 * y)
                        - math.sin(2 * y)
                        + math.sin(y)
                    )
                    if v < minv:
                        minv = v
                    if v > maxv:
                        maxv = v
                    self.m_T1[i, j] = v

            mingv = comm.allreduce(minv, op=MPI.MIN)
            maxgv = comm.allreduce(maxv, op=MPI.MAX)

            skew = 0.0 - mingv
            ratio = 2 * self.edgetemp / (maxgv - mingv)
            self.m_T1 += skew
            self.m_T1 *= ratio

        self.m_TCurrent = self.m_T1
        self.m_TNext = self.m_T2

    def switchCurrentNext(self):
        tmp = self.m_TCurrent
        self.m_TCurrent = self.m_TNext
        self.m_TNext = tmp

    def iterate(self):
        for i in range(1, self.m_s.ndx + 1):
            for j in range(1, self.m_s.ndy + 1):
                self.m_TNext[i, j] = (
                    self.omega
                    / 4
                    * (
                        self.m_TCurrent[i - 1, j]
                        + self.m_TCurrent[i + 1, j]
                        + self.m_TCurrent[i, j - 1]
                        + self.m_TCurrent[i, j + 1]
                    )
                    + (1.0 - self.omega) * self.m_TCurrent[i, j]
                )
        self.switchCurrentNext()

    def heatEdges(self):
        if self.m_s.posx == 0:
            self.m_TCurrent[0, :] = self.edgetemp

        if self.m_s.posx == self.m_s.npx - 1:
            self.m_TCurrent[self.m_s.ndx + 1, :] = self.edgetemp

        if self.m_s.posy == 0:
            self.m_TCurrent[:, 0] = self.edgetemp

        if self.m_s.posy == self.m_s.npy - 1:
            self.m_TCurrent[:, self.m_s.ndy + 1] = self.edgetemp

    def exchange(self, comm):
        send_x = np.empty(self.m_s.ndx + 2, dtype=np.float64)
        recv_x = np.empty(self.m_s.ndx + 2, dtype=np.float64)

        tag = 1
        if self.m_s.rank_left >= 0:
            send_x[:] = self.m_TCurrent[:, 1]
            comm.Send(send_x, dest=self.m_s.rank_left, tag=tag)
        if self.m_s.rank_right >= 0:
            comm.Recv(recv_x, source=self.m_s.rank_right, tag=tag)
            self.m_TCurrent[:, self.m_s.ndy + 1] = recv_x

        tag = 2
        if self.m_s.rank_right >= 0:
            send_x[:] = self.m_TCurrent[:, self.m_s.ndy]
            comm.Send(send_x, dest=self.m_s.rank_right, tag=tag)
        if self.m_s.rank_left >= 0:
            comm.Recv(recv_x, source=self.m_s.rank_left, tag=tag)
            self.m_TCurrent[:, 0] = recv_x

        tag = 3
        if self.m_s.rank_down >= 0:
            comm.Send(self.m_TCurrent[self.m_s.ndx, :], dest=self.m_s.rank_down, tag=tag)
        if self.m_s.rank_up >= 0:
            comm.Recv(self.m_TCurrent[0, :], source=self.m_s.rank_up, tag=tag)

        tag = 4
        if self.m_s.rank_up >= 0:
            comm.Send(self.m_TCurrent[1, :], dest=self.m_s.rank_up, tag=tag)
        if self.m_s.rank_down >= 0:
            comm.Recv(
                self.m_TCurrent[self.m_s.ndx + 1, :],
                source=self.m_s.rank_down,
                tag=tag,
            )

    def data_noghost(self):
        return self.m_TCurrent[1 : self.m_s.ndx + 1, 1 : self.m_s.ndy + 1].copy()


class IO:
    def __init__(self, settings, comm):
        self._adios = adios2.Adios(comm)
        self._io = self._adios.declare_io("SimulationOutput")
        self._io.set_engine(settings.engine)

        self._var_t = self._io.define_variable(
            "T",
            np.zeros((settings.ndx, settings.ndy), dtype=np.float64),
            [settings.gndx, settings.gndy],
            [settings.offsx, settings.offsy],
            [settings.ndx, settings.ndy],
            True,
        )

        itvar: int = 1
        self._var_it = self._io.define_variable("iteration", itvar)
        self._io.define_attribute("description", "Temperature from simulation", "T")
        self._io.define_attribute("unit", "C", "T")
        self._stream = adios2.Stream(self._io, settings.outputfile, "w", comm)
        self._stream.engine.lock_writer_definitions()

    def write(self, step, ht):
        self._stream.begin_step()
        data = ht.data_noghost()
        self._stream.write(self._var_t, data)
        self._stream.write(self._var_it, step)
        self._stream.end_step()

    def close(self):
        if self._stream is not None:
            self._stream.close()
            self._stream = None

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()


def main():
    if not MPI.Is_initialized():
        MPI.Init()

    comm_world = MPI.COMM_WORLD
    wrank = comm_world.Get_rank()
    wnproc = comm_world.Get_size()

    color = 1
    mpi_heat_transfer_comm = comm_world.Split(color, wrank)

    rank = mpi_heat_transfer_comm.Get_rank()
    nproc = mpi_heat_transfer_comm.Get_size()

    io = None
    try:
        time_start = MPI.Wtime()
        settings = Settings(sys.argv, rank, nproc)
        if not rank:
            print(f"Process decomposition  : {settings.npx} x {settings.npy}")
            print(f"Array size per process : {settings.ndx} x {settings.ndy}")
            print(f"Number of output steps : {settings.steps}")
            print(f"Iterations per step    : {settings.iterations}")
            print(f"Using engine           : {settings.engine}")

        ht = HeatTransfer(settings)
        io = IO(settings, mpi_heat_transfer_comm)

        if rank == 0:
            print("Simulation step 0: initialization")
        ht.init(False, mpi_heat_transfer_comm)
        ht.heatEdges()
        ht.exchange(mpi_heat_transfer_comm)

        io.write(0, ht)

        for step in range(1, settings.steps):
            if rank == 0:
                print(f"Simulation step {step}")
            for _ in range(1, settings.iterations + 1):
                ht.iterate()
                ht.exchange(mpi_heat_transfer_comm)
                ht.heatEdges()
            io.write(step, ht)

        mpi_heat_transfer_comm.Barrier()

        time_end = MPI.Wtime()
        if rank == 0:
            print(f"Total runtime = {time_end - time_start}s")
    except ValueError as exc:
        print(exc)
        print_usage()
    except OSError as exc:
        print("I/O base exception caught")
        print(exc)
    except Exception as exc:
        print("Exception caught")
        print(exc)
    finally:
        if io is not None:
            io.close()
        if not MPI.Is_finalized():
            MPI.Finalize()


if __name__ == "__main__":
    main()
