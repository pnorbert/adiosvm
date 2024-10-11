#------------------------------------------------------------------------------#
# Distributed under the OSI-approved Apache License, Version 2.0.  See
# accompanying file Copyright.txt for details.
#------------------------------------------------------------------------------#

add_executable(heatTransferWrite
    main.cpp
    HeatTransfer.cpp
    Settings.cpp
    IO_adios2.cpp
)

target_link_libraries(heatTransferWrite adios2::cxx11_mpi MPI::MPI_CXX)
install(TARGETS heatTransferWrite RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

