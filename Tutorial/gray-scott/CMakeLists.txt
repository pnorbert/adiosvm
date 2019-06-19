cmake_minimum_required(VERSION 3.10)

set(CMAKE_CXX_STANDARD 11)
# ENABLE ADIOS2_ROOT
if(POLICY CMP0074)
  cmake_policy(SET CMP0074 NEW)
endif()

project(gray-scott C CXX)

find_package(MPI REQUIRED)
find_package(ADIOS2 REQUIRED)

# We are not using the C++ API of MPI, this will stop the compiler look for it
add_definitions(-DOMPI_SKIP_MPICXX -DMPICH_SKIP_MPICXX)

add_executable(gray-scott simulation/main.cpp simulation/gray-scott.cpp simulation/settings.cpp)
target_link_libraries(gray-scott adios2::adios2 MPI::MPI_C)

add_executable(pdf_calc analysis/pdf_calc.cpp)
target_link_libraries(pdf_calc adios2::adios2 MPI::MPI_C)

if (VTK_ROOT)
    set(VTK "ON")
endif (VTK_ROOT)

if (VTK STREQUAL ON)
  message(STATUS "Find VTK")

  find_package(VTK COMPONENTS
    vtkCommonCore
    vtkCommonDataModel
    vtkCommonExecutionModel
    vtkCommonMisc
    vtkFiltersCore
    vtkFiltersGeneral
    vtkFiltersGeometry
    vtkIOImage
    vtkIOXML
    vtkInteractionStyle
    vtkInteractionWidgets
    vtkRenderingContext2D
    vtkRenderingCore
    vtkRenderingOpenGL2
    vtkViewsCore
    vtkViewsInfovis
    vtkkwiml
  )
  
  
  if(VTK_FOUND)
  
      message(STATUS "Found VTK: ${VTK_DIR}")
      include(${VTK_USE_FILE})
  
      add_executable(isosurface analysis/isosurface.cpp)
      target_link_libraries(isosurface adios2::adios2 ${VTK_LIBRARIES} MPI::MPI_C)
  
      add_executable(find_blobs analysis/find_blobs.cpp)
      target_link_libraries(find_blobs adios2::adios2 ${VTK_LIBRARIES} MPI::MPI_C)
  
      add_executable(compute_curvature analysis/curvature.cpp)
      target_link_libraries(compute_curvature adios2::adios2 ${VTK_LIBRARIES} MPI::MPI_C)
  
      add_executable(render_isosurface plot/render_isosurface.cpp)
      target_link_libraries(render_isosurface adios2::adios2 ${VTK_LIBRARIES} MPI::MPI_C)
  
  else()
      message(STATUS "VTK was NOT found, do not build apps using VTK")
  endif(VTK_FOUND)
endif(VTK STREQUAL ON)
