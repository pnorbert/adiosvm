#include <iostream>
#include <string>
#include <stdexcept>
#include <vector>

#include <mpi.h>
#include <adios2.h>

#ifdef ENABLE_TIMERS
#include "../common/timer.hpp"
#endif

#include "libIsoSurface.h"

int main(int argc, char **argv)
{
    int mpiRank;
    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &mpiRank);

    if(argc < 4)
    {
        if(mpiRank == 0)
        {
            std::cerr << "Error: Too few arguments\n"
                      << "Usage: " << argv[0] << " input output isovalues...\n";
        }
        MPI_Abort(MPI_COMM_WORLD, -1);
    }

    const std::string inputFName(argv[1]);
    const std::string outputFName(argv[2]);

    std::vector<double> isoValues;
    for (int i = 3; i < argc; i++)
    {
        isoValues.push_back(std::stod(argv[i]));
    }

    try
    {
        adios2::ADIOS adios("adios2.xml", MPI_COMM_WORLD, adios2::DebugON);
        adios2::IO io = adios.DeclareIO("SimulationOutput");

        IsoSurface analysis(MPI_COMM_WORLD, io, inputFName, outputFName,
                            isoValues, false);

        while(analysis.Step());
    }
    catch(const std::exception &ex)
    {
        std::cerr << "Error: " << ex.what() << "\n";
        MPI_Abort(MPI_COMM_WORLD, -2);
    }

    MPI_Finalize();

    return 0;
}
