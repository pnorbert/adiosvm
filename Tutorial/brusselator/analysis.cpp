/*
 * Analysis code for the Brusselator application.
 * Reads variable u_real, u_imag, v_real, v_imag, and computes the norm of U and V.
 * Writes the variables and their computed norm to an ADIOS2 file.
 *
 * Kshitij Mehta
 *
 * @TODO:
 *      - Error checks. What is vector resizing returns an out-of-memory error? Must handle it
 *      - Turn ADIOS2 Debug to ON
 */
#include <iostream>
#include <stdexcept>
#include <cstdint>
#include <cmath>
#include "adios2.h"

/*
 * Function to compute the norm of an array
 */
std::vector<double> compute_norm (std::vector<double> real_part, std::vector<double> imag_part, int dims) {
    int i;
    std::vector<double> norm;
    int comm_size;
    MPI_Comm_size(MPI_COMM_WORLD, &comm_size);

    norm.resize(dims);
    for (i=0; i<dims; i++)
        norm[i] = sqrt( real_part[i]*real_part[i] + imag_part[i]*imag_part[i] );

    return norm;
}

/*
 * MAIN
 */
int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);
    int rank, comm_size;
    
    int u_global_size, v_global_size;
    int u_local_size, v_local_size;
    
    bool firstStep = true;

    MPI_Comm_rank (MPI_COMM_WORLD, &rank);
    MPI_Comm_size (MPI_COMM_WORLD, &comm_size);

    std::vector<long unsigned int> shape_u_real;
    std::vector<long unsigned int> shape_u_imag;
    std::vector<long unsigned int> shape_v_real;
    std::vector<long unsigned int> shape_v_imag;
    
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
    adios2::ADIOS ad ("analysis_adios2.xml", MPI_COMM_WORLD, adios2::DebugOFF);

    // IO object and engine for reading
    adios2::IO reader_io = ad.DeclareIO("analysis_reader");
    adios2::Engine reader_engine = reader_io.Open("./data/brusselator.bp", adios2::Mode::Read, MPI_COMM_WORLD);

    // IO object and engine for writing
    adios2::IO writer_io = ad.DeclareIO("analysis_writer");
    adios2::Engine writer_engine = writer_io.Open("./data/analysis.bp", adios2::Mode::Write, MPI_COMM_WORLD);

    // read data per timestep
    while(true) {

        // Begin step
        adios2::StepStatus read_status  = reader_engine.BeginStep (adios2::StepMode::NextAvailable, 0.0f);
        if (read_status != adios2::StepStatus::OK)
            break;

        if (firstStep) {
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
            var_u_norm = writer_io.DefineVariable<double> ("u_norm",
                    { shape_u_real[0], shape_u_real[1], shape_u_real[2] },
                    { shape_u_real[0]/comm_size * rank, 0, 0 },
                    { shape_u_real[0]/comm_size, shape_u_real[1], shape_u_real[2] } );
            var_v_norm = writer_io.DefineVariable<double> ("v_norm",
                    { shape_v_real[0], shape_v_real[1], shape_v_real[2] },
                    { shape_v_real[0]/comm_size * rank, 0, 0 },
                    { shape_v_real[0]/comm_size, shape_v_real[1], shape_v_real[2] } );

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

            firstStep = false;
        }

        // Read adios2 data
        reader_engine.Get<double>(var_u_real_in, u_real_data);
        reader_engine.Get<double>(var_u_imag_in, u_imag_data);
        reader_engine.Get<double>(var_v_real_in, v_real_data);
        reader_engine.Get<double>(var_v_imag_in, v_imag_data);

        // End adios2 step
        reader_engine.EndStep();

        std::cout << u_real_data[0] << std::endl;
        std::cout << "size" << std::endl;
        std::cout << u_real_data.size() << std::endl;

        // Compute norms
        norm_u = compute_norm(u_real_data, u_imag_data, u_local_size);
        norm_v = compute_norm(v_real_data, v_imag_data, v_local_size);

        std::cout << "Printing norm" << std::endl;
        std::cout << norm_u[1] << std::endl;
        std::cout << norm_v[1] << std::endl;

        // write U, V, and their norms out
        writer_engine.BeginStep ();
        writer_engine.Put<double> (var_u_norm, norm_u.data());
        writer_engine.Put<double> (var_v_norm, norm_v.data());
        writer_engine.Put<double> (var_u_real_out, u_real_data.data());
        writer_engine.Put<double> (var_u_imag_out, u_imag_data.data());
        writer_engine.Put<double> (var_v_real_out, v_real_data.data());
        writer_engine.Put<double> (var_v_imag_out, v_imag_data.data());
        writer_engine.EndStep ();
    }

    // cleanup
    reader_engine.Close();
    writer_engine.Close();
    MPI_Finalize();
    return 0;
}

