#include <fstream>
#include <iostream>
#include <sstream>
#include <vector>

#include <adios2.h>
#include <mpi.h>

#include "../common/timer.hpp"
#include "gray-scott.h"

void define_bpvtk_attribute(const Settings &s, adios2::IO &io)
{
    auto lf_VTKImage = [](const Settings &s, adios2::IO &io) {
        const std::string extent = "0 " + std::to_string(s.L + 1) + " " + "0 " +
                                   std::to_string(s.L + 1) + " " + "0 " +
                                   std::to_string(s.L + 1);

        const std::string imageData = R"(
        <?xml version="1.0"?>
        <VTKFile type="ImageData" version="0.1" byte_order="LittleEndian">
          <ImageData WholeExtent=")" + extent +
                                      R"(" Origin="0 0 0" Spacing="1 1 1">
            <Piece Extent=")" + extent +
                                      R"(">
              <CellData Scalars="U">
                  <DataArray Name="U" />
                  <DataArray Name="V" />
                  <DataArray Name="TIME">
                    step
                  </DataArray>
              </CellData>
            </Piece>
          </ImageData>
        </VTKFile>)";

        io.DefineAttribute<std::string>("vtk.xml", imageData);
    };

    if (s.mesh_type == "image") {
        lf_VTKImage(s, io);
    } else if (s.mesh_type == "structured") {
        throw std::invalid_argument(
            "ERROR: mesh_type=structured not yet "
            "   supported in settings.json, use mesh_type=image instead\n");
    }
    // TODO extend to other formats e.g. structured
}

void print_io_settings(const adios2::IO &io)
{
    std::cout << "Simulation writes data using engine type:              "
              << io.EngineType() << std::endl;
}

void print_settings(const Settings &s)
{
    std::cout << "grid:             " << s.L << "x" << s.L << "x" << s.L
              << std::endl;
    std::cout << "steps:            " << s.steps << std::endl;
    std::cout << "plotgap:          " << s.plotgap << std::endl;
    std::cout << "F:                " << s.F << std::endl;
    std::cout << "k:                " << s.k << std::endl;
    std::cout << "dt:               " << s.dt << std::endl;
    std::cout << "Du:               " << s.Du << std::endl;
    std::cout << "Dv:               " << s.Dv << std::endl;
    std::cout << "noise:            " << s.noise << std::endl;
    std::cout << "output:           " << s.output << std::endl;
    std::cout << "adios_config:     " << s.adios_config << std::endl;
}

void print_simulator_settings(const GrayScott &s)
{
    std::cout << "decomposition:    " << s.npx << "x" << s.npy << "x" << s.npz
              << std::endl;
    std::cout << "grid per process: " << s.size_x << "x" << s.size_y << "x"
              << s.size_z << std::endl;
}

int main(int argc, char **argv)
{
    MPI_Init(&argc, &argv);
    int rank, procs, wrank;

    MPI_Comm_rank(MPI_COMM_WORLD, &wrank);

    const unsigned int color = 1;
    MPI_Comm comm;
    MPI_Comm_split(MPI_COMM_WORLD, color, wrank, &comm);

    MPI_Comm_rank(comm, &rank);
    MPI_Comm_size(comm, &procs);

    if (argc < 2) {
        if (rank == 0) {
            std::cerr << "Too few arguments" << std::endl;
            std::cerr << "Usage: gray-scott settings.json" << std::endl;
        }
        MPI_Abort(MPI_COMM_WORLD, -1);
    }

    Settings settings = Settings::from_json(argv[1]);

    GrayScott sim(settings, comm);

    sim.init();

    adios2::ADIOS adios(settings.adios_config, comm, adios2::DebugON);

    adios2::IO io = adios.DeclareIO("SimulationOutput");

    if (rank == 0) {
        print_io_settings(io);
        std::cout << "========================================" << std::endl;
        print_settings(settings);
        print_simulator_settings(sim);
        std::cout << "========================================" << std::endl;
    }

    io.DefineAttribute<double>("F", settings.F);
    io.DefineAttribute<double>("k", settings.k);
    io.DefineAttribute<double>("dt", settings.dt);
    io.DefineAttribute<double>("Du", settings.Du);
    io.DefineAttribute<double>("Dv", settings.Dv);
    io.DefineAttribute<double>("noise", settings.noise);
    // define VTK visualization schema as an attribute
    if (!settings.mesh_type.empty()) {
        define_bpvtk_attribute(settings, io);
    }

    adios2::Variable<double> varU =
        io.DefineVariable<double>("U", {settings.L, settings.L, settings.L},
                                  {sim.offset_z, sim.offset_y, sim.offset_x},
                                  {sim.size_z, sim.size_y, sim.size_x});

    adios2::Variable<double> varV =
        io.DefineVariable<double>("V", {settings.L, settings.L, settings.L},
                                  {sim.offset_z, sim.offset_y, sim.offset_x},
                                  {sim.size_z, sim.size_y, sim.size_x});

    adios2::Variable<int> varStep = io.DefineVariable<int>("step");

    adios2::Engine writer = io.Open(settings.output, adios2::Mode::Write);

#ifdef ENABLE_TIMERS
    Timer timer_total;
    Timer timer_compute;
    Timer timer_write;

    std::ostringstream log_fname;
    log_fname << "gray_scott_pe_" << rank << ".log";

    std::ofstream log(log_fname.str());
    log << "step\ttotal_gs\tcompute_gs\twrite_gs" << std::endl;
#endif

    for (int i = 0; i < settings.steps;) {
#ifdef ENABLE_TIMERS
        MPI_Barrier(comm);
        timer_total.start();
        timer_compute.start();
#endif

        for (int j = 0; j < settings.plotgap; j++) {
            sim.iterate();
            i++;
        }

#ifdef ENABLE_TIMERS
        double time_compute = timer_compute.stop();
        MPI_Barrier(comm);
        timer_write.start();
#endif

        if (rank == 0) {
            std::cout << "Simulation at step " << i
                      << " writing output step     " << i / settings.plotgap
                      << std::endl;
        }

        if (settings.adios_span) {
            writer.BeginStep();
            writer.Put<int>(varStep, &i);

            // provide memory directly from adios buffer
            adios2::Variable<double>::Span u_span = writer.Put<double>(varU);
            adios2::Variable<double>::Span v_span = writer.Put<double>(varV);

            // populate spans
            sim.u_noghost(u_span.data());
            sim.v_noghost(v_span.data());

            writer.EndStep();
        } else {
            std::vector<double> u = sim.u_noghost();
            std::vector<double> v = sim.v_noghost();
            writer.BeginStep();
            writer.Put<int>(varStep, &i);
            writer.Put<double>(varU, u.data());
            writer.Put<double>(varV, v.data());
            writer.EndStep();
        }

#ifdef ENABLE_TIMERS
        double time_write = timer_write.stop();
        double time_step = timer_total.stop();
        MPI_Barrier(comm);

        log << i << "\t" << time_step << "\t" << time_compute << "\t"
            << time_write << std::endl;
#endif
    }

#ifdef ENABLE_TIMERS
    log << "total\t" << timer_total.elapsed() << "\t" << timer_compute.elapsed()
        << "\t" << timer_write.elapsed() << std::endl;

    log.close();
#endif

    writer.Close();

    MPI_Finalize();
}
