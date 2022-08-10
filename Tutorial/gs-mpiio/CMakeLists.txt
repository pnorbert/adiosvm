cmake_minimum_required(VERSION 3.10)

set(CMAKE_CXX_STANDARD 11)
if(POLICY CMP0074)
  cmake_policy(SET CMP0074 NEW)
endif()

project(gray-scott C CXX)

find_package(MPI REQUIRED)
# #IO# look for ADIOS2

# We are not using the C++ API of MPI, this will stop the compiler look for it
add_definitions(-DOMPI_SKIP_MPICXX -DMPICH_SKIP_MPICXX)

add_executable(gray-scott
  simulation/main.cpp
  simulation/gray-scott.cpp
  simulation/settings.cpp
  simulation/writer.cpp
)
target_link_libraries(gray-scott MPI::MPI_C)
# #IO# add link dependency adios2::cxx11_mpi

add_executable(pdf-calc analysis/pdf-calc.cpp)
target_link_libraries(pdf-calc MPI::MPI_C)
# #IO# add link dependency adios2::cxx11_mpi


#
# Install commands
#
install(TARGETS gray-scott
	RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX})
install(TARGETS pdf-calc
	RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX})

install(FILES "adios2.xml"
              "simulation/settings-files.json"
              "plot/decomp.py" "plot/gsplot.py" "plot/pdfplot.py"
              "README.md"
        DESTINATION ${CMAKE_INSTALL_PREFIX})


install(PROGRAMS "cleanup.sh"
        DESTINATION ${CMAKE_INSTALL_PREFIX})
