program reader
    use adios2
    use heat_print
    implicit none
    include 'mpif.h'

    character(len=256) :: filename, errmsg
    real*8, dimension(:,:),   allocatable :: T 

    ! MPI variables
    integer :: group_comm, nproc
    integer :: rank
    integer :: ierr

    integer :: ts=0   ! actual timestep

    ! ADIOS related variables
    integer*8                :: adios2obj   ! ADIOS2 object
    integer*8                :: io   ! IO group handle
    integer*8                :: fh   ! File handle
    integer*8                :: sel  ! ADIOS selection object
    integer*8                :: var_T ! variable objects
    ! Variable information
    integer                  :: ndim
    integer*8, dimension(:), allocatable  :: dims
    integer*8                :: steps_start, steps_count
    ! Offsets and sizes
    integer*8, dimension(2)  :: offset=0, readsize=1

    call MPI_Init (ierr)
    call MPI_Comm_dup (MPI_COMM_WORLD, group_comm, ierr)
    call MPI_Comm_rank (MPI_COMM_WORLD, rank, ierr)
    call MPI_Comm_size (group_comm, nproc , ierr)

    write(filename,'("../heat.bp")')

    call adios2_init(adios2obj, group_comm, .true., ierr)
    call adios2_declare_io(io, adios2obj, "heat_in", ierr)
    call adios2_open(fh, io, filename, adios2_mode_read, group_comm, ierr)

    ! This is how to read in scalars (from metadata directly)
    !call adios2_get_sync(fh, "gndx", gndx, ierr)
    !call adios2_get_sync(fh, "gndy", gndy, ierr)

    ! We can inquire the dimensions, type and number of steps 
    ! of a variable directly
    call adios2_inquire_variable(var_T, io, "T", ierr)
    call adios2_variable_shape(var_T, ndim, dims, ierr)
    if (rank == 0) then
        print '(" Global array size: ",i0, "x", i0)', dims(1), dims(2)
    endif
    
    readsize(1) = dims(1) 
    readsize(2) = dims(2) / nproc

    offset(1)   = 0
    offset(2)   = rank * readsize(2)

    if (rank == nproc-1) then  ! last process should read all the rest of columns
        readsize(2) = dims(2) - readsize(2)*(nproc-1)
    endif
          
    allocate( T(readsize(1), readsize(2)) )

    !TODO:  Get the number of available steps
    call adios2_variable_available_steps_start(var_T, steps_start, ierr)
    call adios2_variable_available_steps_count(var_T, steps_count, ierr)
    ts = steps_start+steps_count-1 ! Let's read the last timestep
    if (rank == 0) then
        print '(" First available step = ", i0)', steps_start
        print '(" Available steps      = ", i0)', steps_count
        print '(" Read step            = ", i0)', ts
    endif
    call adios2_set_step_selection(var_T, ts*1_8, 1_8, ierr)
    call adios2_set_selection(var_T, 2, offset, readsize, ierr)
    call adios2_get_sync(fh, var_T, T, ierr)
    call adios2_close(fh, ierr)
    call print_array (T, offset, rank, ts)

    ! Terminate
    deallocate(dims)
    deallocate(T)
    call adios2_finalize (adios2obj, ierr)
    call MPI_Finalize (ierr)
  end program reader  
