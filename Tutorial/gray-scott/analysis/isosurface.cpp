#include <chrono>
#include <iostream>

#include <adios2.h>

#include <vtkm/Math.h>
#include <vtkm/cont/DataSet.h>
#include <vtkm/cont/DataSetBuilderUniform.h>
#include <vtkm/cont/DataSetFieldAdd.h>
#include <vtkm/filter/MarchingCubes.h>
#include <vtkm/io/writer/VTKDataSetWriter.h>

vtkm::cont::DataSet compute_isosurface(const adios2::Variable<double> &var,
                                       const std::vector<double> &buf,
                                       double isovalue)
{
    const vtkm::Vec<vtkm::Float64, 3> origin(var.Start()[2], var.Start()[1],
                                             var.Start()[0]);
    const vtkm::Vec<vtkm::Float64, 3> spacing(1, 1, 1);
    const vtkm::Id3 dims(var.Count()[2], var.Count()[1], var.Count()[0]);

    const vtkm::cont::DataSetBuilderUniform dsb;
    vtkm::cont::DataSet input = dsb.Create(dims, origin, spacing);

    const vtkm::Id n_points = dims[0] * dims[1] * dims[2];
    const vtkm::cont::DataSetFieldAdd dsf;
    dsf.AddPointField(input, var.Name(), buf.data(), n_points);

    vtkm::filter::MarchingCubes filter;
    filter.SetIsoValue(0, isovalue);
    filter.SetActiveField(var.Name());

    return filter.Execute(input);
}

void write_vtk(const std::string &fname, const vtkm::cont::DataSet &ds)
{
    vtkm::io::writer::VTKDataSetWriter writer(fname);
    writer.WriteDataSet(ds);
}

void write_adios(adios2::Engine &writer, vtkm::cont::DataSet &ds,
                 adios2::Variable<double> &varPoint,
                 adios2::Variable<int> &varCell)
{
    int cindex = 0;
    auto cdata = ds.GetCoordinateSystem(cindex).GetData();
    auto portal = cdata.GetPortalConstControl();
    size_t nPoints = portal.GetNumberOfValues();
    std::vector<double> points(nPoints * 3);

    for (vtkm::Id i = 0; i < nPoints; i++) {
        const auto &value = portal.Get(i);

        using ValueType = typename vtkm::Vec<vtkm::FloatDefault, 3>;
        using VecType = typename vtkm::VecTraits<ValueType>;

        for (vtkm::IdComponent c = 0; c < 3; c++) {
            points[i * 3 + c] = VecType::GetComponent(value, c);
        }
    }

    int csindex = 0;
    auto cellSet =
        ds.GetCellSet(csindex).Cast<vtkm::cont::CellSetSingleType<>>();
    size_t nCells = cellSet.GetNumberOfCells();
    std::vector<int> cells(nCells * 3);

    for (vtkm::Id i = 0; i < nCells; ++i) {
        vtkm::cont::ArrayHandle<vtkm::Id> ids;
        vtkm::Id nids = cellSet.GetNumberOfPointsInCell(i);
        cellSet.GetIndices(i, ids);
        auto IdPortal = ids.GetPortalConstControl();

        for (vtkm::Id j = 0; j < nids; ++j) {
            cells[i * 3 + j] = IdPortal.Get(j);
        }
    }

    writer.BeginStep();

    varPoint.SetShape({nPoints, 3});
    varPoint.SetSelection({{0, 0}, {nPoints, 3}});

    writer.Put(varPoint, points.data());

    varCell.SetShape({nCells, 3});
    varCell.SetSelection({{0, 0}, {nCells, 3}});

    writer.Put(varCell, cells.data());

    writer.EndStep();
}

std::chrono::milliseconds
diff(const std::chrono::steady_clock::time_point &start,
     const std::chrono::steady_clock::time_point &end)
{
    auto diff = end - start;

    return std::chrono::duration_cast<std::chrono::milliseconds>(diff);
}

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);

    if (argc < 4) {
        std::cerr << "Too few arguments" << std::endl;
        std::cout << "Usage: isosurface input output isovalue" << std::endl;
        MPI_Abort(MPI_COMM_WORLD, -1);
    }

    const std::string input_fname(argv[1]);
    const std::string output_fname(argv[2]);
    const double isovalue = std::stod(argv[3]);

    adios2::ADIOS adios("adios2.xml", MPI_COMM_WORLD);

    adios2::IO inIO = adios.DeclareIO("SimulationOutput");
    adios2::Engine reader = inIO.Open(input_fname, adios2::Mode::Read);

    adios2::IO outIO = adios.DeclareIO("IsosurfaceOutput");
    adios2::Engine writer = outIO.Open(output_fname, adios2::Mode::Write);

    auto varPoint =
        outIO.DefineVariable<double>("point", {1, 3}, {0, 0}, {1, 3});
    auto varCell = outIO.DefineVariable<int>("cell", {1, 3}, {0, 0}, {1, 3});

    std::vector<double> u;

    auto start_total = std::chrono::steady_clock::now();

    while (true) {
        auto start_step = std::chrono::steady_clock::now();

        adios2::StepStatus status =
            reader.BeginStep(adios2::StepMode::NextAvailable);

        if (status != adios2::StepStatus::OK) {
            break;
        }

        const adios2::Variable<double> varU = inIO.InquireVariable<double>("U");
        reader.Get<double>(varU, u);
        reader.EndStep();

        auto end_read = std::chrono::steady_clock::now();

        auto ds = compute_isosurface(varU, u, isovalue);

        auto end_compute = std::chrono::steady_clock::now();

        write_adios(writer, ds, varPoint, varCell);

        auto end_step = std::chrono::steady_clock::now();

        std::cout << "Step " << reader.CurrentStep()
            << " read IO " << diff(start_step, end_read).count() << " [ms]"
            << " compute " << diff(end_read, end_compute).count() << " [ms]"
            << " write IO " << diff(end_compute, end_step).count() << " [ms]"
            << std::endl;
    }

    auto end_total = std::chrono::steady_clock::now();

    std::cout << "Total runtime: " << diff(start_total, end_total).count()
              << " [ms]" << std::endl;

    writer.Close();
    reader.Close();
}
