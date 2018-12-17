#ifndef __GRAY_SCOTT_H__
#define __GRAY_SCOTT_H__

#include <random>
#include <vector>

#include <mpi.h>

#include "settings.h"

class GrayScott
{
public:
    // Dimension of process grid
    size_t npx, npy, npz;
    // Coordinate of this rank in processor grid
    size_t px, py, pz;
    // Dimension of local array
    size_t size_x, size_y, size_z;

    GrayScott(const Settings &settings, MPI_Comm comm);
    ~GrayScott();

    void init();
    void iterate();
    std::vector<double> u_noghost() const;
    std::vector<double> v_noghost() const;

protected:
    Settings settings;

    std::vector<double> u, v, u2, v2;

    int rank;
    int procs;
    int west, east, up, down, north, south;
    MPI_Comm comm;
    MPI_Comm cart_comm;

    MPI_Datatype xy_face_type;
    MPI_Datatype xz_face_type;
    MPI_Datatype yz_face_type;

    std::random_device rand_dev;
    std::mt19937 mt_gen;
    std::uniform_real_distribution<double> uniform_dist;

    // Setup cartesian communicator data types
    void init_mpi();
    // Setup initial conditions
    void init_field();

    // Progess simulation for one timestep
    void calc(const std::vector<double> &u, const std::vector<double> &v,
              std::vector<double> &u2, std::vector<double> &v2);
    // Compute reaction term for U
    double calcU(double tu, double tv) const;
    // Compute reaction term for V
    double calcV(double tu, double tv) const;
    // Compute laplacian of field s at (ix, iy, iz)
    double laplacian(int ix, int iy, int iz,
                     const std::vector<double> &s) const;

    // Exchange faces with neighbors
    void sendrecv(std::vector<double> &u, std::vector<double> &v) const;
    // Exchange XY faces with north/south
    void sendrecv_xy(std::vector<double> &local_data) const;
    // Exchange XZ faces with up/down
    void sendrecv_xz(std::vector<double> &local_data) const;
    // Exchange YZ faces with west/east
    void sendrecv_yz(std::vector<double> &local_data) const;

    // Return a copy of data with ghosts removed
    std::vector<double> data_noghost(const std::vector<double> &data) const;

    // Check if point is included in my subdomain
    inline bool is_inside(int x, int y, int z) const
    {
        int sx = size_x * px;
        int sy = size_y * py;
        int sz = size_z * pz;

        int ex = sx + size_x;
        int ey = sy + size_y;
        int ez = sz + size_z;

        if (x < sx) return false;
        if (x >= ex) return false;
        if (y < sy) return false;
        if (y >= ey) return false;
        if (z < sz) return false;
        if (z >= ez) return false;

        return true;
    }
    // Convert global coordinate to local index
    inline int g2i(int gx, int gy, int gz) const
    {
        int sx = size_x * px;
        int sy = size_y * py;
        int sz = size_z * pz;

        int x = gx - sx;
        int y = gy - sy;
        int z = gz - sz;

        return l2i(x + 1, y + 1, z + 1);
    }
    // Convert local coordinate to local index
    inline int l2i(int x, int y, int z) const
    {
        return z + y * (size_z + 2) + x * (size_y + 2) * (size_z + 2);
    }
};

#endif
