/*
 * Distributed under the OSI-approved Apache License, Version 2.0.  See
 * accompanying file Copyright.txt for details.
 *
 * main.cpp
 *
 * Recreates heat_transfer.f90 (Fortran) ADIOS tutorial example in C++
 *
 * Created on: Feb 2017
 *     Author: Norbert Podhorszki
 *
 */
#include <mpi.h>

#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>

#include "HeatTransfer.h"
#include "IO.h"
#include "Settings.h"

void printUsage()
{
    std::cout << "Usage: heatTransfer  config   output  N  M   nx  ny  iterations  write_freq  read_freq\n"
              << "  config: XML config file to use\n"
              << "  output: name of output data file/stream\n"
              << "  N:      number of processes in X dimension\n"
              << "  M:      number of processes in Y dimension\n"
              << "  nx:     local array size in X dimension per processor\n"
              << "  ny:     local array size in Y dimension per processor\n"
              << "  iterations: number of compute iterations to \n"
              << "  write_freq: frequency to output data \n"
              << "  read_freq: frequency to read back output data (overwrite) \n\n";
}

int main(int argc, char *argv[])
{
    int provided;

    std::string engineName = std::string(argv[argc - 1]);

    int threadSupportLevel = MPI_THREAD_SINGLE;
    if (engineName == "SST")
    {
        threadSupportLevel = MPI_THREAD_MULTIPLE;
    }

    // MPI_THREAD_MULTIPLE is only required if you enable the SST MPI_DP
    MPI_Init_thread(&argc, &argv, threadSupportLevel, &provided);

    /* When writer and reader is launched together with a single mpirun command,
       the world comm spans all applications. We have to split and create the
       local 'world' communicator mpiHeatTransferComm for the writer only.
       When writer and reader is launched separately, the mpiHeatTransferComm
       communicator will just equal the MPI_COMM_WORLD.
     */

    int wrank, wnproc;
    MPI_Comm_rank(MPI_COMM_WORLD, &wrank);
    MPI_Comm_size(MPI_COMM_WORLD, &wnproc);

    const unsigned int color = 1;
    MPI_Comm mpiHeatTransferComm;
    MPI_Comm_split(MPI_COMM_WORLD, color, wrank, &mpiHeatTransferComm);

    int rank, nproc;
    MPI_Comm_rank(mpiHeatTransferComm, &rank);
    MPI_Comm_size(mpiHeatTransferComm, &nproc);

    try
    {
        double timeStart = MPI_Wtime();
        Settings settings(argc, argv, rank, nproc);
        HeatTransfer ht(settings);
        IO io(settings, mpiHeatTransferComm);

        ht.init(mpiHeatTransferComm, false);
        // ht.printT("Initialized T:", mpiHeatTransferComm);
        ht.heatEdges();
        ht.exchange(mpiHeatTransferComm);
        // ht.printT("Heated T:", mpiHeatTransferComm);

        unsigned int t = 0;
        unsigned int tin = 0;
        for (unsigned int iter = 0; iter < settings.iterations; ++iter)
        {
            if (iter % settings.write_freq == 0)
            {
                if (rank == 0)
                    std::cout << "Output step " << t << " iteration " << iter << std::endl;

                io.write(iter, ht, settings, mpiHeatTransferComm);
                if (iter && iter % settings.read_freq == 0)
                {
                    if (rank == 0)
                        std::cout << "Input step " << tin << " iteration " << iter << " reads back output step " << t << std::endl;

                    unsigned int iterread = io.read(ht, t, settings, mpiHeatTransferComm);
                    if (iterread != iter)
                    {
                        throw std::runtime_error("Expected reading back output step " + std::to_string(t) + ", iteration " +
                                                 std::to_string(iter) + " but we read in iter " + std::to_string(iterread));
                    }
                    ++tin;
                    ht.exchange(mpiHeatTransferComm);
                }
                ++t;
            }

            ht.iterate();
            ht.exchange(mpiHeatTransferComm);
            ht.heatEdges();
        }
        MPI_Barrier(mpiHeatTransferComm);

        double timeEnd = MPI_Wtime();
        if (rank == 0)
            std::cout << "Total runtime = " << timeEnd - timeStart << "s\n";
    }
    catch (std::invalid_argument &e) // command-line argument errors
    {
        std::cout << e.what() << std::endl;
        printUsage();
    }
    catch (std::ios_base::failure &e) // I/O failure (e.g. file not found)
    {
        std::cout << "I/O base exception caught\n";
        std::cout << e.what() << std::endl;
    }
    catch (std::exception &e) // All other exceptions
    {
        std::cout << "Exception caught\n";
        std::cout << e.what() << std::endl;
    }

    MPI_Finalize();
    return 0;
}
