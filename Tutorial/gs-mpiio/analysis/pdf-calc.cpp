/*
 * Analysis code for the Gray-Scott application.
 * Reads variable U, and computes the PDF for each 2D slices of U
 * Writes the computed PDFs using ADIOS.
 *
 * Norbert Podhorszki, pnorbert@ornl.gov
 *
 */

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

#include <mpi.h>

bool epsilon(double d) { return (d < 1.0e-20); }
bool epsilon(float d) { return (d < 1.0e-20); }

/*
 * Function to compute the PDF of a 2D slice
 */
template <class T>
void compute_pdf(const std::vector<T> &data,
                 const std::vector<std::size_t> &shape, const size_t start,
                 const size_t count, const size_t nbins, const T min,
                 const T max, std::vector<T> &pdf, std::vector<T> &bins)
{
    if (shape.size() != 3)
        throw std::invalid_argument("ERROR: shape is expected to be 3D\n");

    size_t slice_size = shape[1] * shape[2];
    pdf.resize(count * nbins);
    bins.resize(nbins);

    size_t start_data = 0;
    size_t start_pdf = 0;

    T binWidth = (max - min) / nbins;
    for (auto i = 0; i < nbins; ++i)
    {
        bins[i] = min + (i * binWidth);
    }

    if (nbins == 1)
    {
        // special case: only one bin
        for (auto i = 0; i < count; ++i)
        {
            pdf[i] = slice_size;
        }
        return;
    }

    if (epsilon(max - min) || epsilon(binWidth))
    {
        // special case: constant array
        for (auto i = 0; i < count; ++i)
        {
            pdf[i * nbins + (nbins / 2)] = slice_size;
        }
        return;
    }

    for (auto i = 0; i < count; ++i)
    {
        // Calculate a PDF for 'nbins' bins for values between 'min' and 'max'
        // from data[ start_data .. start_data+slice_size-1 ]
        // into pdf[ start_pdf .. start_pdf+nbins-1 ]
        for (auto j = 0; j < slice_size; ++j)
        {
            if (data[start_data + j] > max || data[start_data + j] < min)
            {
                std::cout << " data[" << start * slice_size + start_data + j
                          << "] = " << data[start_data + j]
                          << " is out of [min,max] = [" << min << "," << max
                          << "]" << std::endl;
            }
            size_t bin = static_cast<size_t>(
                std::floor((data[start_data + j] - min) / binWidth));
            if (bin == nbins)
            {
                bin = nbins - 1;
            }
            ++pdf[start_pdf + bin];
        }
        start_pdf += nbins;
        start_data += slice_size;
    }
    return;
}

/*
 * Print info to the user on how to invoke the application
 */
void printUsage()
{
    std::cout
        << "Usage: pdf_calc input output [N] [output_inputdata]\n"
        << "  input:   Name of the input file handle for reading data\n"
        << "  output:  Name of the output file to which data must be written\n"
        << "  N:       Number of bins for the PDF calculation, default = 1000\n"
        << "  output_inputdata: YES will write the original variables besides "
           "the analysis results\n\n";
}

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

struct header_in
{
    unsigned long long z;
    unsigned long long y;
    unsigned long long x;
};

struct header_pdf
{
    unsigned long long nslices;
    unsigned long long nbins;
};

/*
 * MAIN
 */
