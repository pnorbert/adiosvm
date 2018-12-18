find_package(MPI REQUIRED)
find_package(VTKm REQUIRED)

add_executable(isosurface isosurface.cpp)
target_include_directories(isosurface PRIVATE ${MPI_CXX_INCLUDE_PATH})
target_compile_options(isosurface PRIVATE ${MPI_CXX_COMPILE_FLAGS})
target_link_libraries(isosurface ${MPI_CXX_LIBRARIES} ${MPI_CXX_LINK_FLAGS} adios2 vtkm_cont)
