#include <chrono>
#include <iostream>

#include <adios2.h>

#include <vtkImageData.h>
#include <vtkImageImport.h>
#include <vtkMarchingCubes.h>
#include <vtkPolyData.h>
#include <vtkSmartPointer.h>
#include <vtkXMLPolyDataWriter.h>

vtkSmartPointer<vtkPolyData>
compute_isosurface(const adios2::Variable<double> &var,
                   const std::vector<double> &buf, double isovalue)
{
    vtkSmartPointer<vtkImageImport> imageImport =
        vtkSmartPointer<vtkImageImport>::New();
    imageImport->SetDataSpacing(1, 1, 1);
    imageImport->SetDataOrigin(var.Start()[2], var.Start()[1], var.Start()[0]);
    imageImport->SetWholeExtent(0, var.Count()[2] - 1, 0, var.Count()[1] - 1, 0,
                                var.Count()[0]);
    imageImport->SetDataExtentToWholeExtent();
    imageImport->SetDataScalarTypeToDouble();
    imageImport->SetNumberOfScalarComponents(1);
    imageImport->SetImportVoidPointer(const_cast<double *>(buf.data()));
    imageImport->Update();

    vtkSmartPointer<vtkMarchingCubes> marchingCubes =
        vtkSmartPointer<vtkMarchingCubes>::New();
    marchingCubes->SetInputData(imageImport->GetOutput());
    marchingCubes->ComputeNormalsOn();
    marchingCubes->SetValue(0, isovalue);
    marchingCubes->Update();

    return marchingCubes->GetOutput();
}

void write_vtk(const std::string &fname,
               const vtkSmartPointer<vtkPolyData> polyData)
{
    vtkSmartPointer<vtkXMLPolyDataWriter> writer =
        vtkSmartPointer<vtkXMLPolyDataWriter>::New();
    writer->SetFileName(fname.c_str());
    writer->SetInputData(polyData);
    writer->Write();
}

void write_adios(adios2::Engine &writer,
                 const vtkSmartPointer<vtkPolyData> polyData,
                 adios2::Variable<double> &varPoint,
                 adios2::Variable<int> &varCell)
{
    size_t nCells = polyData->GetNumberOfPolys();
    size_t nPoints = polyData->GetNumberOfPoints();
    size_t iCells = 0;

    std::vector<double> points(nPoints * 3);
    std::vector<int> cells(nCells * 3);

    double coords[3];

    vtkSmartPointer<vtkCellArray> cellArray = polyData->GetPolys();

    cellArray->InitTraversal();

    for (int i = 0; i < polyData->GetNumberOfPolys(); i++)
    {
        vtkSmartPointer<vtkIdList> idList = vtkSmartPointer<vtkIdList>::New();

        cellArray->GetNextCell(idList);

        for (int j = 0; j < idList->GetNumberOfIds(); j++) {
            auto id = idList->GetId(j);

            cells[iCells++] = id;

            polyData->GetPoint(id, coords);

            points[id * 3 + 0] = coords[0];
            points[id * 3 + 1] = coords[1];
            points[id * 3 + 2] = coords[2];
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

        auto polyData = compute_isosurface(varU, u, isovalue);

        auto end_compute = std::chrono::steady_clock::now();

        write_adios(writer, polyData, varPoint, varCell);

        auto end_step = std::chrono::steady_clock::now();

        std::cout << "Step " << reader.CurrentStep() << " read IO "
                  << diff(start_step, end_read).count() << " [ms]"
                  << " compute " << diff(end_read, end_compute).count()
                  << " [ms]"
                  << " write IO " << diff(end_compute, end_step).count()
                  << " [ms]" << std::endl;
    }

    auto end_total = std::chrono::steady_clock::now();

    std::cout << "Total runtime: " << diff(start_total, end_total).count()
              << " [ms]" << std::endl;

    writer.Close();
    reader.Close();
}
