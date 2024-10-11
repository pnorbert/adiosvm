/*
 * Distributed under the OSI-approved Apache License, Version 2.0.  See
 * accompanying file Copyright.txt for details.
 *
 * IO_ADIOS2.cpp
 *
 *  Created on: Feb 2017
 *      Author: Norbert Podhorszki
 */

#include "IO.h"

#include <string>

#include "adios2.h"

adios2::ADIOS ad;
adios2::IO bpio, bpioIn;
adios2::Engine bpWriter;
adios2::Variable<double> varT;
adios2::Variable<unsigned int> varIteration;

IO::IO(const Settings &s, MPI_Comm comm)
{
    m_outputfilename = s.outputfile;

    ad = adios2::ADIOS(s.configfile, comm);

    bpio = ad.DeclareIO("writer");
    if (!bpio.InConfigFile())
    {
        // if not defined by user, we can change the default settings
        // BPFile is the default engine
        bpio.SetEngine("BPFile");
        bpio.SetParameters({{"num_threads", "1"}});

        // ISO-POSIX file output is the default transport (called "File")
        // Passing parameters to the transport
#ifdef _WIN32
        bpio.AddTransport("File", {{"Library", "stdio"}});
#else
        bpio.AddTransport("File", {{"Library", "posix"}});
#endif
    }
    bpioIn = ad.DeclareIO("reader");

    // define T as 2D global array
    varT = bpio.DefineVariable<double>("T",
                                       // Global dimensions
                                       {s.gndx, s.gndy},
                                       // starting offset of the local array in the global space
                                       {s.offsx, s.offsy},
                                       // local size, could be defined later using SetSelection()
                                       {s.ndx, s.ndy});

    varIteration = bpio.DefineVariable<unsigned int>("iteration");

    bpWriter = bpio.Open(m_outputfilename, adios2::Mode::Write, comm);

    // Promise that we are not going to change the variable sizes nor add new
    // variables
    bpWriter.LockWriterDefinitions();
}

IO::~IO() { bpWriter.Close(); }

void IO::write(unsigned int iteration, const HeatTransfer &ht, const Settings &s, MPI_Comm comm)
{
    bpWriter.BeginStep();
    std::vector<double> v = ht.data_noghost();
    bpWriter.Put<double>(varT, v.data());
    bpWriter.Put<unsigned int>(varIteration, iteration);
    bpWriter.EndStep();
}

unsigned int IO::read(HeatTransfer &ht, const unsigned int expected_step, const Settings &s, MPI_Comm comm)
{
    adios2::Engine bpReader;
    bpioIn.SetParameter("SelectSteps", std::to_string(expected_step));
    bpReader = bpioIn.Open(m_outputfilename, adios2::Mode::ReadRandomAccess, comm);

    std::vector<double> v;
    unsigned int iter;
    auto vT = bpioIn.InquireVariable<double>("T");
    auto vIter = bpioIn.InquireVariable<unsigned int>("iteration");

    vT.SetSelection({{s.offsx, s.offsy}, {s.ndx, s.ndy}});
    bpReader.Get<double>(vT, v);
    bpReader.Get<unsigned int>(vIter, iter);
    bpReader.Close();

    ht.set_data_noghost(v);
    return iter;
}
