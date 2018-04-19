!  ADIOS is freely available under the terms of the BSD license described
!  in the COPYING file in the top level directory of this source distribution.
!
!  Copyright (c) 2008 - 2009.  UT-BATTELLE, LLC. All rights reserved.
!
!
!  2D heat transfer example with ghost cells
!
!  nx * ny      processes write a 2D array, where each process writes an
!  ndx * ndy    piece 
!
!  The rectangle is initialized to some values, then heat transfer equation is used
!  to calculate the next step. 
!
!  Output N times after every K iterations
! 
!
! (c) Oak Ridge National Laboratory, 2014
! Author: Norbert Podhorszki
!

program heat_transfer
    use heat_vars
    use heat_io
    implicit none
    include 'mpif.h'
    integer :: tstep ! current timestep (1..steps)
    integer :: it    ! current iteration (1..iters)
    integer :: curr  ! 1 or 2:   T(:,:,curr) = T(t) current step  
                     ! the other half of T is the next step T(t+1)
    real*8  :: tstart, tend

    call MPI_Init (ierr)
    ! World comm spans all applications started with the same mpirun command 
    call MPI_Comm_rank (MPI_COMM_WORLD, wrank, ierr)
    call MPI_Comm_size (MPI_COMM_WORLD, wnproc , ierr)
    ! Have to split and create a 'world' communicator for heat_transfer only
    color = 1
    call MPI_Comm_split (MPI_COMM_WORLD, color, wrank, app_comm, ierr)
    call MPI_Comm_rank (app_comm, rank, ierr)
    call MPI_Comm_size (app_comm, nproc , ierr)

    tstart = MPI_Wtime()

    call io_init()

    call processArgs()
    if (nproc .ne. npx*npy) then
        if (rank == 0) then
            print '("Error: Number of processors ",i0,"does not match ndx*ndy=",i0)', nproc, npx*npy
        endif
        call MPI_Barrier (app_comm, ierr)
        call exit(1)
    endif
    
    if (rank == 0) then
        print '("Process decomposition  : ",i0," x ",i0)', npx,npy
        print '("Array size per process : ",i0," x ",i0)', ndx,ndy
        print '("Number of output steps : ",i0)', steps
        print '("Iterations per step    : ",i0)', iters

    endif

    ! determine global size
    gndx = npx * ndx
    gndy = npy * ndy

    ! determine offsets
    posx = mod(rank, npx)     ! 1st dim easy: 0, npx, 2npx... are in the same X position
    posy = rank/(npx)         ! 2nd dim: npx consecutive processes belong into one dim
    offx = posx * ndx
    offy = posy * ndy

    ! determine neighbors
    if (posx==0) then
        rank_left = -1;
    else
        rank_left = rank-1;
    endif
    if (posx==npx-1) then
        rank_right = -1;
    else
        rank_right = rank+1;
    endif
    if (posy==0) then
        rank_up = -1;
    else
        rank_up = rank-npx;
    endif
    if (posy==npy-1) then
        rank_down = -1;
    else
        rank_down = rank+npx;
    endif


    ! allocate and initialize data array
    allocate( T(0:ndx+1, 0:ndy+1, 2) )
    allocate( dT(1:ndx, 1:ndy) )
    T = 0.0
    dT = 0.0

    ! can we set up T to be a sin wave
    if (rank==0) print '("Simulation step ",i4,": initialization")', 0
    call init_T()

    curr = 1;
    call heatEdges(curr)
    call io_write(0,curr) 

    do tstep=1,steps
        if (rank==0) print '("Simulation step ",i4)', tstep

        do it=1,iters
            call iterate(curr)
            curr = 2/curr  !  flip between 1 and 2, current and next array
            call heatEdges(curr)
            call exchange(curr)
            !print '("Rank ",i4," done exchange")', rank
        end do ! iterations

        call io_write(tstep,curr) 
        !print '("Rank ",i4," done write")', rank

    end do ! steps


    ! Terminate
    deallocate (T)
    call MPI_Barrier (app_comm, ierr)
    call io_finalize()

    call MPI_Barrier (app_comm, ierr)
    tend = MPI_Wtime()

    call MPI_Finalize (ierr)
    if (rank==0) print '("Total runtime = ",f6.3,"s")', tend-tstart
