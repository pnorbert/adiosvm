#include "writer.h"

#include <iostream>

Writer::Writer(const Settings &settings, const GrayScott &sim, adios2::IO io)
: settings(settings), io(io)
{
    io.DefineAttribute<double>("F", settings.F);
    io.DefineAttribute<double>("k", settings.k);
    io.DefineAttribute<double>("dt", settings.dt);
    io.DefineAttribute<double>("Du", settings.Du);
    io.DefineAttribute<double>("Dv", settings.Dv);
    io.DefineAttribute<double>("noise", settings.noise);

    var_u =
        io.DefineVariable<double>("U", {settings.L, settings.L, settings.L},
                                  {sim.offset_z, sim.offset_y, sim.offset_x},
                                  {sim.size_z, sim.size_y, sim.size_x});

    var_v =
        io.DefineVariable<double>("V", {settings.L, settings.L, settings.L},
                                  {sim.offset_z, sim.offset_y, sim.offset_x},
                                  {sim.size_z, sim.size_y, sim.size_x});

    var_u.SetMemorySelection(
        {{1, 1, 1}, {sim.size_z + 2, sim.size_y + 2, sim.size_x + 2}});
    var_v.SetMemorySelection(
        {{1, 1, 1}, {sim.size_z + 2, sim.size_y + 2, sim.size_x + 2}});

    var_step = io.DefineVariable<int>("step");
}

void Writer::open(const std::string &fname)
{
    writer = io.Open(fname, adios2::Mode::Write);
}

void Writer::write(int step, const GrayScott &sim)
{
    const std::vector<double> &u = sim.u_ghost();
    const std::vector<double> &v = sim.v_ghost();

    writer.BeginStep();
    writer.Put<int>(var_step, &step);
    writer.Put<double>(var_u, u.data());
    writer.Put<double>(var_v, v.data());
    writer.EndStep();
}

void Writer::close() { writer.Close(); }

void Writer::print_settings()
{
    std::cout << "Simulation writes data using engine type:              "
              << io.EngineType() << std::endl;
}
