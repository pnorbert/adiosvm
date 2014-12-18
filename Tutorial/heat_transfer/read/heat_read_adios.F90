program reader
    use adios_read_mod
    use heat_print
    implicit none
    include 'mpif.h'

    character(len=256) :: filename, errmsg
    integer :: timesteps      ! number of times to read data    
    integer :: nproc          ! number of processors
    
    real*8, dimension(:,:),   allocatable :: T, dT 

    ! Offsets and sizes
    integer :: gndx, gndy
    integer*8, dimension(2) :: offset=0, readsize=1
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
    call adios_schedule_read(fh, sel, "T", 3, 1, T, ierr)
    call adios_perform_reads (fh, ierr)

    call print_array (T, offset, rank, 3)
    !write (100+rank, '("rank=",i0," size=",i0,"x",i0," offsets=",i0,":",i0," steps=",i0)') &
    !    rank, readsize(1), readsize(2), offset(1), offset(2), ts
    !write (100+rank, '(" time   row   columns ",i0,"...",i0)'), offset(2), offset(2)+readsize(2)-1  
    !write (100+rank, '("        ",$)') 
    !do j=1,readsize(2)
    !    write (100+rank, '(i9,$)'), offset(2)+j-1
    !enddo
    !write (100+rank, '(" ")')
    !write (100+rank, '("--------------------------------------------------------------")') 
    !do i=1,readsize(1)
    !    write (100+rank, '(2i5,$)') ts,offset(1)+i-1
    !    do j=1,readsize(2)
    !        write (100+rank, '(f9.2,$)') T(i,j)
    !    enddo
    !    write (100+rank, '(" ")')
    !enddo

    call adios_read_close (fh, ierr)
    ! Terminate
    call adios_selection_delete (sel)
    call adios_read_finalize_method (ADIOS_READ_METHOD_BP, ierr)
    call MPI_Finalize (ierr)
  end program reader  
