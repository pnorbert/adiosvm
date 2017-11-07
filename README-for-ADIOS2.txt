First, build ADIOS 1.x as described in README.txt, except that install ADIOS 1.x into /opt/adios2/adios1


Download
========

First time:
$ cd ~/Software
$ git clone https://github.com/ornladios/ADIOS2.git
$ cd ADIOS2
$ git checkout release
$ mkdir build

Later:
$ cd ~/Software/ADIOS2
$ git pull


Build
=====
$ cd build
$ cmake -DADIOS1_DIR=/opt/adios2/adios1 -DHDF5_ROOT=/opt/hdf5-1.8.17-parallel -DADIOS2_USE_ADIOS1=ON -DADIOS2_USE_MPI=ON -DADIOS2_USE_HDF5=ON -DCMAKE_INSTALL_PREFIX=/opt/adios2 ..

It should produce

ADIOS2 build configuration:
  ADIOS Version: 2.0.0
  C++ Compiler : GNU 5.4.0 
    /usr/bin/c++

  Installation prefix: /opt/adios2
  Features:
    Library Type: static
    Build Type:   Debug
    Testing: ON
    Build Options:
      BZip2    : ON
      ZFP      : OFF
      MPI      : ON
      DataMan  : ON
      ZeroMQ   : OFF
      HDF5     : ON
      ADIOS1   : ON
      Python   : OFF
      SysVShMem: ON

$ make -j 4

Run Heat Transfer example
=========================
$ cd ~/Software/ADIOS2/build
$ mpirun -np 12 ./bin/heatTransfer_write_adios2 heat 4 3 100 100 5 100
$ /opt/adios/bin/bpmeta heat.bp
$ visit -o heat.bp


