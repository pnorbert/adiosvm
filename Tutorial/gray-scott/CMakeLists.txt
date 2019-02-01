cmake_minimum_required(VERSION 3.9)

set(CMAKE_CXX_STANDARD 11)

project(gray-scott C CXX)

find_package(MPI REQUIRED)
find_package(ADIOS2 REQUIRED)

# We are not using the C++ API of MPI, this will stop the compiler look for it
add_definitions(-DOMPI_SKIP_MPICXX -DMPICH_SKIP_MPICXX)   

add_executable(gray-scott simulation/main.cpp simulation/gray-scott.cpp simulation/settings.cpp)
target_link_libraries(gray-scott adios2::adios2 MPI::MPI_C)

add_executable(pdf_calc analysis/pdf_calc.cpp)
target_link_libraries(pdf_calc adios2::adios2 MPI::MPI_C)