end program heat_transfer



!!***************************
subroutine heatEdges(curr)
    use heat_vars
    implicit none
    integer, intent(in) :: curr

    !! Heat the whole edges
    if (posx==0)     T(0,:,curr)     = edgetemp
    if (posx==npx-1) T(ndx+1,:,curr) = edgetemp
    if (posy==0)     T(:,0,curr)     = edgetemp
    if (posy==npy-1) T(:,ndy+1,curr) = edgetemp

end subroutine heatEdges


!!*********************
subroutine init_T()
    use heat_vars
    implicit none
    include 'mpif.h'
    integer :: i,j,k
    real*8  :: v, x,y,hx,hy
    real*8  :: minv, maxv, mingv, maxgv, skew, ratio


    hx = 2.0 * 4.0*atan(1.0d0)/gndx
    hy = 2.0 * 4.0*atan(1.0d0)/gndy

    minv = 1.0e30
    maxv = -1.0e30

    do j=0,ndy+1
        y = 0.0 + hy*(j - 1 + posy*ndy)
        do i=0,ndx+1
            x = 0.0 + hx*(i - 1 + posx*ndx)
            v = cos(8*x) + cos(6*x) - cos(4*x) + cos(2*x) - cos(x) + &
                sin(8*y) - sin(6*y) + sin(4*y) - sin(2*y) + sin(y) 
            if (v < minv) minv = v
            if (v > maxv) maxv = v
            T(i,j,1) = v
        end do
    end do

    call MPI_Allreduce(minv, mingv, 1, MPI_DOUBLE, MPI_MIN, app_comm, ierr)
    call MPI_Allreduce(maxv, maxgv, 1, MPI_DOUBLE, MPI_MAX, app_comm, ierr)

    ! normalize to [0..2*edgetemp]
    skew = 0.0 - mingv
    ratio = 2 * edgetemp / (maxgv-mingv)
    do j=0,ndy+1
        do i=0,ndx+1
            T(i,j,1) = (T(i,j,1) + skew) * ratio
        end do
    end do

end subroutine init_T


!!***************************
subroutine iterate(curr)
    use heat_vars
    implicit none
    integer, intent(in) :: curr
    include 'mpif.h'
    integer :: i,j,k,next
    real*8, parameter :: omega = 0.8;

    next = 2/curr 
    do j=1,ndy
        do i=1,ndx
            T(i,j,next) = omega/4*(T(i-1,j,curr)+T(i+1,j,curr)+ &
                T(i,j-1,curr)+T(i,j+1,curr) ) + &
                (1.0-omega)*T(i,j,curr)
            dT(i,j) = T(i,j,next) - T(i,j,curr)
            !if (rank==1) then
            !    print '(i0,",",i0,":(",5f9.3,")")', &
            !    j,i, &
            !    T(i-1,j,curr), T(i+1,j,curr), &
            !    T(i,j-1,curr), T(i,j+1,curr), &
            !    T(i,j,curr)
            !endif
        enddo
    enddo

end subroutine iterate

