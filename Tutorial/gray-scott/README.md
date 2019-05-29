# gray-scott

This is a 3D 7-point stencil code to simulate the following Gray-Scott
reaction diffusion model:

```
u_t = Du * u_xx - u * v^2 + F * (1 - u)
v_t = Dv * v_xx + v * v^2 - (F + k) * v
```

## How to build

Make sure MPI and ADIOS2 are installed and that the PYTHONPATH includes the ADIOS2 package.
Assuming ADIOS2 is installed in /opt/adios2 and was built with python 3.5:

```
$ export PYTHONPATH=/opt/adios2/lib/python3.5/site-packages

$ mkdir build
$ cd build
$ cmake -DADIOS2_DIR=/opt/adios2 ..
$ make
$ cd ..
```

## How to run

```
$ mpirun -n 8 build/gray-scott simulation/settings.json
========================================
grid:             64x64x64
steps:            3000
plotgap:          20
F:                0.02
k:                0.048
dt:               1
Du:               0.2
Dv:               0.1
noise:            0.01
output:           gs.bp
adios_config:     adios2.xml
decomposition:    2x2x2
grid per process: 32x32x32
========================================
Writing step: 0
Writing step: 20
Writing step: 40
Writing step: 60
Writing step: 80
Writing step: 100
...


$ bpls -l gs.bp
  double   U     12*{64, 64, 64} = 0.0956338 / 1.04389
  double   V     12*{64, 64, 64} = 0 / 0.649263


$ python3 plot/gsplot.py -i gs.bp

```

## Analysis example how to run

```
$ mpirun -n 8 build/gray-scott simulation/settings.json
$ mpirun -n 2 build/pdf_calc gs.bp pdf.bp 100
$ bpls -l pdf.bp
  double   U/bins  15*{100} = 0.0889799 / 1.03432
  double   U/pdf   15*{64, 100} = 0 / 2079
  double   V/bins  15*{100} = 0 / 0.650473
  double   V/pdf   15*{64, 100} = 0 / 4096

$ python3 plot/pdfplot.py -i pdf.bp
OR
$ mpirun -n 8 python3 plot/pdfplot.py -i pdf.bp -o u
This is a parallel script, each process plots one PDF.
Each process plots the middle slice of their subarray U/pdf[x:y,:]

```

## How to change the parameters

Edit settings.json to change the parameters for the simulation.

| Key           | Description                           |
| ------------- | ------------------------------------- |
| L             | Size of global array (L x L x L cube) |
| Du            | Diffusion coefficient of U            |
| Dv            | Diffusion coefficient of V            |
| F             | Feed rate of U                        |
| k             | Kill rate of V                        |
| dt            | Timestep                              |
| steps         | Total number of steps to simulate     |
| plotgap       | Number of steps between output        |
| noise         | Amount of noise to inject             |
| output        | Output file/stream name               |
| adios_config  | ADIOS2 XML file name                  |

Decomposition is automatically determined by MPI_Dims_create.

## Examples

| D_u | D_v | F    | k      | Output
| ----|-----|------|------- | -------------------------- |
| 0.2 | 0.1 | 0.02 | 0.048  | ![](img/example1.jpg?raw=true) |
| 0.2 | 0.1 | 0.03 | 0.0545 | ![](img/example2.jpg?raw=true) |
| 0.2 | 0.1 | 0.03 | 0.06   | ![](img/example3.jpg?raw=true) |
| 0.2 | 0.1 | 0.01 | 0.05   | ![](img/example4.jpg?raw=true) |
| 0.2 | 0.1 | 0.02 | 0.06   | ![](img/example5.jpg?raw=true) |


## In situ pipeline example

In adios2.xml, change all IO groups' engine to SST.

      <engine type="SST"

Launch the pipeline in 4 separate terminals:
```
$ mpirun -n 4 build/gray-scott simulation/settings.json
$ mpirun -n 1 build/pdf_calc gs.bp pdf.bp 100
$ mpirun -n 1 python3 plot/pdfplot.py -i pdf.bp
$ mpirun -n 1 python3 plot/gsplot.py -i gs.bp
```

MPMD mode run in a single terminal:
```
$ mpirun -n 4 build/gray-scott simulation/settings.json : \
         -n 1 build/pdf_calc gs.bp pdf.bp 100 :           \
         -n 1 python3 plot/pdfplot.py -i pdf.bp :         \
         -n 1 python3 plot/gsplot.py -i gs.bp
```

