cmake_minimum_required(VERSION 3.10)

set(CMAKE_CXX_STANDARD 11)
# ENABLE ADIOS2_ROOT
if(POLICY CMP0074)
  cmake_policy(SET CMP0074 NEW)
endif()

project(gray-scott C CXX)

find_package(MPI REQUIRED)
find_package(ADIOS2 REQUIRED)

option(USE_TIMERS "Use profiling timers")
if(USE_TIMERS)
  message(STATUS "Enabling profiling timers")
  add_definitions(-DENABLE_TIMERS)
endif()

# We are not using the C++ API of MPI, this will stop the compiler look for it
add_definitions(-DOMPI_SKIP_MPICXX -DMPICH_SKIP_MPICXX)

add_executable(gray-scott
  simulation/main.cpp
  simulation/gray-scott.cpp
  simulation/settings.cpp
  simulation/writer.cpp
)
target_link_libraries(gray-scott adios2::adios2 MPI::MPI_C)

add_executable(pdf_calc analysis/pdf_calc.cpp)
target_link_libraries(pdf_calc adios2::adios2 MPI::MPI_C)

option(VTK "Build VTK apps")
if (VTK_ROOT)
  set(VTK ON)
endif()

if (VTK)
  message(STATUS "Configuring VTK apps")

  find_package(VTK COMPONENTS
    FiltersCore IOImage IOXML IOParallelXML ParallelMPI
  )

  if(VTK_FOUND)
    add_executable(isosurface analysis/isosurface.cpp)
    target_link_libraries(isosurface adios2::adios2 ${VTK_LIBRARIES}
      MPI::MPI_C)

    add_executable(BlockIsoSurface
      analysis/mainIsoSurface.cpp
      analysis/libIsoSurface.cpp)
    target_link_libraries(BlockIsoSurface
      adios2::adios2 MPI::MPI_C
      VTK::CommonCore VTK::CommonDataModel
      VTK::FiltersCore VTK::FiltersGeneral
      VTK::IOImage VTK::IOXML VTK::IOParallelXML VTK::ParallelMPI
    )

    add_executable(gray-scott-iso
      analysis/libIsoSurface.cpp
      simulation/main.cpp
      simulation/gray-scott.cpp
      simulation/settings.cpp
      simulation/writer.cpp
    )
    target_link_libraries(gray-scott-iso
      adios2::adios2 MPI::MPI_C
      VTK::CommonCore VTK::CommonDataModel
      VTK::FiltersCore VTK::FiltersGeneral
      VTK::IOImage VTK::IOXML VTK::IOParallelXML VTK::ParallelMPI
    )
    target_compile_definitions(gray-scott-iso PRIVATE USE_INLINE_ISOSURFACE=1)
  endif()

  find_package(VTK COMPONENTS FiltersCore FiltersGeometry IOXML)

  if(VTK_FOUND)
    add_executable(find_blobs analysis/find_blobs.cpp)
    target_link_libraries(find_blobs adios2::adios2 ${VTK_LIBRARIES}
      MPI::MPI_C)
  endif()

  find_package(VTK COMPONENTS FiltersGeneral)

  if(VTK_FOUND)
    add_executable(compute_curvature analysis/curvature.cpp)
    target_link_libraries(compute_curvature adios2::adios2 ${VTK_LIBRARIES}
      MPI::MPI_C)
  endif()


  find_package(VTK COMPONENTS RenderingOpenGL2 ViewsInfovis)

  if(VTK_FOUND)
    add_executable(render_isosurface plot/render_isosurface.cpp)
    target_link_libraries(render_isosurface adios2::adios2 ${VTK_LIBRARIES}
      MPI::MPI_C)
  endif()
endif()
