/*
 * Analysis code for the Brusselator application.
 * Reads variable u_real, u_imag, v_real, v_imag, and computes the norm of U and V.
 * Writes the variables and their computed norm to an ADIOS2 file.
 *
 * Kshitij Mehta
 *
 * @TODO:
 *      - Error checks. What is vector resizing returns an out-of-memory error? Must handle it
 */
#include <iostream>
#include <stdexcept>
#include <cstdint>
#include <cmath>
#include "adios2.h"

/*
 * Function to compute the norm of a vector
 */
template <class T> 
std::vector<T> compute_norm(const std::vector<T>& real, const std::vector<T>& imag)
{
    if(real.size() != imag.size()) 
        throw std::invalid_argument("ERROR: real and imag parts have different sizes\n"); 
    
    std::vector<T> norm( real.size() );
    
    for (auto i = 0; i < real.size(); ++i )
        norm[i] = std::sqrt( std::pow(real[i], 2.) + std::pow(imag[i], 2.) );
    
    return norm;
}

/*
 * Print info to the user on how to invoke the application
 */
void printUsage()
{
    std::cout
        << "Usage: analysis input_filename output_filename [output_inputdata]\n"
        << "  input_filename:   Name of the input file handle for reading data\n"
        << "  output_filename:  Name of the output file to which data must be written\n"
        << "  output_inputdata: Enter 0 if you want to write the original variables besides the analysis results\n\n";
}

/*
 * MAIN
 */
