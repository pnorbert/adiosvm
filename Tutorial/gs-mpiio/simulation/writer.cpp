#include "writer.h"

#include <iostream>

#define CHECK_ERR(func)                                                        \
    {                                                                          \
        if (err != MPI_SUCCESS)                                                \
        {                                                                      \
            int errorStringLen;                                                \
            char errorString[MPI_MAX_ERROR_STRING];                            \
            MPI_Error_string(err, errorString, &errorStringLen);               \
            printf("Error at line %d: calling %s (%s)\n", __LINE__, #func,     \
                   errorString);                                               \
        }                                                                      \
    }

Writer::Writer(const Settings &settings, const GrayScott &sim,
               const MPI_Comm comm)
: settings(settings), comm(comm)
{
    // #IO# make initializations, declarations as necessary
    // information from settings
    // <double>("F", settings.F);
    // <double>("k", settings.k);
    // <double>("dt", settings.dt);
    // <double>("Du", settings.Du);
    // <double>("Dv", settings.Dv);
    // <double>("noise", settings.noise);

    // 3D variables
    // <double> U, V
    // global dimensions: {settings.L, settings.L, settings.L},
    // starting offset:   {sim.offset_z, sim.offset_y, sim.offset_x},
    // local block size:  {sim.size_z, sim.size_y, sim.size_x}

    // u and v has ghost cells
    // local memory block size: {sim.size_z + 2, sim.size_y + 2, sim.size_x + 2}
    // output data starts at offset: {1, 1, 1}

    // information: <int> step   is a single value

    /*
     *  MPI Subarray data type for writing/reading parallel distributed arrays
     *  See case II for array with ghost cells:
     *  https://wgropp.cs.illinois.edu/courses/cs598-s15/lectures/lecture33.pdf
     */

    int fshape[3] = {(int)settings.L, (int)settings.L, (int)settings.L};
    int fstart[3] = {(int)sim.offset_z, (int)sim.offset_y, (int)sim.offset_x};
    int fcount[3] = {(int)sim.size_z, (int)sim.size_y, (int)sim.size_x};
    err = MPI_Type_create_subarray(3, fshape, fcount, fstart, MPI_ORDER_C,
                                   MPI_DOUBLE, &filetype);
    CHECK_ERR(MPI_Type_create_subarray for file type)
    err = MPI_Type_commit(&filetype);
    CHECK_ERR(MPI_Type_commit for file type)
}

void Writer::open(const std::string &fname)
{
    int cmode;
    MPI_Info info;
    MPI_Offset headersize = sizeof(header);

    /* Users can set customized I/O hints in info object */
    info = MPI_INFO_NULL; /* no user I/O hint */

    /* set file open mode */
    cmode = MPI_MODE_CREATE;  /* to create a new file */
    cmode |= MPI_MODE_WRONLY; /* with write-only permission */

    /* collectively open a file, shared by all processes in MPI_COMM_WORLD */
    std::string s = fname + ".u";
    err = MPI_File_open(comm, s.c_str(), cmode, info, &fh);
    CHECK_ERR(MPI_File_open to write)

    int rank;
    MPI_Comm_rank(comm, &rank);
    if (!rank)
    {
        unsigned long long L = static_cast<unsigned long long>(settings.L);
        struct header h = {L, L, L};
        MPI_Status status;
        MPI_File_write(fh, &h, sizeof(h), MPI_BYTE, &status);
    }

    err =
        MPI_File_set_view(fh, headersize, MPI_DOUBLE, filetype, "native", info);
    CHECK_ERR(MPI_File_set_view)
    MPI_Barrier(comm);
}

void Writer::write(int step, const GrayScott &sim)
{
    /* sim.u_ghost() provides access to the U variable as is */
    /* sim.u_noghost() provides a contiguous copy without the ghost cells */
    const std::vector<double> &u = sim.u_noghost();
    const std::vector<double> &v = sim.v_noghost();

    MPI_Status status;
    int nelem = (int)(sim.size_z * sim.size_y * sim.size_x);
    err = MPI_File_write_all(fh, u.data(), nelem, MPI_DOUBLE, &status);
    CHECK_ERR(MPI_File_write_all)
}

void Writer::close()
{
    /* collectively close the file */
    err = MPI_File_close(&fh);
    CHECK_ERR(MPI_File_close);
}

void Writer::print_settings()
{
    std::cout << "Simulation writes data using engine type:              "
              << "native MPI-IO" << std::endl;
}
