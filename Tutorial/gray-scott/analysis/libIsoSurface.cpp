#include "libIsoSurface.h"

#include <iomanip>
#include <iostream>
#include <sstream>

#include <vtkImageData.h>
#include <vtkImageImport.h>
#include <vtkMarchingCubes.h>
#include <vtkSmartPointer.h>
#include <vtkMultiBlockDataGroupFilter.h>
#include <vtkMPI.h>
#include <vtkMPICommunicator.h>
#include <vtkMPIController.h>
#include <vtkXMLPMultiBlockDataWriter.h>

// Helper functions
namespace
{
    // Zero-copy inline interface
    void Adios2Vtk(
        const adios2::Variable<double> &var,
        adios2::Variable<double>::Info &block,
        vtkSmartPointer<vtkImageImport> image)
    {
        image->SetWholeExtent(
            0, var.Count()[2] - 1, 0, var.Count()[1] - 1, 0,
            var.Count()[0] - 1);
        image->SetDataSpacing(1, 1, 1);
        image->SetDataExtent(
            block.Start[2], block.Start[2] + block.Count[2] - 1,
            block.Start[1], block.Start[1] + block.Count[1] - 1,
            block.Start[0], block.Start[0] + block.Count[0] - 1);
        image->SetDataScalarTypeToDouble();
        image->SetNumberOfScalarComponents(1);
        image->Modified();
    }

    // Copied image data
    void Adios2Vtk(
        const adios2::Variable<double> &var,
        adios2::Variable<double>::Info &block,
        vtkSmartPointer<vtkImageData> image)
    {
        image->SetOrigin(0, 0, 0);
        image->SetSpacing(1, 1, 1);
        image->SetExtent(
            block.Start[2], block.Start[2] + block.Count[2] - 1,
            block.Start[1], block.Start[1] + block.Count[1] - 1,
            block.Start[0], block.Start[0] + block.Count[0] - 1);
        image->AllocateScalars(VTK_DOUBLE, 1);
        image->Modified();
    }
}

struct IsoSurface::IsoSurfaceImpl
{
    adios2::IO &IO;
    adios2::Engine Reader;
    struct
    {
        vtkSmartPointer<vtkMPICommunicator> Comm;
        vtkSmartPointer<vtkMPIController> Controller;
        std::vector<vtkSmartPointer<vtkImageImport>> InputImageImports;
        std::vector<vtkSmartPointer<vtkImageData>> InputImages;
        vtkSmartPointer<vtkMultiBlockDataGroupFilter> Group;
        vtkSmartPointer<vtkMarchingCubes> Contour;
        vtkSmartPointer<vtkXMLPMultiBlockDataWriter> Writer;
    } Pipeline;
    
    size_t BlockIdMin, BlockIdMax;
    int MpiRank, MpiSize;
    std::string OutFName;
    bool IsInline;

    IsoSurfaceImpl(MPI_Comm comm, adios2::IO &io, const std::string &in,
                   const std::string &out, const std::vector<double> &isoValues,
                   bool isInline)
    : IO(io), Reader(io.Open(in, adios2::Mode::Read)), OutFName(out),
      IsInline(isInline)
    {
        MPI_Comm_rank(comm, &this->MpiRank);
        MPI_Comm_size(comm, &this->MpiSize);

        // Setup MPI fpr VTK
        //
        vtkMPICommunicatorOpaqueComm opaqueComm(&comm);
        this->Pipeline.Comm = vtkMPICommunicator::New();
        this->Pipeline.Comm->InitializeExternal(&opaqueComm);

        this->Pipeline.Controller = vtkMPIController::New();
        this->Pipeline.Controller->SetCommunicator(this->Pipeline.Comm.Get());
        vtkMultiProcessController::SetGlobalController(
             this->Pipeline.Controller.Get());

        // Setup the pipeline stages (except for input, that's later)
        //
        this->Pipeline.Group = vtkMultiBlockDataGroupFilter::New();

        this->Pipeline.Contour = vtkMarchingCubes::New();
        this->Pipeline.Contour->AddInputConnection(
            this->Pipeline.Group->GetOutputPort());
        this->Pipeline.Contour->SetNumberOfContours(isoValues.size());
        for(size_t i = 0; i < isoValues.size(); ++i)
        {
            this->Pipeline.Contour->SetValue(i, isoValues[i]);
        }

        this->Pipeline.Writer = vtkXMLPMultiBlockDataWriter::New();
        this->Pipeline.Writer->AddInputConnection(
            this->Pipeline.Contour->GetOutputPort());
    }

    ~IsoSurfaceImpl() = default;