int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);
    int rank, comm_size, wrank, step_num = 0;

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
        MPI_Abort(comm, -1);
    }

    std::string in_filename;
    std::string out_filename;
    bool write_norms_only = true;
    in_filename = argv[1];
    out_filename = argv[2];
    if (argc >= 4)
    {
        std::string out_norms_only = argv[3];
        if (out_norms_only.compare("0") == 0)
            write_norms_only = false;
    }

    std::size_t u_global_size, v_global_size;
    std::size_t u_local_size, v_local_size;
    
    bool firstStep = true;

    std::vector<std::size_t> shape_u_real;
    std::vector<std::size_t> shape_u_imag;
    std::vector<std::size_t> shape_v_real;
    std::vector<std::size_t> shape_v_imag;
    
    std::vector<double> u_real_data;
    std::vector<double> u_imag_data;
    std::vector<double> v_real_data;
    std::vector<double> v_imag_data;

    std::vector<double> norm_u;
    std::vector<double> norm_v;
    
    // adios2 variable declarations
    adios2::Variable<double> var_u_real_in, var_u_imag_in, var_v_real_in, var_v_imag_in;
    adios2::Variable<double> var_u_norm, var_v_norm;
    adios2::Variable<double> var_u_real_out, var_u_imag_out, var_v_real_out, var_v_imag_out;

    // adios2 io object and engine init
    adios2::ADIOS ad ("adios2.xml", comm, adios2::DebugON);

    // IO object and engine for reading
    adios2::IO reader_io = ad.DeclareIO("SimulationOutput");
    adios2::Engine reader_engine = reader_io.Open(in_filename, adios2::Mode::Read, comm);

    // IO object and engine for writing
    adios2::IO writer_io = ad.DeclareIO("AnalysisOutput2");
    adios2::Engine writer_engine = writer_io.Open(out_filename, adios2::Mode::Write, comm);

    // read data per timestep
    while(true) {

        // Begin step
        adios2::StepStatus read_status  = reader_engine.BeginStep ();
        if (read_status != adios2::StepStatus::OK)
            break;

        step_num ++;
        if (rank == 0)
            std::cout << "Step: " << step_num << std::endl;

        // Inquire variable and set the selection at the first step only
        // This assumes that the variable dimensions do not change across timesteps

        // Inquire variable
        var_u_real_in = reader_io.InquireVariable<double>("u_real");
        var_u_imag_in = reader_io.InquireVariable<double>("u_imag");
        var_v_real_in = reader_io.InquireVariable<double>("v_real");
        var_v_imag_in = reader_io.InquireVariable<double>("v_imag");

        shape_u_real = var_u_real_in.Shape();
        shape_u_imag = var_u_imag_in.Shape();
        shape_v_real = var_v_real_in.Shape();
        shape_v_imag = var_v_imag_in.Shape();

        // Calculate global and local sizes of U and V
        u_global_size = shape_u_real[0] * shape_u_real[1] * shape_u_real[2];
        u_local_size  = u_global_size/comm_size;
        v_global_size = shape_v_real[0] * shape_v_real[1] * shape_v_real[2];
        v_local_size  = v_global_size/comm_size;

        // Set selection
        var_u_real_in.SetSelection(adios2::Box<adios2::Dims>(
                    {shape_u_real[0]/comm_size*rank,0,0},
                    {shape_u_real[0]/comm_size, shape_u_real[1], shape_u_real[2]}));
        var_u_imag_in.SetSelection(adios2::Box<adios2::Dims>(
                    {shape_u_imag[0]/comm_size*rank,0,0},
                    {shape_u_imag[0]/comm_size, shape_u_imag[1], shape_u_imag[2]}));
        var_v_real_in.SetSelection(adios2::Box<adios2::Dims>(
                    {shape_v_real[0]/comm_size*rank,0,0},
                    {shape_v_real[0]/comm_size, shape_v_real[1], shape_v_real[2]}));
        var_v_imag_in.SetSelection(adios2::Box<adios2::Dims>(
                    {shape_v_imag[0]/comm_size*rank,0,0},
                    {shape_v_imag[0]/comm_size, shape_v_imag[1], shape_v_imag[2]}));

        // Declare variables to output
        if (firstStep) {
            var_u_norm = writer_io.DefineVariable<double> ("u_norm",
                    { shape_u_real[0], shape_u_real[1], shape_u_real[2] },
                    { shape_u_real[0]/comm_size * rank, 0, 0 },
                    { shape_u_real[0]/comm_size, shape_u_real[1], shape_u_real[2] } );
            var_v_norm = writer_io.DefineVariable<double> ("v_norm",
                    { shape_v_real[0], shape_v_real[1], shape_v_real[2] },
                    { shape_v_real[0]/comm_size * rank, 0, 0 },
                    { shape_v_real[0]/comm_size, shape_v_real[1], shape_v_real[2] } );

            if ( !write_norms_only) {
                var_u_real_out = writer_io.DefineVariable<double> ("u_real",
                        { shape_u_real[0], shape_u_real[1], shape_u_real[2] },
                        { shape_u_real[0]/comm_size * rank, 0, 0 },
                        { shape_u_real[0]/comm_size, shape_u_real[1], shape_u_real[2] } );
                var_u_imag_out = writer_io.DefineVariable<double> ("u_imag",
                        { shape_u_real[0], shape_u_real[1], shape_u_real[2] },
                        { shape_u_real[0]/comm_size * rank, 0, 0 },
                        { shape_u_real[0]/comm_size, shape_u_real[1], shape_u_real[2] } );
                var_v_real_out = writer_io.DefineVariable<double> ("v_real",
                        { shape_v_real[0], shape_v_real[1], shape_v_real[2] },
                        { shape_v_real[0]/comm_size * rank, 0, 0 },
                        { shape_v_real[0]/comm_size, shape_v_real[1], shape_v_real[2] } );
                var_v_imag_out = writer_io.DefineVariable<double> ("v_imag",
                        { shape_v_real[0], shape_v_real[1], shape_v_real[2] },
                        { shape_v_real[0]/comm_size * rank, 0, 0 },
                        { shape_v_real[0]/comm_size, shape_v_real[1], shape_v_real[2] } );
            }
            firstStep = false;
        }


        // Read adios2 data
        reader_engine.Get<double>(var_u_real_in, u_real_data);
        reader_engine.Get<double>(var_u_imag_in, u_imag_data);
        reader_engine.Get<double>(var_v_real_in, v_real_data);
        reader_engine.Get<double>(var_v_imag_in, v_imag_data);

        // End adios2 step
        reader_engine.EndStep();

        // Compute norms
        norm_u = compute_norm (u_real_data, u_imag_data);
        norm_v = compute_norm (v_real_data, v_imag_data);

        // write U, V, and their norms out
        writer_engine.BeginStep ();
        writer_engine.Put<double> (var_u_norm, norm_u.data());
        writer_engine.Put<double> (var_v_norm, norm_v.data());
        if (!write_norms_only) {
            writer_engine.Put<double> (var_u_real_out, u_real_data.data());
            writer_engine.Put<double> (var_u_imag_out, u_imag_data.data());
            writer_engine.Put<double> (var_v_real_out, v_real_data.data());
            writer_engine.Put<double> (var_v_imag_out, v_imag_data.data());
        }
        writer_engine.EndStep ();
    }

    // cleanup
    reader_engine.Close();
    writer_engine.Close();
    MPI_Finalize();
    return 0;
}

