# How to modify this example to write/read with ADIOS2

## Gray-Scott simulation to write data

1. Add #include "adios2.h" to simulation/writer.h and simulation/main.cpp

2. Fix build issues: add ADIOS2 to the build in CMakeLists.txt
* add `find_package(ADIOS2 REQUIRED)` to CMakeLists.txt after MPI
* add `adios2::cxx11_mpi` to the `target_link_libraries` of both gray-scott and pdf-calc
* add to the cmake command line `-DCMAKE_PREFIX_PATH=<adios2_install_path>`

3. **main.cpp**
* Add library initialization to main.cpp after `sim.init()`
    - `adios2::ADIOS adios(settings.adios_config, comm);`
* Create an IO object in main.cpp that will be passed to Writer
    - `adios2::IO io_main = adios.DeclareIO("SimulationOutput");`
    - *SimulationOutput* is a label that can be used in XML config file to set up for runtime
* Pass IO object as third argument to writer()
    - `Writer writer(settings, sim, io_main);`

4. **writer.h**
* Add IO library to the constructor
    - `Writer(const Settings &settings, const GrayScott &sim, adios2::IO io);`
* Add ADIOS2 objects to protected area that we will use in output
```
    adios2::IO io;
    adios2::Engine writer;
    adios2::Variable<double> var_u, var_v;
    adios2::Variable<int> var_step;
```

* Note: IO is a small object that can be copied. You can use references as well, just make sure you use `&` in both declarations and also in writer.cpp

5. **writer.cpp**  Open/close
* Fix constructor to deal with IO argument
    - `Writer::Writer(const Settings &settings, const GrayScott &sim, adios2::IO io)`
      `: settings(settings), io(io)`
* Create output stream in Writer::open()
    - `writer = io.Open(fname, adios2::Mode::Write);`
* Close output stream in Writer::close()
    - `writer.Close();`
* Print the runtime engine type in Writer::print_settings()
    - replace `"NONE"` with  `io.EngineType()`

6. **writer.cpp** Define content 
* in constructor, define all attributes and variables that we will write every step. Since the decomposition and data size does not change in this application, this can be done ahead of writing steps. 
* For each commented information element, create an attribute (fixed label)
```
    io.DefineAttribute<double>("F", settings.F);
    io.DefineAttribute<double>("k", settings.k);
    io.DefineAttribute<double>("dt", settings.dt);
    io.DefineAttribute<double>("Du", settings.Du);
    io.DefineAttribute<double>("Dv", settings.Dv);
    io.DefineAttribute<double>("noise", settings.noise);
```
* for variable U and V, define a double type, 3D variable
```
    var_u = io.DefineVariable<double>("U", {settings.L, settings.L, settings.L},
            {sim.offset_z, sim.offset_y, sim.offset_x}, {sim.size_z, sim.size_y, sim.size_x});
    var_v = io.DefineVariable<double>("V", {settings.L, settings.L, settings.L},
            {sim.offset_z, sim.offset_y, sim.offset_x}, {sim.size_z, sim.size_y, sim.size_x});
```
* since we have ghost cells, the `u` app variable is bigger than the desired output block. We need to specify the missing information: beginning offset in `u` where the output starts `{1,1,1}`, and the total size of `u` which is not known by ADIOS2 otherwise `{sim.size_z + 2, sim.size_y + 2, sim.size_x + 2}}`:
```
    adios2::Dims startoffset = {1,1,1};
    adios2::Dims blocksize = {sim.size_z + 2, sim.size_y + 2, sim.size_x + 2};;
    adios2::Box<adios2::Dims> box = {startoffset, blocksize};
    var_u.SetMemorySelection(box);
    var_v.SetMemorySelection(box);
```


7. **writer.cpp** Write data every step in Writer::write()
* add BeginStep/EndStep 
* make a Put call for variables U,V (nothing is needed for attributes)
```
    writer.BeginStep();
    writer.Put<double>(var_u, u.data());
    writer.Put<double>("V", v.data());
    writer.Put<int>(var_step, step);
    writer.EndStep();
```

