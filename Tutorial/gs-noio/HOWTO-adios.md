# How to modify this example to write/read with ADIOS2

## Gray-Scott simulation to write data

1. Add #include "adios2.h" to writer.h and main.cpp
2. Fix build issues: add ADIOS2 to the build in CMakeLists.txt
* add `find_package(ADIOS2 REQUIRED)` to CMakeLists.txt after MPI
* add `adios2::adios2` to the `target_link_libraries` of both gray-scott and pdf-calc
* add to the cmake command line `-DCMAKE_PREFIX_PATH=<adios2_install_path>`


