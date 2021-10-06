#include "writer.h"

#include <iostream>

Writer::Writer(const Settings &settings, const GrayScott &sim)
: settings(settings)
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
}

void Writer::open(const std::string &fname)
{
    // #IO# Create the output
    std::cout << "Create output stream: " << fname << std::endl;
}

void Writer::write(int step, const GrayScott &sim)
{
    // #IO# Write the output in a given step
    /* sim.u_ghost() provides access to the U variable as is */
    /* sim.u_noghost() provides a contiguous copy without the ghost cells */
    const std::vector<double> &u = sim.u_ghost();
    const std::vector<double> &v = sim.v_ghost();
}

void Writer::close()
{
    // #IO# Close the stream
    std::cout << "Close output stream: " << std::endl;
}

void Writer::print_settings()
{
    // #IO# Just print information at the beginning about the IO setup
    std::cout << "Simulation writes data using engine type:              "
              << "NONE" << std::endl;
}