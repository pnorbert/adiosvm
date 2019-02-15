#include <chrono>
#include <iostream>

#include <adios2.h>

#include <vtkCellArray.h>
#include <vtkCurvatures.h>
#include <vtkPoints.h>
#include <vtkPolyData.h>
#include <vtkSmartPointer.h>
#include <vtkXMLPolyDataWriter.h>

vtkSmartPointer<vtkPolyData> read_mesh(const std::vector<double> &bufPoints,
                                       const std::vector<int> &bufCells)
{
    int nPoints = bufPoints.size() / 3;
    int nCells = bufCells.size() / 3;

    vtkSmartPointer<vtkPoints> points = vtkSmartPointer<vtkPoints>::New();
    points->SetNumberOfPoints(nPoints);
    for (vtkIdType i = 0; i < nPoints; i++) {
        double x = bufPoints[i * 3];
        double y = bufPoints[i * 3 + 1];
        double z = bufPoints[i * 3 + 2];
        points->SetPoint(i, x, y, z);
    }

    vtkSmartPointer<vtkCellArray> polys = vtkSmartPointer<vtkCellArray>::New();
    for (vtkIdType i = 0; i < nCells; i++) {
        vtkIdType a = bufCells[i * 3];
        vtkIdType b = bufCells[i * 3 + 1];
        vtkIdType c = bufCells[i * 3 + 2];
        polys->InsertNextCell(3);
        polys->InsertCellPoint(a);
        polys->InsertCellPoint(b);
        polys->InsertCellPoint(c);
    }

    vtkSmartPointer<vtkPolyData> polyData = vtkSmartPointer<vtkPolyData>::New();
    polyData->SetPoints(points);
    polyData->SetPolys(polys);

    return polyData;
}

void compute_curvature(const vtkSmartPointer<vtkPolyData> polyData)
{
    vtkSmartPointer<vtkCurvatures> curvaturesFilter =
        vtkSmartPointer<vtkCurvatures>::New();
    curvaturesFilter->SetInputData(polyData);
    // curvaturesFilter->SetCurvatureTypeToMinimum();
    // curvaturesFilter->SetCurvatureTypeToMaximum();
    // curvaturesFilter->SetCurvatureTypeToGaussian();
    curvaturesFilter->SetCurvatureTypeToMean();
    curvaturesFilter->Update();

    vtkSmartPointer<vtkXMLPolyDataWriter> writer =
        vtkSmartPointer<vtkXMLPolyDataWriter>::New();
    writer->SetInputData(curvaturesFilter->GetOutput());
    writer->SetFileName("x.vtp");
    writer->Write();
}

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);

    if (argc < 4) {
        std::cerr << "Too few arguments" << std::endl;
        std::cout << "Usage: curvature input output step" << std::endl;
        MPI_Abort(MPI_COMM_WORLD, -1);
    }

    const std::string input_fname(argv[1]);
    const std::string output_fname(argv[2]);
    const int step = std::stoi(argv[3]);

    adios2::ADIOS adios(MPI_COMM_WORLD);

    adios2::IO inIO = adios.DeclareIO("IsosurfaceOutput");
    adios2::Engine reader = inIO.Open(input_fname, adios2::Mode::Read);

    adios2::IO outIO = adios.DeclareIO("CurvatureOutput");
    adios2::Engine writer = outIO.Open(output_fname, adios2::Mode::Write);

    std::vector<double> points;
    std::vector<int> cells;

    while (true) {
        adios2::StepStatus status =
            reader.BeginStep(adios2::StepMode::NextAvailable);

        if (status != adios2::StepStatus::OK) {
            break;
        }

        auto varPoint = inIO.InquireVariable<double>("point");
        auto varCell = inIO.InquireVariable<int>("cell");

        points.resize(varPoint.Shape()[0] * varPoint.Shape()[1]);
        cells.resize(varCell.Shape()[0] * varCell.Shape()[1]);

        reader.Get<double>(varPoint, points.data());
        reader.Get<int>(varCell, cells.data());

        reader.EndStep();

        std::cout << "Step " << reader.CurrentStep() << " "
                  << varPoint.Shape()[0] << " points, " << varCell.Shape()[0]
                  << " cells" << std::endl;

        if (reader.CurrentStep() == step) {
            vtkSmartPointer<vtkPolyData> polyData = read_mesh(points, cells);
            auto start = std::chrono::steady_clock::now();
            compute_curvature(polyData);
            auto end = std::chrono::steady_clock::now();
            auto diff = end - start;
            auto duration =
                std::chrono::duration_cast<std::chrono::milliseconds>(diff);

            std::cout << "Computed curvature in " << duration.count() << " [ms]"
                      << std::endl;
            break;
        }
    }

    writer.Close();
    reader.Close();
}
