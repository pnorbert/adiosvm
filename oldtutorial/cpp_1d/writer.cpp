/*
 * Distributed under the OSI-approved Apache License, Version 2.0.  See
 * accompanying file Copyright.txt for details.
 *
 *
 *  Created on: May 12, 2017
 *      Author: pnorbert
 */

#include <iostream>
#include <vector>
#include <mpi.h>
#include <adios.h>

int main(int argc, char *argv[])
{
    int rank = 0, nproc = 1;
    MPI_Init(&argc, &argv);
    MPI_Comm comm = MPI_COMM_WORLD;
    MPI_Comm_rank(comm, &rank);
    MPI_Comm_size(comm, &nproc);

    if (argc < 2)
    {
        std::cout << "Not enough arguments: need an input file\n";
        return 1;
    }
    const char *outputfile = argv[1];

    const int NSTEPS = 5;
    const unsigned int NX = 10;
    const unsigned int gnx = 10*nproc;
    const unsigned int offs = rank*NX;

    adios_init("writer.xml", comm);

    std::vector<int> x(NX);
    std::string mode = "w";

    for (int step = 0; step < NSTEPS; step++)
    {
        for (int i = 0; i < NX; i++)
        {
            x[i] = step * NX * nproc * 1.0 + rank * NX * 1.0 + i;
        }

        int64_t f;
        adios_open(&f, "writer", outputfile, mode.c_str(), comm);
        adios_write(f, "gnx", &gnx);
        adios_write(f, "nx", &NX);
        adios_write(f, "offs", &offs);
        adios_write(f, "x", x.data());
        adios_close(f);

        mode = "a";
    }

    MPI_Barrier(comm);
    adios_finalize(rank);
    MPI_Finalize();
    return 0;
}