!!***************************
subroutine exchange(curr)
    use heat_vars
    implicit none
    integer, intent(in) :: curr
    include 'mpif.h'
    integer status(MPI_STATUS_SIZE,1), tag

    ! Exchange ghost cells, in the order left-right-up-down
    !  call MPI_Isend(buf,nsize,type,target_rank,tag,comm,request,ierr) 
    !  call MPI_Irecv(buf,nsize,type,target_rank,tag,comm,request,ierr)

    ! send to left + receive from right
    tag = 1
    if (posx > 0) then
        !print '("Rank ",i4," send left to rank ",i4)', rank, rank-1
        call MPI_Send(T(1,0:ndy+1,curr), ndy+2, MPI_REAL8, rank-1, tag, app_comm, ierr) 
    endif
    if (posx < npx-1) then
        !print '("Rank ",i4," recv from right from rank ",i4)', rank, rank+1
        call MPI_Recv(T(ndx+1,0:ndy+1,curr), ndy+2, MPI_REAL8, rank+1, tag, app_comm, status, ierr) 
    endif

    ! send to right + receive from left
    tag = 2
    if (posx < npx-1) then
        !print '("Rank ",i4," send right to rank ",i4)', rank, rank+1
        call MPI_Send(T(ndx,0:ndy+1,curr), ndy+2, MPI_REAL8, rank+1, tag, app_comm, ierr) 
    endif
    if (posx > 0) then
        !print '("Rank ",i4," recv from left from rank ",i4)', rank, rank-1
        call MPI_Recv(T(0,0:ndy+1,curr), ndy+2, MPI_REAL8, rank-1, tag, app_comm, status, ierr) 
    endif

    ! send to down + receive from above
    tag = 3
    if (posy < npy-1) then
        !print '("Rank ",i4," send down curr=",i1," to rank ",i4)', rank, curr, rank+npx
        call MPI_Send(T(0:ndx+1,ndy,curr), ndx+2, MPI_REAL8, rank+npx, tag, app_comm, ierr) 
    endif
    if (posy > 0) then
        !print '("Rank ",i4," recv from above curr=",i1," from rank ",i4)', rank, curr, rank-npx
        call MPI_Recv(T(0:ndx+1,0,curr), ndx+2, MPI_REAL8, rank-npx, tag, app_comm, &
                status, ierr) 
    endif

    ! send to up + receive from below
    tag = 4
    if (posy > 0) then
        !print '("Rank ",i4," send up curr=",i1," to rank ",i4)', rank, curr, rank-npx
        call MPI_Send(T(0:ndx+1,1,curr), ndx+2, MPI_REAL8, rank-npx, tag, app_comm, ierr) 
    endif
    if (posy < npy-1) then
        !print '("Rank ",i4," recv from below curr=",i1," from rank ",i4)', rank, curr, rank+npx
        call MPI_Recv(T(0:ndx+1,ndy+1,curr), ndx+2, MPI_REAL8, rank+npx, tag, app_comm, &
                status, ierr) 
    endif

end subroutine exchange


!!***************************
subroutine usage()
    print *, "Usage: heat_transfer  output  N  M   nx  ny   steps iterations"
    print *, "output: name of output file"
    print *, "N:      number of processes in X dimension"
    print *, "M:      number of processes in Y dimension"
    print *, "nx:     local array size in X dimension per processor"
    print *, "ny:     local array size in Y dimension per processor"
    print *, "steps:  the total number of steps to output" 
    print *, "iterations: one step consist of this many iterations"
end subroutine usage

!!***************************
subroutine processArgs()
    use heat_vars

#ifndef __GFORTRAN__
#ifndef __GNUC__
    interface
         integer function iargc()
         end function iargc
    end interface
#endif
#endif

    character(len=256) :: npx_str, npy_str, ndx_str, ndy_str
    character(len=256) :: steps_str,iters_str
    integer :: numargs

    !! process arguments
    numargs = iargc()
    !print *,"Number of arguments:",numargs
    if ( numargs < 7 ) then
        call usage()
        call exit(1)
    endif
    call getarg(1, outputfile)
    call getarg(2, npx_str)
    call getarg(3, npy_str)
    call getarg(4, ndx_str)
    call getarg(5, ndy_str)
    call getarg(6, steps_str)
    call getarg(7, iters_str)
    read (npx_str,'(i5)') npx
    read (npy_str,'(i5)') npy
    read (ndx_str,'(i6)') ndx
    read (ndy_str,'(i6)') ndy
    read (steps_str,'(i6)') steps
    read (iters_str,'(i6)') iters

end subroutine processArgs


