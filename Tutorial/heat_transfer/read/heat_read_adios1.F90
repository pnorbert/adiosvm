program reader
    use adios_read_mod
    use heat_print
    implicit none
    include 'mpif.h'

    character(len=256) :: filename, errmsg
    integer :: timesteps      ! number of times to read data    
    integer :: nproc          ! number of processors
    
    real*8, dimension(:,:),   allocatable :: T, dT 

    ! MPI variables
    integer :: group_comm
    integer :: rank
    integer :: ierr

    integer :: ts=0   ! actual timestep
    integer :: i,j

    ! ADIOS related variables
    integer*8                :: fh   ! File handle
    integer*8                :: sel  ! ADIOS selection object
    ! Variable information
    integer                  :: vartype, nsteps, ndim
    integer*8, dimension(2)  :: dims
    ! Offsets and sizes
    integer                  :: gndx, gndy
    integer*8, dimension(2)  :: offset=0, readsize=1



    call MPI_Init (ierr)
    call MPI_Comm_dup (MPI_COMM_WORLD, group_comm, ierr)
    call MPI_Comm_rank (MPI_COMM_WORLD, rank, ierr)
    call MPI_Comm_size (group_comm, nproc , ierr)
    call adios_read_init_method (ADIOS_READ_METHOD_BP, group_comm, "verbose=3", ierr)

    write(filename,'("../heat.bp")')

    call adios_read_open_file (fh, filename, ADIOS_READ_METHOD_BP, group_comm, ierr)

    ! adios_get_scalar() gets the value from metadata in memory
    call adios_get_scalar(fh, "gndx", gndx, ierr)
    call adios_get_scalar(fh, "gndy", gndy, ierr)
    readsize(1) = gndx 
    readsize(2) = gndy / nproc

    ! We can also inquire the dimensions, type and number of steps 
    ! of a variable directly
    call adios_inq_var (fh, "T", vartype, nsteps, ndim, dims, ierr)
    ts = nsteps-1 ! Let's read the last timestep

    offset(1)   = 0
    offset(2)   = rank * readsize(2)

    if (rank == nproc-1) then  ! last process should read all the rest of columns
        readsize(2) = gndy - readsize(2)*(nproc-1)
    endif
          
    allocate( T(readsize(1), readsize(2)) )

    ! Create a 2D selection for the subset
    call adios_selection_boundingbox (sel, 2, offset, readsize)

       
    ! Arrays are read by scheduling one or more of them
    ! and performing the reads at once
    call adios_schedule_read(fh, sel, "T", ts, 1, T, ierr)
    call adios_perform_reads (fh, ierr)

    call print_array (T, offset, rank, ts)

    call adios_read_close (fh, ierr)
    ! Terminate
    call adios_selection_delete (sel)
    call adios_read_finalize_method (ADIOS_READ_METHOD_BP, ierr)
    call MPI_Finalize (ierr)
  end program reader  
