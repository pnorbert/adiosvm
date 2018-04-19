program reader
    use adios2
    use heat_print
    implicit none
    include 'mpif.h'

    character(len=256) :: filename, errmsg
    real*8, dimension(:,:),   allocatable :: T 

    ! MPI variables
    integer :: wnproc, wrank, color
    integer :: app_comm, nproc, rank
    integer :: ierr

    integer :: ts=0   ! actual step in file that we read

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
    ! World comm spans all applications started with the same mpirun command 
    call MPI_Comm_rank (MPI_COMM_WORLD, wrank, ierr)
    call MPI_Comm_size (MPI_COMM_WORLD, wnproc , ierr)
    ! Have to split and create a 'world' communicator for heat reader only
    color = 2
    call MPI_Comm_split (MPI_COMM_WORLD, color, wrank, app_comm, ierr)
    call MPI_Comm_rank (app_comm, rank, ierr)
    call MPI_Comm_size (app_comm, nproc , ierr)

    call processArgs()

    if (rank == 0) then
        print '(" Input file: ",a)', filename
    endif

    call adios2_init_config(adios2obj, "adios2.xml", app_comm, .true., ierr)
    call adios2_declare_io(io, adios2obj, "heat", ierr)
    call adios2_open(fh, io, filename, adios2_mode_read, app_comm, ierr)

    ! We can inquire the dimensions, type and number of steps 
    ! of a variable directly from the metadata
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
    call adios2_get_deferred(fh, var_T, T, ierr)
    call adios2_close(fh, ierr)
    call print_array (T, offset, rank, ts)

    ! Terminate
    deallocate(dims)
    deallocate(T)
    call adios2_finalize (adios2obj, ierr)
    call MPI_Finalize (ierr)


contains

    !!***************************
  subroutine usage()
    print *, "Usage: heat_read  input"
    print *, "input:  name of input file"
  end subroutine usage

!!***************************
  subroutine processArgs()

#ifndef __GFORTRAN__
#ifndef __GNUC__
    interface
         integer function iargc()
         end function iargc
    end interface
#endif
#endif

    integer :: numargs

    !! process arguments
    numargs = iargc()
    !print *,"Number of arguments:",numargs
    if ( numargs < 1 ) then
        call usage()
        call exit(1)
    endif
    call getarg(1, filename)

  end subroutine processArgs

end program reader  


