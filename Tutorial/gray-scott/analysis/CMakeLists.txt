find_package(MPI REQUIRED)
find_package(ADIOS2 REQUIRED)
find_package(VTK REQUIRED)
find_package(VTKm REQUIRED)

add_executable(isosurface isosurface.cpp)
target_link_libraries(isosurface MPI::MPI_CXX adios2::adios2 vtkm_cont)

add_executable(curvature curvature.cpp)
target_link_libraries(curvature MPI::MPI_CXX adios2::adios2 ${VTK_LIBRARIES})
