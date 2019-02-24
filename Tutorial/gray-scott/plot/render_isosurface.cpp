#include <chrono>
#include <iostream>

#include <adios2.h>

#include <vtkCellArray.h>
#include <vtkPoints.h>
#include <vtkPolyData.h>
#include <vtkSmartPointer.h>

#include <vtkActor.h>
#include <vtkCallbackCommand.h>
#include <vtkInteractorStyleSwitch.h>
#include <vtkPolyDataMapper.h>
#include <vtkRenderView.h>
#include <vtkRenderWindow.h>
#include <vtkRenderWindowInteractor.h>
#include <vtkRenderer.h>

typedef struct {
    vtkRenderView *renderView;
    vtkPolyDataMapper *mapper;
    adios2::IO *inIO;
    adios2::Engine *reader;
} Context;

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

void func(vtkObject *object, unsigned long eid, void *clientdata,
          void *calldata)
{
    Context *context = static_cast<Context *>(clientdata);

    std::vector<double> points;
    std::vector<int> cells;
    int step;

    adios2::StepStatus status =
        context->reader->BeginStep(adios2::StepMode::NextAvailable);

    if (status != adios2::StepStatus::OK) {
        return;
    }

    auto varPoint = context->inIO->InquireVariable<double>("point");
    auto varCell = context->inIO->InquireVariable<int>("cell");
    auto varStep = context->inIO->InquireVariable<int>("step");

    varPoint.SetSelection({{0, 0}, {varPoint.Shape()[0], varPoint.Shape()[1]}});
    varCell.SetSelection({{0, 0}, {varCell.Shape()[0], varCell.Shape()[1]}});

    context->reader->Get<double>(varPoint, points);
    context->reader->Get<int>(varCell, cells);
    context->reader->Get<int>(varStep, &step);

    context->reader->EndStep();

    std::cout << "Step " << step << " " << varCell.Shape()[0] << " cells "
              << varPoint.Shape()[0] << " points" << std::endl;

    vtkSmartPointer<vtkPolyData> polyData = read_mesh(points, cells);

    context->mapper->SetInputData(polyData);
    context->renderView->ResetCamera();
    context->renderView->Render();
}

int main(int argc, char *argv[])
{
    MPI_Init(&argc, &argv);

    if (argc < 2) {
        std::cerr << "Too few arguments" << std::endl;
        std::cout << "Usage: render_isosurface input" << std::endl;
        MPI_Abort(MPI_COMM_WORLD, -1);
    }

    const std::string input_fname(argv[1]);

    adios2::ADIOS adios("adios2.xml", MPI_COMM_WORLD, adios2::DebugON);

    adios2::IO inIO = adios.DeclareIO("IsosurfaceOutput");
    adios2::Engine reader = inIO.Open(input_fname, adios2::Mode::Read);

    auto mapper = vtkSmartPointer<vtkPolyDataMapper>::New();

    auto actor = vtkSmartPointer<vtkActor>::New();
    actor->SetMapper(mapper);

    auto renderView = vtkSmartPointer<vtkRenderView>::New();

    renderView->GetRenderer()->AddActor(actor);
    renderView->Update();

    auto style = vtkSmartPointer<vtkInteractorStyleSwitch>::New();
    style->SetCurrentStyleToTrackballCamera();

    auto interactor = renderView->GetInteractor();

    interactor->Initialize();

    interactor->SetInteractorStyle(style);

    interactor->CreateRepeatingTimer(100);

    Context context = {
        .renderView = renderView,
        .mapper = mapper,
        .inIO = &inIO,
        .reader = &reader,
    };

    auto timerCallback = vtkSmartPointer<vtkCallbackCommand>::New();
    timerCallback->SetCallback(func);
    timerCallback->SetClientData(&context);

    interactor->AddObserver(vtkCommand::TimerEvent, timerCallback);

    renderView->Render();
    renderView->GetRenderWindow()->SetSize(500, 500);

    interactor->Start();

    reader.Close();
}
