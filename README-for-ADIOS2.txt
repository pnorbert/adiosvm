
Download
========

First time:
$ cd ~/Software
$ git clone https://github.com/ornladios/ADIOS2.git
$ cd ADIOS2
$ git checkout master
$ mkdir build

Later:
$ cd ~/Software/ADIOS2
$ git pull


Build
=====
$ cd build
$ cmake -DCMAKE_INSTALL_PREFIX=/opt/adios2 \
      -DCMAKE_BUILD_TYPE=Release  \
      -DCMAKE_PREFIX_PATH="/opt/blosc;/opt/zfp/0.5.5;/opt/SZ/2.0.2.1;/opt/MGARD;/opt/hdf5-parallel" \
      -DADIOS2_USE_MPI=ON \
      -DADIOS2_USE_Python=ON \
      -DADIOS2_USE_Profiling=ON \
      -DADIOS2_BUILD_TESTING=OFF \
      ..

It should produce

ADIOS2 build configuration:
  ADIOS Version: 2.5.0
  C++ Compiler : GNU 5.4.0 
    /usr/bin/c++

  Fortran Compiler : GNU 5.4.0 
    /usr/bin/f95

  Installation prefix: /opt/adios2
        bin: bin
        lib: lib
    include: include
      cmake: lib/cmake/adios2
     python: lib/python3.5/site-packages

  Features:
    Library Type: shared
    Build Type:   Release
    Testing: OFF
    Examples: ON
    Build Options:
      Blosc    : ON
      BZip2    : ON
      ZFP      : ON
      SZ       : ON
      MGARD    : ON
      PNG      : ON
      MPI      : ON
      DataMan  : ON
      Table    : ON
      SSC      : ON
      SST      : ON
      DataSpaces: OFF
      ZeroMQ   : ON
      HDF5     : ON
      Python   : ON
      Fortran  : ON
      SysVShMem: ON
      Profiling: ON
      Endian_Reverse: OFF
    RDMA Transport for Staging: Unconfigured
-- Configuring done
-- Generating done
-- Build files have been written to: /home/adios/Software/ADIOS2/build



$ make -j 4

Run Heat Transfer example
=========================
$ cd ~/Software/ADIOS2/build
$ mpirun -np 12 ./bin/heatTransfer_write_adios2 heat 4 3 100 100 5 100
$ visit -o heat.bp


