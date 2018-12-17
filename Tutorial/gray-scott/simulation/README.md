# gray-scott

This is a 3D 7-point stencil code to simulate the following Gray-Scott
reaction diffusion model:

```
u_t = Du * u_xx - u * v^2 + F * (1 - u)
v_t = Dv * v_xx + v * v^2 - (F + k) * v
```

## How to build

Make sure MPI and ADIOS2 are installed.

```
$ cmake .
$ make
```

## How to run

```
$ mpiexec -np 8 ./gray-scott settings.json
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
