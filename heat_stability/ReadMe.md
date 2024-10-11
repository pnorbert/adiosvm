### ADIOS2 heatTransfer example

This example solves a 2D Poisson equation for temperature in homogeneous media
using finite differences. This examples shows a straight-forward way to hook
an application to the ADIOS2 library for its IO.


#### Example

##### 1. Build the example
$ mkdir build
$ cd build
$ cmake -DCMAKE_PREFIX_PATH=<adios2-install-dir> -DCMAKE_INSTALL_PREFIX=install -DCMAKE_BUILD_TYPE=Release ..
$ make -j 8
$ cd ..

##### 1. Produce an output

```
Writer usage:  heatTransfer  config output  N  M   nx  ny   steps iterations
  config: XML config file to use
  output: name of output data file/stream
  N:      number of processes in X dimension
  M:      number of processes in Y dimension
  nx:     local array size in X dimension per processor
  ny:     local array size in Y dimension per processor
  steps:  the total number of steps to output
  iterations: one step consist of this many iterations
```

$ mpirun -n 4 ./build/write/heatTransferWrite  heat_bp5.xml heat.bp 2 2 128 128 200 1 1

###### 2. Plot the results
$ python3 ./plot_heat.py -i heat.bp -o T
see image files as T0\*.png
 
