#include <cstdint>

#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
//#include <math.h>
//#include <memory>
//#include <stdexcept>
#include <string>
#include <vector>
#include <mpi.h>
#include <adios_read.h>

void printData(std::vector<int> x, int steps, uint64_t nelems,
        uint64_t offset, int rank);

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
    const char *inputfile = argv[1];

    adios_read_init_method(ADIOS_READ_METHOD_BP, comm, "verbose=3");

    ADIOS_FILE *f;
    f = adios_read_open_file(inputfile, ADIOS_READ_METHOD_BP, comm);
    if (f == NULL)
    {
        std::cout << adios_errmsg() << std::endl;
        return -1;
    }

    ADIOS_VARINFO *vgnx = adios_inq_var(f, "gnx");
    unsigned int gnx = *(unsigned int *)vgnx->value;
    int nsteps = vgnx->nsteps;
    if (rank == 0)
    {
        std::cout << "gnx = " << gnx << std::endl;
        std::cout << "nsteps = " << nsteps << std::endl;
    }
    adios_free_varinfo(vgnx);


    // 1D decomposition of the columns, which is inefficient for reading!
    uint64_t readsize = gnx / nproc;
    uint64_t offset = rank * readsize;
    if (rank == nproc - 1)
    {
        // last process should read all the rest of columns
        readsize = gnx - readsize * (nproc - 1);
    }

    MPI_Barrier(comm);
    std::cout << "rank " << rank << " reads " << readsize
              << " columns from offset " << offset << std::endl;

    std::vector<int> x(nsteps * readsize) ;

    // Create a 2D selection for the subset
    ADIOS_SELECTION *sel = adios_selection_boundingbox(1, &offset, &readsize);

    // Arrays are read by scheduling one or more of them
    // and performing the reads at once
    adios_schedule_read(f, sel, "x", 0, nsteps, x.data());
    adios_perform_reads(f, 1);

    printData(x, nsteps, readsize, offset, rank);
    adios_read_close(f);
    adios_selection_delete(sel);
    adios_read_finalize_method(ADIOS_READ_METHOD_BP);
    MPI_Barrier(comm);
    MPI_Finalize();
    return 0;
}

void printData(std::vector<int> x, int steps, uint64_t nelems,
        uint64_t offset, int rank)
{
    std::ofstream myfile;
    // The next line does not work with PGI compiled code
    //std::string filename = "reader." + std::to_string(rank)+".txt";
    std::stringstream ss;
    ss << "reader." << rank << ".txt";
    std::string filename = ss.str();

    myfile.open(filename);
    myfile << "rank=" << rank << " columns=" << nelems
           << " offset=" << offset
           << " steps=" << steps << std::endl;
    myfile << " time   columns " << offset << "..."
           << offset+nelems-1 << std::endl;

    myfile << "             ";
    for (int j = 0; j < nelems; j++)
        myfile << std::setw(5) << offset + j;
    myfile << "\n-------------";
    for (int j = 0; j < nelems; j++)
        myfile << "-----";
    myfile << std::endl;


    for (int step = 0; step < steps; step++)
    {
        myfile << std::setw(5) << step << "        ";
        for (int i = 0; i < nelems; i++)
        {
            myfile << std::setw(5) << x[step*nelems + i];
        }
        myfile << std::endl;
    }
    myfile.close();
}
