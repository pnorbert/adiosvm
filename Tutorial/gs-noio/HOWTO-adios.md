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


## pdf-calc analysis to read data

1. Add #include "adios2.h" to analysis/pdf-calc.cpp

2. `u` and `pdf_u` are program variables that will hold the input/computed data. We need to declare ADIOS variables for the definition of input and output. 
```
    adios2::Variable<double> var_u_in, var_v_in;
    adios2::Variable<int> var_step_in;
    adios2::Variable<double> var_u_pdf, var_v_pdf;
    adios2::Variable<double> var_u_bins, var_v_bins;
    adios2::Variable<int> var_step_out;
    adios2::Variable<double> var_u_out, var_v_out;
```

3. Add library initialization
    - `adios2::ADIOS adios(settings.adios_config, comm);`

4. Create two IO objects for reading Gray-Scott data and writing PDF output
    - `adios2::IO reader_io = adios.DeclareIO("SimulationOutput");`
    - `adios2::IO writer_io = adios.DeclareIO("PDFAnalysisOutput");`
    - *SimulationOutput* is a label that can be used in XML config file to set up for runtime consistently with what Gray-Scott simulation is using
    - *PDFAnalysisOutput* is another label to set up the analysis output for runtime. 

5. Open streams for reading and for writing
    - `adios2::Engine reader = reader_io.Open(in_filename, adios2::Mode::Read, comm);`
    - `adios2::Engine writer = writer_io.Open(out_filename, adios2::Mode::Write, comm);`
6. Set up BeginStep/Endstep loop without knowning how many steps will be available. Replace this snippet that fakes two steps of reading:
```
    if (stepAnalysis > 1)
    {
        break;
    }
```
with this generic code for stepping in ADIOS2
```
    adios2::StepStatus status = reader.BeginStep(adios2::StepMode::Read, 10.0f);
    if (status == adios2::StepStatus::NotReady)
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));
        continue;
    }
    else if (status != adios2::StepStatus::OK)
    {
        break;
    }
```

7. In every step, inquire the variables from the input file to create the ADIOS variable. The scope of the variable object is inside the step, so must inquire every step (variable may not be present in consecutive steps).
```
    var_u_in = reader_io.InquireVariable<double>("U");
    var_v_in = reader_io.InquireVariable<double>("V");
    var_step_in = reader_io.InquireVariable<int>("step");
```

8. In the first step, calculate decomposition (already there), set the per-process read selection and also declare output variables
* Get the actual shape of the incoming variable
    - replace fake `shape = {64, 64, 64};` with `shape = var_u_in.Shape();`
* Read selection
```
    var_u_in.SetSelection({{start1, 0, 0}, {count1, shape[1], shape[2]}});
    var_v_in.SetSelection({{start1, 0, 0}, {count1, shape[1], shape[2]}});
```
* Output variables
```
    var_u_pdf = writer_io.DefineVariable<double>("U/pdf", {shape[0], nbins}, {start1, 0}, {count1, nbins});
    var_v_pdf = writer_io.DefineVariable<double>("V/pdf", {shape[0], nbins}, {start1, 0}, {count1, nbins});

    if (!rank)
    {
        var_u_bins = writer_io.DefineVariable<double>("U/bins", {nbins}, {0}, {nbins});
        var_v_bins = writer_io.DefineVariable<double>("V/bins", {nbins}, {0}, {nbins});
        var_step_out = writer_io.DefineVariable<int>("step");
    }

    if (write_inputvars)
    {
        var_u_out = write_io.DefineVariable<double>("U", {shape[0], shape[1], shape[2]},
                {start1, 0, 0}, {count1, shape[1], shape[2]});
        var_v_out = write_io.DefineVariable<double>("V", {shape[0], shape[1], shape[2]},
                {start1, 0, 0}, {count1, shape[1], shape[2]});
    }
```

9. Read in data (completing read with EndStep)
Replace the fake reading code:
```
    {
        const size_t N = count1 * shape[1] * shape[2];
        u.resize(N);
        v.resize(N);
        for (size_t i = 0; i < N; ++i)
        {
            u[i] = v[i] = stepAnalysis * 1.0;
        }
    }

    if (!rank)
    {
        simStep = stepAnalysis * 10;
    }
```
with
```
    reader.Get<double>(var_u_in, u);
    reader.Get<double>(var_v_in, v);
    if (!rank)
    {
        reader.Get<int>(var_step_in, &simStep);
    }
    reader.EndStep();
    ++stepAnalysis;
```

10. Output the results
```
    writer.BeginStep();
    writer.Put<double>(var_u_pdf, pdf_u.data());
    writer.Put<double>(var_v_pdf, pdf_v.data());
    if (!rank)
    {
        // #IO# write the bins
        writer.Put<double>(var_u_bins, bins_u.data());
        writer.Put<double>(var_v_bins, bins_v.data());
        writer.Put<int>(var_step_out, simStep);
    }
    if (write_inputvars)
    {
        // #IO# write the input data
        writer.Put<double>(var_u_out, u.data());
        writer.Put<double>(var_v_out, v.data());
    }
    writer.EndStep();
```

11. Close the streams outside of the loop
```
    reader.Close();
    writer.Close();
```