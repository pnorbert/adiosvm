#ifndef libIsoSurface_h_
#define libIsoSurface_h_

#include <string>
#include <memory>
#include <vector>

#include <mpi.h>

#include <adios2.h>

class IsoSurface
{
public:
    IsoSurface(MPI_Comm comm, adios2::IO &io, const std::string &in,
               const std::string &out, const std::vector<double> &isoValues,
               bool isInline);

    ~IsoSurface();

    bool Step();

private:
    struct IsoSurfaceImpl;
    std::unique_ptr<IsoSurfaceImpl> Impl;
};

#endif // libIsoSurface_h_
