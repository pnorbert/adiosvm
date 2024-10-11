#------------------------------------------------------------------------------#
# Distributed under the OSI-approved Apache License, Version 2.0.  See
# accompanying file Copyright.txt for details.
#------------------------------------------------------------------------------#

cmake_minimum_required(VERSION 3.12)
project(HeatTransfer)

cmake_minimum_required(VERSION 3.12)

set(CMAKE_CXX_STANDARD 17)
if(POLICY CMP0074)
  cmake_policy(SET CMP0074 NEW)
endif()

project(HeatTransfer C CXX)

find_package(MPI REQUIRED)
find_package(ADIOS2 REQUIRED)

# We are not using the C++ API of MPI, this will stop the compiler look for it
add_definitions(-DOMPI_SKIP_MPICXX -DMPICH_SKIP_MPICXX)

add_subdirectory(write)
