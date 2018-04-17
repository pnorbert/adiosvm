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
    integer :: gndx, gndy
    integer*8, dimension(2) :: offset=0, readsize=1




    call MPI_Init (ierr)
    call MPI_Comm_dup (MPI_COMM_WORLD, group_comm, ierr)
    call MPI_Comm_rank (MPI_COMM_WORLD, rank, ierr)
    call MPI_Comm_size (group_comm, nproc , ierr)
    call adios_read_init_method (ADIOS_READ_METHOD_BP, group_comm, "verbose=3", ierr)

    write(filename,'("../heat.bp")')

    call adios_read_open (fh, filename, ADIOS_READ_METHOD_BP, group_comm, &
                          ADIOS_LOCKMODE_CURRENT, 180.0, ierr)
    if (ierr .ne. 0) then
        print '(" Failed to open stream: ",a)', filename
        print '(" open stream ierr=: ",i0)', ierr
        call exit(1)
    endif

    ts = 0;
    do while (ierr==0)

        print '(" Process step: ",i0)', ts
        if (ts==0) then
            ! adios_get_scalar() gets the value from metadata in memory
            call adios_get_scalar(fh, "gndx", gndx, ierr)
            call adios_get_scalar(fh, "gndy", gndy, ierr)
            readsize(1) = gndx 
            readsize(2) = gndy / nproc

            offset(1)   = 0
            offset(2)   = rank * readsize(2)
    
            if (rank == nproc-1) then  ! last process should read all the rest of columns
                readsize(2) = gndy - readsize(2)*(nproc-1)
            endif
          
            allocate( T(readsize(1), readsize(2)) )

            ! Create a 2D selection for the subset
            call adios_selection_boundingbox (sel, 2, offset, readsize)
        endif
       
        ! Arrays are read by scheduling one or more of them
        ! and performing the reads at once
        ! In streaming mode, always step 0 is the one available for read
        call adios_schedule_read(fh, sel, "T", 0, 1, T, ierr)
        call adios_perform_reads (fh, ierr)

        ! Release resources to this step
        call adios_release_step(fh, ierr)

        call print_array (T, offset, rank, ts)

        ! Advance to the next available step
        call MPI_Barrier (group_comm, ierr)
        call adios_advance_step(fh, 0, 5.0, ierr)
        if (ierr==err_end_of_stream .and. rank==0) then
            print *, " Stream has terminated. Quit reader"
        elseif (ierr==err_step_notready .and. rank==0) then
            print *, " Next step has not arrived for a while. Assume termination"
        endif
        ts = ts+1
    enddo
    call adios_read_close (fh, ierr)

    ! Terminate
    deallocate(T)
    call adios_selection_delete (sel)
    call adios_read_finalize_method (ADIOS_READ_METHOD_BP, ierr)
    call MPI_Finalize (ierr)
  end program reader  
