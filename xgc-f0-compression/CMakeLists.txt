cmake_minimum_required (VERSION 3.10)
project (XGCF0CompressionTest)

find_package(Kokkos REQUIRED)
find_package(ADIOS2 REQUIRED COMPONENTS CXX MPI)

add_definitions(-DOMPI_SKIP_MPICXX -DMPICH_SKIP_MPICXX)


add_executable(xgc-f0-compression xgc-f0-compression.cpp)
target_link_libraries(xgc-f0-compression Kokkos::kokkos adios2::adios2 MPI::MPI_C)



