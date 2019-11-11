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
if(VTK_ROOT)
  set(VTK ON)
endif()

if(VTK)
  message(STATUS "Configuring VTK apps")

  find_package(VTK COMPONENTS vtkFiltersCore vtkIOImage vtkIOXML)
  if(VTK_FOUND)
    message(STATUS "Adding isosurface")
    add_executable(isosurface analysis/isosurface.cpp)
    target_include_directories(isosurface PRIVATE ${VTK_INCLUDE_DIRS})
    target_link_libraries(isosurface
      adios2::adios2 MPI::MPI_C ${VTK_LIBRARIES}
    )
  endif()

  find_package(VTK COMPONENTS
    vtkCommonCore vtkCommonDataModel vtkFiltersCore vtkFiltersGeneral
    vtkIOImage vtkIOXML vtkIOParallelXML vtkParallelMPI
  )
  if(VTK_FOUND)
    message(STATUS "Adding libisosurface")
    add_library(libisosurface analysis/lib-isosurface.cpp)
    target_include_directories(libisosurface
      INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/analysis
      PRIVATE ${VTK_INCLUDE_DIRS}
    )
    target_link_libraries(libisosurface
      PUBLIC adios2::adios2 MPI::MPI_C
      PRIVATE ${VTK_LIBRARIES}
    )

    message(STATUS "Adding block-isosurface")
    add_executable(block-isosurface analysis/block-isosurface.cpp)
    target_link_libraries(block-isosurface
      adios2::adios2 MPI::MPI_C libisosurface
    )

    message(STATUS "Adding gray-scott-iso")
    add_executable(gray-scott-iso
      simulation/main.cpp
      simulation/gray-scott.cpp
      simulation/settings.cpp
      simulation/writer.cpp
    )
    target_link_libraries(gray-scott-iso
      adios2::adios2 MPI::MPI_C libisosurface
    )
    target_compile_definitions(gray-scott-iso PRIVATE USE_INLINE_ISOSURFACE=1)
  endif()

  find_package(VTK COMPONENTS vtkFiltersCore vtkFiltersGeometry vtkIOXML)
  if(VTK_FOUND)
    add_executable(find_blobs analysis/find_blobs.cpp)
    target_include_directories(find_blobs PRIVATE ${VTK_INCLUDE_DIRS})
    target_link_libraries(find_blobs
      adios2::adios2 MPI::MPI_C ${VTK_LIBRARIES}
    )
  endif()

  find_package(VTK COMPONENTS vtkFiltersGeneral)
  if(VTK_FOUND)
    add_executable(compute_curvature analysis/curvature.cpp)
    target_include_directories(compute_curvature PRIVATE ${VTK_INCLUDE_DIRS})
    target_link_libraries(compute_curvature
      adios2::adios2 MPI::MPI_C ${VTK_LIBRARIES}
    )
  endif()

  find_package(VTK COMPONENTS vtkRenderingOpenGL2 vtkViewsInfovis)
  if(VTK_FOUND)
    add_executable(render_isosurface plot/render_isosurface.cpp)
    target_include_directories(render_isosurface PRIVATE ${VTK_INCLUDE_DIRS})
    target_link_libraries(render_isosurface
      adios2::adios2 MPI::MPI_C ${VTK_LIBRARIES}
    )
  endif()
endif()
