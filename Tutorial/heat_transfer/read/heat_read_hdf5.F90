program reader
   ! use adios_read_mod
    use HDF5
    use heat_print
    implicit none
    include 'mpif.h'

    character(len=256) :: filename, errmsg
    integer :: timesteps      ! number of times to read data    
    integer :: nproc          ! number of processors
    
    real*8, dimension(:,:,:),   allocatable :: T, dT 

    ! Offsets and sizes
    integer :: gndx, gndy
    integer*8, dimension(3) :: dims
    integer*8, dimension(3) :: maxdims
    integer*8, dimension(3) :: offset=0, readsize=1
    integer*8           :: sel  ! ADIOS selection object

    ! MPI variables
    integer :: group_comm
    integer :: rank
    integer :: ierr

    integer :: ts=0   ! actual timestep
    integer :: i,j

    integer :: ntsteps
    
    ! This example can read from 1-260 readers
    integer             :: gcnt, vcnt, acnt
    integer*8           :: fh, gh, read_bytes

    INTEGER(HID_T) :: file_id       ! File identifier
    INTEGER(HID_T) :: dset_id       ! Dataset identifier
    INTEGER(HID_T) :: dataspace     ! Dataspace identifier
    INTEGER(HID_T) :: memspace      ! Memory space identifier


    call MPI_Init (ierr)
    call MPI_Comm_dup (MPI_COMM_WORLD, group_comm, ierr)
    call MPI_Comm_rank (MPI_COMM_WORLD, rank, ierr)
    call MPI_Comm_size (group_comm, nproc , ierr)
    call h5open_f(ierr)

    write(filename,'("../heat.h5")')

    ! Open the file
    call h5fopen_f (filename, H5F_ACC_RDWR_F, file_id, ierr)

    ! Open the T dataset
    call h5dopen_f(file_id, "T", dset_id, ierr)

    ! Get the dimensions of T
    call h5dget_space_f(dset_id, dataspace, ierr)
    call h5sget_simple_extent_dims_f(dataspace, dims, maxdims, ierr)

    gndx = dims(1)
    gndy = dims(2)

    readsize(1) = gndx 
    readsize(2) = gndy / nproc
    readsize(3) = 1 ! Read one timestep

    if (rank == nproc-1) then  ! last process should read all the rest of columns
        readsize(2) = gndy - readsize(2)*(nproc-1)
        !readsize(2) = 3
    endif
          
    offset(1)   = 0
    offset(2)   = rank * (gndy / nproc)
    offset(3)   = dims(3)-1 ! Read the latest timestep

    ! Create a memory space for the partial read
    call h5screate_simple_f (3, readsize, memspace, ierr)

    allocate( T(readsize(1), readsize(2), readsize(3)) )

    call h5sselect_hyperslab_f(dataspace, H5S_SELECT_SET_F, offset, &
                               readsize, ierr)
       
    call h5dread_f(dset_id, H5T_NATIVE_DOUBLE, T, readsize, ierr, &
                   memspace, dataspace, H5P_DEFAULT_F)


    ts   = dims(3)-1 ! Read the latest timestep
    call print_array (T(:,:,1), offset, rank, ts)

    call h5dclose_f(dset_id, ierr)

    call h5fclose_f(file_id, ierr)

    call h5close_f(ierr)

    ! Terminate
    !call adios_selection_delete (sel)
    !call adios_read_finalize_method (ADIOS_READ_METHOD_BP, ierr)
    call MPI_Finalize (ierr)
  end program reader  
