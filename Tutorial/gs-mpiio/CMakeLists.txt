cmake_minimum_required(VERSION 3.10)

set(CMAKE_CXX_STANDARD 11)
if(POLICY CMP0074)
  cmake_policy(SET CMP0074 NEW)
endif()

project(gray-scott C CXX)

find_package(MPI REQUIRED)
# #IO# look for ADIOS2
find_package(ADIOS2 REQUIRED)

# We are not using the C++ API of MPI, this will stop the compiler look for it
add_definitions(-DOMPI_SKIP_MPICXX -DMPICH_SKIP_MPICXX)

add_executable(gray-scott
  simulation/main.cpp
  simulation/gray-scott.cpp
  simulation/settings.cpp
  simulation/writer.cpp
)
# #IO# add link dependency adios2::cxx11_mpi
target_link_libraries(gray-scott adios2::cxx11_mpi MPI::MPI_C)

add_executable(pdf-calc analysis/pdf-calc.cpp)
# #IO# add link dependency adios2::cxx11_mpi
target_link_libraries(pdf-calc adios2::cxx11_mpi MPI::MPI_C)


#
# Install commands
#
install(TARGETS gray-scott
	RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX})
install(TARGETS pdf-calc
	RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX})

install(FILES "adios2.xml"
              "simulation/settings-files.json"
              "plot/gsplot.py" 
              "README.md"
        DESTINATION ${CMAKE_INSTALL_PREFIX})


install(PROGRAMS "cleanup.sh"
        DESTINATION ${CMAKE_INSTALL_PREFIX})
