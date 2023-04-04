cmake_minimum_required (VERSION 3.10)
project (XGCF0CompressionTest)

find_package(Kokkos REQUIRED)
find_package(MGARD REQUIRED)
find_package(ADIOS2 REQUIRED COMPONENTS CXX MPI)

add_definitions(-DOMPI_SKIP_MPICXX -DMPICH_SKIP_MPICXX)


add_executable(xgc-f0-compression xgc-f0-compression.cpp)
target_link_libraries(xgc-f0-compression Kokkos::kokkos mgard::mgard adios2::adios2 MPI::MPI_C)

add_executable(xgc-f0-compression-cpu xgc-f0-compression-cpu.cpp)
target_link_libraries(xgc-f0-compression-cpu Kokkos::kokkos adios2::adios2 MPI::MPI_C)

add_executable(xgc-f0-compression-vec xgc-f0-compression-vec.cpp)
target_link_libraries(xgc-f0-compression-vec Kokkos::kokkos adios2::adios2 MPI::MPI_C)

add_executable(xgc-f0-compression-adioscompression xgc-f0-compression-adioscompression.cpp)
target_link_libraries(xgc-f0-compression-adioscompression Kokkos::kokkos adios2::adios2 MPI::MPI_C)

add_executable(nrmse nrmse.cpp)
target_link_libraries(nrmse adios2::cxx11)
