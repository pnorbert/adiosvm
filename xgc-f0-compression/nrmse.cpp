#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <limits>
#include <sys/time.h>
#include <vector>
#include <math.h>

#include <adios2.h>

std::string filename1; // = "xgc.f0.1.bp";
std::string filename2; // = "xgc.f0.2.bp";
std::string varname;   // = "e_f" or "i_f"

std::string DimsToString(const adios2::Dims &dimensions)
{
    std::string dimensionsString("Dims(" + std::to_string(dimensions.size()) + "):[");

    for (const auto dimension : dimensions)
    {
        dimensionsString += std::to_string(dimension) + ", ";
    }
    dimensionsString.pop_back();
    dimensionsString.pop_back();
    dimensionsString += "]";
    return dimensionsString;
}

struct Errors
{
    double ePointwise;
    double eLinf;
    double eNRMSE;
    Errors() : ePointwise(0.0), eLinf(0.0), eNRMSE(0.0){};
};

Errors calc_errors(const std::vector<double> &a1, const std::vector<double> &a2)
{
    Errors e;
    double diff, maxdiff = 0.0;
    double maxv = 0.0;
    double sum = 0.0;

    size_t N = a1.size();
    for (size_t n = 0; n < N; ++n)
    {
        double diff = fabs(a1[n] - a2[n]);
        maxdiff = fmaxf64(maxdiff, diff);
        maxv = fmaxf64(maxv, fabs(a1[n]));
        sum += diff * diff;
    }
    e.ePointwise = maxdiff;
    e.eLinf = maxdiff / maxv;
    e.eNRMSE = sqrtf64(sum / N) / maxv;

    return e;
}

std::vector<Errors> runtest()
{
    adios2::Variable<double> v1, v2;
    adios2::ADIOS ad;
    adios2::IO io1 = ad.DeclareIO("ReadIO1");
    adios2::IO io2 = ad.DeclareIO("ReadIO2");
    adios2::Engine reader1 = io1.Open(filename1, adios2::Mode::ReadRandomAccess);
    adios2::Engine reader2 = io2.Open(filename2, adios2::Mode::ReadRandomAccess);

    v1 = io1.InquireVariable<double>(varname);
    v2 = io2.InquireVariable<double>(varname);
    auto bi = v1.AllStepsBlocksInfo();
    size_t nBlocks = bi[0].size();

    std::cout << "Variable: " << varname << " nBlocks = " << nBlocks << std::endl;

    std::vector<Errors> ev;
    for (size_t b = 0; b < nBlocks; ++b)
    {
        std::cout << "Read block: " << b << std::endl;
        v1.SetBlockSelection(b);
        std::vector<double> a1;
        reader1.Get(v1, a1, adios2::Mode::Sync);

        v2.SetBlockSelection(b);
        std::vector<double> a2;
        reader2.Get(v2, a2, adios2::Mode::Sync);

        std::cout << "Process block: " << b << std::endl;
        ev.push_back(calc_errors(a1, a2));
    }

    reader1.Close();
    reader2.Close();
    return ev;
}

void print_errors(std::vector<Errors> &ev)
{
    Errors maxs;
    std::cout << "Rank :    pointwise       L-inf           NRMSE\n";
    std::cout << "--------------------------------------------------------------\n";
    int p = 9, w = 3 + p;
    for (int r = 0; r < ev.size(); ++r)
    {
        std::cout << std::setw(5) << r << ":   " << std::fixed << std::setw(w) << std::setprecision(p)
                  << ev[r].ePointwise << "    " << std::setw(w) << std::setprecision(p) << ev[r].eLinf << "   "
                  << std::setw(w) << std::setprecision(p) << ev[r].eNRMSE << "\n";
        maxs.ePointwise = (maxs.ePointwise > ev[r].ePointwise ? maxs.ePointwise : ev[r].ePointwise);
        maxs.eLinf = (maxs.eLinf > ev[r].eLinf ? maxs.eLinf : ev[r].eLinf);
        maxs.eNRMSE = (maxs.eNRMSE > ev[r].eNRMSE ? maxs.eNRMSE : ev[r].eNRMSE);
    }
    std::cout << "  max:   " << std::fixed << std::setw(w) << std::setprecision(p) << maxs.ePointwise << "    "
              << std::setw(w) << std::setprecision(p) << maxs.eLinf << "   " << std::setw(w)
              << std::setprecision(p) << maxs.eNRMSE << "\n";
    std::cout << std::endl;
}

void Usage(const char *prgname)
{
    std::cout << "Usage: " << prgname << " file1  file2  varname" << std::endl;
}

int main(int argc, char *argv[])
{
    if (argc < 4)
    {
        Usage(argv[0]);
        return 1;
    }

    filename1 = argv[1];
    filename2 = argv[2];
    varname = argv[3];

    std::cout << "Calculate errors for f0 data\n  input1 = " << filename1 << "\n  input2 = " << filename2
              << std::endl;

    std::vector<Errors> e = runtest();
    print_errors(e);
    return 0;
}
