#!/usr/bin/env python3
import math
import sys
import time

import numpy as np
import adios2


def print_usage():
    print(
        "Usage: heatSimulation   output  nx  ny  steps  iterations  [engine]\n"
        "  output: name of output data file/stream\n"
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
    def __init__(self, argv):
        if len(argv) < 6:
            raise ValueError("Not enough arguments")

        self.configfile = "adios2.xml"
        self.outputfile = argv[1]
        self.ndx = convert_to_uint("nx", argv[2])
        self.ndy = convert_to_uint("ny", argv[3])
        self.steps = convert_to_uint("steps", argv[4])
        self.iterations = convert_to_uint("iterations", argv[5])
        if (len(argv) == 7):
            self.engine = argv[6]
        else:
            self.engine = "BP5"


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

    def init(self):
        pi = 4.0 * math.atan(1.0)
        hx = 2.0 * pi / self.m_s.ndx
        hy = 2.0 * pi / self.m_s.ndy
        minv = 1.0e30
        maxv = -1.0e30
        for i in range(self.m_s.ndx + 2):
            x = hx * (i - 1)
            for j in range(self.m_s.ndy + 2):
                y = hy * (j - 1)
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

        skew = 0.0 - minv
        ratio = 2 * self.edgetemp / (maxv - minv)
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
        self.m_TCurrent[0, :] = self.edgetemp
        self.m_TCurrent[self.m_s.ndx + 1, :] = self.edgetemp
        self.m_TCurrent[:, 0] = self.edgetemp
        self.m_TCurrent[:, self.m_s.ndy + 1] = self.edgetemp

    def data_noghost(self):
        return self.m_TCurrent[1 : self.m_s.ndx + 1, 1 : self.m_s.ndy + 1].copy()


class IO:
    def __init__(self, settings):
        self._adios = adios2.Adios()
        self._io = self._adios.declare_io("SimulationOutput")
        self._io.set_engine(settings.engine)

        self._var_t = self._io.define_variable(
            "T",
            np.zeros((settings.ndx, settings.ndy), dtype=np.float64),
            [settings.ndx, settings.ndy],
            [0, 0],
            [settings.ndx, settings.ndy],
            True,
        )

        itvar: int = 1
        self._var_it = self._io.define_variable("iteration", itvar)
        self._io.define_attribute("description", "Temperature from simulation", "T")
        self._io.define_attribute("unit", "C", "T")
        self._stream = adios2.Stream(self._io, settings.outputfile, "w")
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
    io = None
    try:
        time_start = time.perf_counter()
        settings = Settings(sys.argv)
        print(f"Array size             : {settings.ndx} x {settings.ndy}")
        print(f"Number of output steps : {settings.steps}")
        print(f"Iterations per step    : {settings.iterations}")
        print(f"Using engine           : {settings.engine}")

        ht = HeatTransfer(settings)
        io = IO(settings)

        print("Simulation step 0: initialization")
        ht.init()
        ht.heatEdges()

        io.write(0, ht)

        for step in range(1, settings.steps):
            print(f"Simulation step {step}")
            for _ in range(1, settings.iterations + 1):
                ht.iterate()
                ht.heatEdges()
            io.write(step, ht)
        time_end = time.perf_counter()
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


if __name__ == "__main__":
    main()
