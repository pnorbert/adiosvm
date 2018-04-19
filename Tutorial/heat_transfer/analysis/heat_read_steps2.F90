program reader
    use adios2
    use heat_print
    implicit none
    include 'mpif.h'

    character(len=256) :: streamname, errmsg
    real*8, dimension(:,:),   allocatable :: T, dT 

    ! MPI variables
    integer :: wnproc, wrank, color
    integer :: app_comm, nproc, rank
    integer :: ierr

    integer :: ts=0   ! actual step in stream
    integer :: i,j

    ! ADIOS2 related variables
    integer*8                :: adios2obj   ! ADIOS2 object
    integer*8                :: io   ! IO group handle
    integer*8                :: fh   ! File handle
    integer*8                :: sel  ! ADIOS selection object
    integer*8                :: var_T ! variable objects
    ! Variable information
    integer                  :: vartype, nsteps, ndim
    integer*8, dimension(:), allocatable  :: dims
    ! Offsets and sizes
    integer*8, dimension(2) :: offset=0, readsize=1

    call MPI_Init (ierr)
    ! World comm spans all applications started with the same mpirun command 
    call MPI_Comm_rank (MPI_COMM_WORLD, wrank, ierr)
    call MPI_Comm_size (MPI_COMM_WORLD, wnproc , ierr)
    ! Have to split and create a 'world' communicator for heat reader only
    color = 2
    call MPI_Barrier(MPI_COMM_WORLD, ierr);
    call MPI_Comm_split (MPI_COMM_WORLD, color, wrank, app_comm, ierr)
    call MPI_Comm_rank (app_comm, rank, ierr)
    call MPI_Comm_size (app_comm, nproc , ierr)

    call processArgs()

    if (rank == 0) then
        print '(" Input file: ",a)', streamname
    endif

    call adios2_init_config(adios2obj, "adios2.xml", app_comm, .true., ierr)
    call adios2_declare_io(io, adios2obj, "heat", ierr)
    call adios2_open(fh, io, streamname, adios2_mode_read, app_comm, ierr)

    if (ierr .ne. 0) then
        print '(" Failed to open stream: ",a)', streamname
        print '(" open stream ierr=: ",i0)', ierr
        call exit(1)
    endif

    ts = 0;
    do 
        call adios2_begin_step(fh, adios2_step_mode_next_available, -1.0, ierr)
        if (ierr /= adios2_step_status_ok) then
            exit
        endif

        print '(" Process step: ",i0)', ts
        call adios2_inquire_variable(var_T, io, "T", ierr)

        if (ts==0) then
            ! We can inquire the dimensions, type and number of steps 
            ! of a variable directly from the metadata
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

        endif
       
        ! Create a 2D selection for the subset 
        call adios2_set_selection(var_T, 2, offset, readsize, ierr)

        ! Arrays are read by scheduling one or more of them
        ! and performing the reads at once
        ! In streaming mode, always step 0 is the one available for read
        call adios2_get_deferred(fh, "T", T, ierr)

        ! Read all deferred and then release resources to this step
        call adios2_end_step(fh, ierr)

        call print_array (T, offset, rank, ts)
        call MPI_Barrier (app_comm, ierr)
        ts = ts+1
    enddo

    if (ierr==adios2_step_status_end_of_stream .and. rank==0) then
        print *, " Stream has terminated. Quit reader"
    elseif (ierr==adios2_step_status_not_ready .and. rank==0) then
        print *, " Next step has not arrived for a while. Assume termination"
    endif

    call adios2_close(fh, ierr)

    ! Terminate
    deallocate(dims)
    deallocate(T)
    call adios2_finalize (adios2obj, ierr)
    call MPI_Finalize (ierr)


contains

    !!***************************
  subroutine usage()
    print *, "Usage: heat_read_steps2  input"
    print *, "input:  name of input file/stream"
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
    call getarg(1, streamname)

  end subroutine processArgs



  end program reader  
