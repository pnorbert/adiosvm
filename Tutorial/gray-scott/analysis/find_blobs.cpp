/*
 * Analysis code for the Gray-Scott simulation.
 * Reads iso-surface mesh data and detects connected components.
 * Counts the total number of connected components and measures the surface
 * area of each component.
 *
 * Keichi Takahashi <takahashi.keichi@ais.cmc.osaka-u.ac.jp>
 *
 */

#include <chrono>
#include <iostream>

#include <adios2.h>

#include <vtkCellArray.h>
#include <vtkConnectivityFilter.h>
#include <vtkDataSetSurfaceFilter.h>
#include <vtkMassProperties.h>
#include <vtkPoints.h>
#include <vtkPolyData.h>
#include <vtkSmartPointer.h>
#include <vtkThreshold.h>
#include <vtkUnstructuredGrid.h>

vtkSmartPointer<vtkPolyData> read_mesh(const std::vector<double> &bufPoints,
                                       const std::vector<int> &bufCells)
{
    int nPoints = bufPoints.size() / 3;
    int nCells = bufCells.size() / 3;

    auto points = vtkSmartPointer<vtkPoints>::New();
    points->SetNumberOfPoints(nPoints);
    for (vtkIdType i = 0; i < nPoints; i++) {
        double x = bufPoints[i * 3 + 0];
        double y = bufPoints[i * 3 + 1];
        double z = bufPoints[i * 3 + 2];

        points->SetPoint(i, x, y, z);
    }

    auto polys = vtkSmartPointer<vtkCellArray>::New();
    for (vtkIdType i = 0; i < nCells; i++) {
        vtkIdType a = bufCells[i * 3 + 0];
        vtkIdType b = bufCells[i * 3 + 1];
        vtkIdType c = bufCells[i * 3 + 2];

        polys->InsertNextCell(3);
        polys->InsertCellPoint(a);
        polys->InsertCellPoint(b);
        polys->InsertCellPoint(c);
    }

    auto polyData = vtkSmartPointer<vtkPolyData>::New();
    polyData->SetPoints(points);
    polyData->SetPolys(polys);

    return polyData;
}

void find_blobs(const vtkSmartPointer<vtkPolyData> polyData)
{
    auto connectivityFilter = vtkSmartPointer<vtkConnectivityFilter>::New();
    connectivityFilter->SetInputData(polyData);
    connectivityFilter->SetExtractionModeToAllRegions();
    connectivityFilter->ColorRegionsOn();
    connectivityFilter->Update();

    int nBlobs = connectivityFilter->GetNumberOfExtractedRegions();

    std::cout << "Extracted " << nBlobs << " blobs" << std::endl;

    auto threshold = vtkSmartPointer<vtkThreshold>::New();
    auto massProperties = vtkSmartPointer<vtkMassProperties>::New();
    auto surfaceFilter = vtkSmartPointer<vtkDataSetSurfaceFilter>::New();

    threshold->SetInputConnection(connectivityFilter->GetOutputPort());
    surfaceFilter->SetInputConnection(threshold->GetOutputPort());
    massProperties->SetInputConnection(surfaceFilter->GetOutputPort());

    for (int i = 0; i < nBlobs; i++) {
        threshold->ThresholdBetween(i, i);

        std::cout << "surface area of blob " << i << " is "
                  << massProperties->GetSurfaceArea() << std::endl;
    }
}

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);

    if (argc < 2) {
        std::cerr << "Too few arguments" << std::endl;
        std::cout << "Usage: find_blobs input" << std::endl;
        MPI_Abort(MPI_COMM_WORLD, -1);
    }

    const std::string input_fname(argv[1]);

    adios2::ADIOS adios("adios2.xml", MPI_COMM_WORLD, adios2::DebugON);

    adios2::IO inIO = adios.DeclareIO("IsosurfaceOutput");
    adios2::Engine reader = inIO.Open(input_fname, adios2::Mode::Read);

    std::vector<double> points;
    std::vector<int> cells;
    int step;

    while (true) {
        adios2::StepStatus status =
            reader.BeginStep(adios2::StepMode::NextAvailable);

        if (status != adios2::StepStatus::OK) {
            break;
        }

        auto varPoint = inIO.InquireVariable<double>("point");
        auto varCell = inIO.InquireVariable<int>("cell");
        auto varStep = inIO.InquireVariable<int>("step");

        varPoint.SetSelection(
            {{0, 0}, {varPoint.Shape()[0], varPoint.Shape()[1]}});
        varCell.SetSelection(
            {{0, 0}, {varCell.Shape()[0], varCell.Shape()[1]}});

        reader.Get<double>(varPoint, points);
        reader.Get<int>(varCell, cells);
        reader.Get<int>(varStep, &step);

        reader.EndStep();

        std::cout << "Step " << step << " " << varCell.Shape()[0] << " cells "
                  << varPoint.Shape()[0] << " points" << std::endl;

        vtkSmartPointer<vtkPolyData> polyData = read_mesh(points, cells);
        auto start = std::chrono::steady_clock::now();
        find_blobs(polyData);
        auto end = std::chrono::steady_clock::now();
        auto diff = end - start;
        auto duration =
            std::chrono::duration_cast<std::chrono::milliseconds>(diff);

        std::cout << "Found blobs in " << duration.count() << " [ms]"
                  << std::endl;
    }

    reader.Close();
}
