/*
 * Analysis code for the Gray-Scott application.
 * Reads variable U and V, and computes the PDF for each 2D slices of U and V.
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

// #IO# include IO library
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

/*
 * MAIN
 */
int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);
    int rank, comm_size, wrank;

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

    std::size_t u_global_size, v_global_size;
    std::size_t u_local_size, v_local_size;

    bool firstStep = true;

    std::vector<std::size_t> shape;
    size_t count1;
    size_t start1;

    std::vector<double> u;
    std::vector<double> v;
    int simStep = -5;

    std::vector<double> pdf_u;
    std::vector<double> pdf_v;
    std::vector<double> bins_u;
    std::vector<double> bins_v;

    // #IO# IO library need declarations for input and output data
    // input
    //   <double> var_u_in, var_v_in;
    //   <int> var_step_in;
    // output
    //   <double> var_u_pdf, var_v_pdf;
    //   <double> var_u_bins, var_v_bins;
    //   <int> var_step_out;
    //   <double> var_u_out, var_v_out;

    // #IO# IO library init

    // #IO# IO objects for reading and writing

    if (!rank)
    {
        std::cout << "PDF analysis reads from Simulation using engine type:  "
                  << "NONE" << std::endl;
        std::cout << "PDF analysis writes using engine type:                 "
                  << "NONE" << std::endl;
    }

    // read data per timestep
    int stepAnalysis = 0;
    while (true)
    {
        // #IO# Begin read step
        // have to wait for simulation to produce new step
        // have to check for errors
        // break when there are no more steps
        if (stepAnalysis > 1)
        {
            break;
        }

        int stepSimOut = stepAnalysis; // assuming we did not skip steps

        // #IO# Inquire variables and get
        // - global dimensions (shape)
        // - get min/max
        // var_u_in = double>("U");
        // var_v_in = <double>("V");
        // var_step_in = <int>("step");

        // Set the selection at the first step only, assuming that
        // the variable dimensions do not change across timesteps
        if (firstStep)
        {
            shape = {64, 64, 64}; // var_u_in.Shape();

            // Calculate global and local sizes of U and V
            u_global_size = shape[0] * shape[1] * shape[2];
            u_local_size = u_global_size / comm_size;
            v_global_size = shape[0] * shape[1] * shape[2];
            v_local_size = v_global_size / comm_size;

            // 1D decomposition
            count1 = shape[0] / comm_size;
            start1 = count1 * rank;
            if (rank == comm_size - 1)
            {
                // last process need to read all the rest of slices
                count1 = shape[0] - count1 * (comm_size - 1);
            }

            std::cout << "  rank " << rank << " slice start={" << start1
                      << ",0,0} count={" << count1 << "," << shape[1] << ","
                      << shape[2] << "}" << std::endl;

            // #IO# Set selection for reading from a global shape
            // Each process reads in a 3D slice
            //   offset:  {start1, 0, 0}
            //   size:    {count1, shape[1], shape[2]}
            // for var_u_in and var_v_in

            // #IO# Declare variables to output
            // PDF variables are 2D, each 2D slice has one 1D pdf of nbins
            //   shape:  {shape[0], nbins}
            //   offset: {start1, 0}
            //   size:   {count1, nbins}
            // var_u_pdf = <double> "U/pdf"
            // var_v_pdf = <double> "V/pdf"

            if (!rank)
            {
                // #IO# The bins should be recorded too, but everyone has the
                // same data, so only one process needs to write this
                //   shape:  {nbins}
                //   offset: {0}
                //   size:   {nbins}
                // var_u_bins = <double> "U/bins"
                // var_v_bins = <double> "V/bins"
                // var_step_out = <int> "step";
            }

            if (write_inputvars)
            {
                // #IO# write a copy of the input data
                //   shape:  {shape[0], shape[1], shape[2]}
                //   offset: {start1, 0, 0}
                //   size:   {count1, shape[1], shape[2]}
                // var_u_out = <double> "U"
                // var_v_out = <double> "V"
            }
            firstStep = false;
        }

        // #IO# Read in data
        // read <double> var_u_in --> u
        // read <double> var_v_in --> v
        {
            // Faking read here
            const size_t N = count1 * shape[1] * shape[2];
            u.resize(N);
            v.resize(N);
            for (size_t i = 0; i < N; ++i)
            {
                u[i] = v[i] = stepAnalysis * 1.0;
            }
        }

        if (!rank)
        {
            // #IO# read <int> var_step_in --> simStep
            // Fake read:
            simStep = stepAnalysis * 10;
        }

        // #IO# End read step (let resources about step go)

        if (!rank)
        {
            std::cout << "PDF Analysis step " << stepAnalysis
                      << " processing sim output step " << stepSimOut
                      << " sim compute step " << simStep << std::endl;
        }

        // Calculate min/max of arrays
        std::pair<double, double> minmax_u;
        std::pair<double, double> minmax_v;
        auto mmu = std::minmax_element(u.begin(), u.end());
        minmax_u = std::make_pair(*mmu.first, *mmu.second);
        auto mmv = std::minmax_element(v.begin(), v.end());
        minmax_v = std::make_pair(*mmv.first, *mmv.second);

        // Compute PDF
        std::vector<double> pdf_u;
        std::vector<double> bins_u;
        compute_pdf(u, shape, start1, count1, nbins, minmax_u.first,
                    minmax_u.second, pdf_u, bins_u);

        std::vector<double> pdf_v;
        std::vector<double> bins_v;
        compute_pdf(v, shape, start1, count1, nbins, minmax_v.first,
                    minmax_v.second, pdf_v, bins_v);

        // #IO# write U, V, and their norms
        // Begin output step
        //    <double> var_u_pdf  <-- pdf_u.data()
        //    <double> var_v_pdf <-- pdf_v.data()
        if (!rank)
        {
            // #IO# write the bins
            //  <double> var_u_bins <-- bins_u.data()
            //  <double> var_v_bins <-- bins_v.data()
            //  <int> var_step_out <-- simStep
        }
        if (write_inputvars)
        {
            // #IO# write the input data
            //  <double> var_u_out <-- u.data()
            //  <double> var_v_out <-- v.data()
        }
        // End output step
        ++stepAnalysis;
    }

    // #IO# cleanup (close reader and writer)

    MPI_Barrier(comm);
    MPI_Finalize();
    return 0;
}