int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);
    int rank, comm_size, wrank, err;

    MPI_Comm_rank(MPI_COMM_WORLD, &wrank);

    const unsigned int color = 2;
    MPI_Comm comm;
    MPI_Comm_split(MPI_COMM_WORLD, color, wrank, &comm);

    MPI_Comm_rank(comm, &rank);
    MPI_Comm_size(comm, &comm_size);

    if (argc < 3)
    {
        std::cout << "Not enough arguments\n";
        if (rank == 0)
            printUsage();
        MPI_Finalize();
        return 0;
    }

    std::string in_filename;
    std::string out_filename;
    size_t nbins = 1000;
    bool write_inputvars = false;
    in_filename = argv[1];
    out_filename = argv[2];

    if (argc >= 4)
    {
        int value = std::stoi(argv[3]);
        if (value > 0)
            nbins = static_cast<size_t>(value);
    }

    if (argc >= 5)
    {
        std::string value = argv[4];
        std::transform(value.begin(), value.end(), value.begin(), ::tolower);
        if (value == "yes")
            write_inputvars = true;
    }

    std::size_t u_global_size;
    std::size_t u_local_size;
    size_t count1;
    size_t start1;

    std::vector<double> u; // input data
    int simStep = -5;

    std::vector<double> pdf_u;  // output data
    std::vector<double> bins_u; // output data

    // Process header
    struct header_in hdr;
    int nsteps;
    size_t varsize;
    int mode = MPI_MODE_RDONLY;
    MPI_Info info = MPI_INFO_NULL;
    MPI_Status status;
    MPI_File fin;
    // open input file for reading
    err = MPI_File_open(comm, in_filename.c_str(), mode, info, &fin);
    CHECK_ERR(MPI_File_open input)
    if (!rank)
    {
        MPI_Offset filesize;
        err = MPI_File_get_size(fin, &filesize);
        CHECK_ERR(MPI_File_get_size)
        err = MPI_File_read(fin, &hdr, sizeof(hdr), MPI_BYTE, &status);
        CHECK_ERR(MPI_File_read header)
        size_t nelems = hdr.z * hdr.y * hdr.x;
        varsize = nelems * sizeof(double);
        double nsteps_d = (filesize - sizeof(hdr)) / (varsize * 1.0);
        nsteps = (int)nsteps_d;
        if ((double)nsteps != nsteps_d)
        {
            std::cerr << "ERROR file size " << filesize << " is unexpected. "
                      << std::endl;
        }
        std::cout << "Found " << nsteps << " steps in file, size of U is "
                  << hdr.z << "x" << hdr.y << "x" << hdr.x << std::endl;
    }
    MPI_Bcast(&hdr, sizeof(hdr), MPI_BYTE, 0, comm);
    MPI_Bcast(&nsteps, 1, MPI_INT, 0, comm);
    MPI_Bcast(&varsize, 1, MPI_INT, 0, comm);

    std::vector<std::size_t> shape;
    shape.push_back(hdr.z);
    shape.push_back(hdr.y);
    shape.push_back(hdr.x);

    // Calculate global and local sizes of U
    u_global_size = shape[0] * shape[1] * shape[2];
    u_local_size = u_global_size / comm_size;

    // 1D decomposition
    count1 = shape[0] / comm_size;
    start1 = count1 * rank;
    if (rank == comm_size - 1)
    {
        // last process need to read all the rest of slices
        count1 = shape[0] - count1 * (comm_size - 1);
    }

    size_t mynelems = count1 * shape[1] * shape[2];
    u.resize(mynelems);

    // define datatype for reading parallel array
    MPI_Datatype typeInU;
    int fshape[3] = {(int)shape[0], (int)shape[1], (int)shape[2]};
    int fstart[3] = {(int)start1, 0, 0};
    int fcount[3] = {(int)count1, (int)shape[1], (int)shape[2]};
    err = MPI_Type_create_subarray(3, fshape, fcount, fstart, MPI_ORDER_C,
                                   MPI_DOUBLE, &typeInU);
    CHECK_ERR(MPI_Type_create_subarray for input file type)
    err = MPI_Type_commit(&typeInU);
    CHECK_ERR(MPI_Type_commit for input file type)

    err = MPI_File_set_view(fin, sizeof(header_in), MPI_DOUBLE, typeInU,
                            "native", info);
    CHECK_ERR(MPI_File_set_view)

    // define datatype for writing parallel arrays (PDF)
    MPI_Datatype typeOutPDF;
    int pshape[2] = {(int)shape[0], (int)nbins};
    int pstart[2] = {(int)start1, 0};
    int pcount[2] = {(int)count1, (int)nbins};
    err = MPI_Type_create_subarray(2, pshape, pcount, pstart, MPI_ORDER_C,
                                   MPI_DOUBLE, &typeOutPDF);
    CHECK_ERR(MPI_Type_create_subarray for PDF file type)
    err = MPI_Type_commit(&typeOutPDF);
    CHECK_ERR(MPI_Type_commit for PDF file type)

    // create PDF file
    int cmode = MPI_MODE_CREATE | MPI_MODE_WRONLY;
    MPI_Info cinfo = MPI_INFO_NULL;
    MPI_File fpdf;
    std::string pdfname = out_filename + ".pdf";
    err = MPI_File_open(comm, pdfname.c_str(), cmode, cinfo, &fpdf);
    CHECK_ERR(MPI_File_open PDF)
    struct header_pdf hout;
    hout.nbins = nbins;
    hout.nslices = shape[0];
    if (!rank)
    {
        MPI_File_write(fpdf, &hout, sizeof(hout), MPI_BYTE, &status);
    }
    err = MPI_File_set_view(fpdf, sizeof(header_pdf), MPI_DOUBLE, typeOutPDF,
                            "native", info);
    CHECK_ERR(MPI_File_set_view)

    // create BINS file
    MPI_File fbins;
    std::string binsname = out_filename + ".bins";
    err = MPI_File_open(comm, binsname.c_str(), cmode, cinfo, &fbins);
    CHECK_ERR(MPI_File_open BINS)
    if (!rank)
    {
        MPI_File_write(fbins, &nbins, 1, MPI_LONG_LONG, &status);
    }

    MPI_Barrier(comm);

    // read data step-by-step
    for (int step = 0; step < nsteps; ++step)
    {
        // start of U in data file at this step
        MPI_Offset stepOffset = sizeof(header_in) + step * varsize;
        if (!rank)
            std::cout << "Seek to " << stepOffset << std::endl;
        err = MPI_File_seek_shared(fin, stepOffset, MPI_SEEK_SET);
        CHECK_ERR(MPI_File_seek_shared)
        err = MPI_File_read_all(fin, u.data(), mynelems, MPI_DOUBLE, &status);
        CHECK_ERR(MPI_File_read_all)

        if (!rank)
        {
            std::cout << "PDF Analysis step " << step << std::endl;
        }

        // Calculate min/max of arrays
        std::pair<double, double> minmax_u;
        auto mmu = std::minmax_element(u.begin(), u.end());
        minmax_u = std::make_pair(*mmu.first, *mmu.second);
        std::cout << "Rank " << rank << " min = " << *mmu.first
                  << " max = " << *mmu.second << "\n";

        // Compute PDF
        std::vector<double> pdf_u;
        std::vector<double> bins_u;
        compute_pdf(u, shape, start1, count1, nbins, minmax_u.first,
                    minmax_u.second, pdf_u, bins_u);

        // write PDF
        err = MPI_File_write_all(fpdf, pdf_u.data(), count1 * nbins, MPI_DOUBLE,
                                 &status);
        CHECK_ERR(MPI_File_write PDF)

        // write BINS
        if (!rank)
        {
            err = MPI_File_write(fbins, bins_u.data(), nbins, MPI_DOUBLE,
                                 &status);
            CHECK_ERR(MPI_File_write BINS)
        }
    }

    // cleanup (close reader and writer)
    err = MPI_File_close(&fin);
    CHECK_ERR(MPI_File_close on rank0)

    MPI_Barrier(comm);
    MPI_Finalize();
    return 0;
}
