program reader
    use adios2
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

    ! ADIOS2 related variables
    integer*8                :: adios2obj   ! ADIOS2 object
    integer*8                :: io   ! IO group handle
    integer*8                :: fh   ! File handle
    integer*8                :: sel  ! ADIOS selection object
    integer*8                :: var_T ! variable objects
    ! Variable information
    integer                  :: vartype, nsteps, ndim
    integer*8, dimension(2)  :: dims
    ! Offsets and sizes
    integer :: gndx, gndy
    integer*8, dimension(2) :: offset=0, readsize=1

    call MPI_Init (ierr)
    call MPI_Comm_dup (MPI_COMM_WORLD, group_comm, ierr)
    call MPI_Comm_rank (MPI_COMM_WORLD, rank, ierr)
    call MPI_Comm_size (group_comm, nproc , ierr)

    write(filename,'("../heat.bp")')

    call adios2_init(adios2obj, group_comm, .true., ierr)
    call adios2_declare_io(io, adios2obj, "heat_in", ierr)
    call adios2_open(fh, io, filename, adios2_mode_read, group_comm, ierr)

    if (ierr .ne. 0) then
        print '(" Failed to open stream: ",a)', filename
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
        if (ts==0) then
            ! adios_get_scalar() gets the value from metadata in memory
            call adios2_get_sync(fh, "gndx", gndx, ierr)
            call adios2_get_sync(fh, "gndy", gndy, ierr)
            if (rank == 0) then
                print '(" Global array size: ",i0, "x", i0)', gndx, gndy
            endif

            readsize(1) = gndx 
            readsize(2) = gndy / nproc

            offset(1)   = 0
            offset(2)   = rank * readsize(2)
    
            if (rank == nproc-1) then  ! last process should read all the rest of columns
                readsize(2) = gndy - readsize(2)*(nproc-1)
            endif
          
            allocate( T(readsize(1), readsize(2)) )

            ! Create a 2D selection for the subset 
            call adios2_inquire_variable(var_T, io, 'T', ierr)
            call adios2_set_selection(var_T, 2, offset, readsize, ierr)
        endif
       
        ! Arrays are read by scheduling one or more of them
        ! and performing the reads at once
        ! In streaming mode, always step 0 is the one available for read
        call adios2_get_deferred(fh, "T", T, ierr)

        ! Read all deferred and then release resources to this step
        call adios2_end_step(fh, ierr)

        call print_array (T, offset, rank, ts)
        call MPI_Barrier (group_comm, ierr)
        ts = ts+1
    enddo

    if (ierr==adios2_step_status_end_of_stream .and. rank==0) then
        print *, " Stream has terminated. Quit reader"
    elseif (ierr==adios2_step_status_not_ready .and. rank==0) then
        print *, " Next step has not arrived for a while. Assume termination"
    endif

    call adios2_close(fh, ierr)

    ! Terminate
    deallocate(T)
    call adios2_finalize (adios2obj, ierr)
    call MPI_Finalize (ierr)
  end program reader  
