
find_package(MPI REQUIRED)

add_executable(gray-scott main.cpp gray-scott.cpp settings.cpp)
target_include_directories(gray-scott PRIVATE ${MPI_CXX_INCLUDE_PATH})
target_compile_options(gray-scott PRIVATE ${MPI_CXX_COMPILE_FLAGS})
target_link_libraries(gray-scott ${MPI_CXX_LIBRARIES} ${MPI_CXX_LINK_FLAGS} adios2)