    void UpdateBlockRange(size_t nBlocks)
    {
        size_t localBlockCount;
        if(this->IsInline)
        {
            if(nBlocks != 1)
            {
                throw std::logic_error(
                    "Inline engine requires exactly 1 block per rank");
            }
            localBlockCount = 1;
            this->BlockIdMin = 0;
        }
        else
        {
            if(nBlocks < this->MpiSize)
            {
                throw std::logic_error(
                    "Number of blocks must be >= number of MPI ranks");
            }
            localBlockCount = nBlocks / this->MpiSize;
            size_t leftOver = nBlocks % this->MpiSize;

            if(this->MpiRank < leftOver)
            {
                localBlockCount++;
                this->BlockIdMin = this->MpiRank * localBlockCount;
            }
            else
            {
                this->BlockIdMin = leftOver * (localBlockCount + 1) +
                    (this->MpiRank - leftOver) * localBlockCount;
            }
        }
        this->BlockIdMax = this->BlockIdMin + localBlockCount - 1;

        // The inline engine uses the vtkImageImport filter for a zero-copy
        // interface while all other engines read into a vtkImageData
        if(this->IsInline)
        {
            // Skip pipeline input adjustment if it's already setup
            if(localBlockCount == this->Pipeline.InputImageImports.size())
            {
                return;
            }

            // Setup the pipeline plumbing
            this->Pipeline.Group->RemoveAllInputConnections(0);
            this->Pipeline.InputImageImports.clear();
            this->Pipeline.InputImageImports.resize(localBlockCount);
            for(auto &input : this->Pipeline.InputImageImports)
            {
                input.TakeReference(vtkImageImport::New());
                this->Pipeline.Group->AddInputConnection(
                    input->GetOutputPort());
            }
        }
        else
        {
            // Skip pipeline input adjustment if it's already setup
            if(localBlockCount == this->Pipeline.InputImages.size())
            {
                return;
            }

            // Setup the pipeline plumbing
            this->Pipeline.Group->RemoveAllInputConnections(0);
            this->Pipeline.InputImages.clear();
            this->Pipeline.InputImages.resize(localBlockCount);
            for(auto &input : this->Pipeline.InputImages)
            {
                input.TakeReference(vtkImageData::New());
                this->Pipeline.Group->AddInputData(input);
            }
        }
    }
};

IsoSurface::IsoSurface(MPI_Comm comm, adios2::IO &io, const std::string &in,
                       const std::string &out,
                       const std::vector<double> &isoValues,
                       bool isInline)
    : Impl(new IsoSurfaceImpl(comm, io, in, out, isoValues, isInline))
{
}

IsoSurface::~IsoSurface() = default;

bool IsoSurface::Step()
{
    // 1. Start the step
    adios2::StepStatus status = this->Impl->Reader.BeginStep();
    if(status != adios2::StepStatus::OK)
    {
        return false;
    }
    if(this->Impl->MpiRank == 0)
    {
        std::cout << "IsoContour step " << this->Impl->Reader.CurrentStep()
                  << std::endl;
    }

    // 2. Locate the variable
    adios2::Variable<double> varU = this->Impl->IO.InquireVariable<double>("U");
    if(!varU) // Ignore steps where the variable doesn't exist
    {
        return true;
    }

    // 3. Get the breakdown of block information
    auto blocksU = this->Impl->Reader.BlocksInfo(varU,
        this->Impl->Reader.CurrentStep());
    if(blocksU.size() == 0) // Ignore steps where the variable is empty
    {
        return true;
    }

    // 4. Determine which blocks need to be read by the current process
    this->Impl->UpdateBlockRange(blocksU.size());

    // 5. Loop through all available blocks and populate their block infos
    for(auto &infoU : blocksU)
    {
      // Skip the blocks we're not working on
      if(infoU.BlockID < this->Impl->BlockIdMin ||
         infoU.BlockID > this->Impl->BlockIdMax)
      {
          continue;
      }

      varU.SetBlockSelection(infoU.BlockID);

      if(this->Impl->IsInline)
      {
          // 7. Establish the zero-copy interface into VTK
          vtkSmartPointer<vtkImageImport> image =
              this->Impl->Pipeline.InputImageImports[
                  infoU.BlockID-this->Impl->BlockIdMin];
          Adios2Vtk(varU, infoU, image);
          this->Impl->Reader.Get(varU, infoU);
          image->SetImportVoidPointer(const_cast<double*>(infoU.Data()));
      }
      else
      {
          // 7. Read into vtkImageData
          vtkSmartPointer<vtkImageData> image =
              this->Impl->Pipeline.InputImages[
                  infoU.BlockID-this->Impl->BlockIdMin];
          Adios2Vtk(varU, infoU, image);
          this->Impl->Reader.Get(varU,
              reinterpret_cast<double*>(image->GetScalarPointer()));
      }
    }
    this->Impl->Reader.PerformGets();


    // 8. Update the output filename
    std::ostringstream ss;
    ss << this->Impl->OutFName << "-"
       << std::setfill('0') << std::setw(5) << this->Impl->Reader.CurrentStep()
       << ".vtm";
    this->Impl->Pipeline.Writer->SetFileName(ss.str().c_str());

    // 9. Trigger the writer which will in turn invoke the entire pipeline
    this->Impl->Pipeline.Writer->Write();

    // 10. Release the ADIOS step
    this->Impl->Reader.EndStep();

    return true;
}
