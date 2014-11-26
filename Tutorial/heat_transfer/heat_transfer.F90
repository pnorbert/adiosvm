
!  ADIOS is freely available under the terms of the BSD license described
!  in the COPYING file in the top level directory of this source distribution.
!
!  Copyright (c) 2008 - 2009.  UT-BATTELLE, LLC. All rights reserved.
!

!
!  2D heat transfer example with ghost cells
!
!  Write an ADIOS BP file from many processor for test purposes.
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
! (c) Oak Ridge National Laboratory, 2009
! Author: Norbert Podhorszki
!
module heat_common
    ! arguments
    character(len=256) :: outputfile, inputfile
    integer :: npx, npy    ! # of processors in x-y direction
    integer :: ndx, ndy    ! size of array per processor (without ghost cells)
    integer :: steps       ! number of steps to write
    integer :: iters       ! number of iterations between steps

    integer :: gndx, gndy  ! size of the global array (without ghost cells)
    integer :: offx,offy   ! offsets of local array in the global array
    integer :: posx, posy  ! position index in the array

    real*8, dimension(:,:,:), allocatable :: T    ! data array 
    real*8, dimension(:,:), allocatable   :: dT   ! data array 
    integer, dimension(:,:), allocatable :: heatmap

    ! MPI COMM_WORLD is for all codes started up at once on Cray XK6 
    integer :: wrank, wnproc

    ! MPI 'world' for this app variables
    integer :: app_comm, color
    integer :: rank, nproc
    integer :: ierr
    integer :: rank_left, rank_right, rank_up, rank_down ! neighbours' ranks

    ! ADIOS variables
    character (len=200) :: group
    character (len=200) :: filename
    !character (len=6)   :: nprocstr
    integer*8 :: handle, total_size, group_size, adios_totalsize
    integer   :: err

    real*8 :: start_time, end_time, total_time,gbs,sz
    real*8 :: io_start_time, io_end_time, io_total_time


end module heat_common


program heat_transfer
    use heat_common
    implicit none
    include 'mpif.h'
    integer :: tstep ! current timestep (1..steps)
    integer :: it    ! current iteration (1..iters)
    integer :: curr  ! 1 or 2:   T(:,:,curr) = T(t) current step  
                     ! the other half of T is the next step T(t+1)

    call MPI_Init (ierr)
    ! World comm spans all applications started with the same aprun command 
    ! on a Cray XK6
    call MPI_Comm_rank (MPI_COMM_WORLD, wrank, ierr)
    call MPI_Comm_size (MPI_COMM_WORLD, wnproc , ierr)
    ! Have to split and create a 'world' communicator for heat_transfer only
    color = 1

    call MPI_Barrier(MPI_COMM_WORLD, ierr);
    call MPI_Comm_split (MPI_COMM_WORLD, color, wrank, app_comm, ierr)
    !call MPI_Comm_dup (MPI_COMM_WORLD, app_comm, ierr)

    call MPI_Comm_rank (app_comm, rank, ierr)
    call MPI_Comm_size (app_comm, nproc , ierr)

    call adios_init ("heat_transfer.xml", app_comm, ierr)
    call MPI_Barrier (app_comm, ierr)

    call processArgs()
    
    if (rank == 0) then
        print *,"Output file(s): "//trim(outputfile)//".<step>.bp"
        print '(" Process number        : ",i0," x ",i0)', npx,npy
        print '(" Array size per process at first step: ",i0," x ",i0)', ndx,ndy

        if (nproc .ne. npx*npy) then
            print '(" Error: Number of processors ",i0,"does not match ndx*ndy=",i0)', nproc, npx*npy
            call exit(1)
        endif
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

    ! allocate and initialize heat map
    allocate( heatmap(0:6,0:6) )
    heatmap = 0
    heatmap = transpose(reshape(            &
                (/ 1000, 1000, 1000, 1000, 1000, 1000, 1000,        & 
                   1000,    0,    0,    0,    0,    0, 1000,        &
                   1000,    0,    0,    0,    0,    0, 1000,        &
                   1000,    0,    0,    0,    0,    0, 1000,        &
                   1000,    0,    0,  500,    0,    0, 1000,        &
                   1000,    0,    0,    0,    0,    0, 1000,        &
                   0000, 0000, 0000, 0000, 0000, 0000, 0000 /),     &
           (/ size(heatmap, 2), size(heatmap, 1) /)))


    curr = 1;
    call heatEdges(curr)
    call writeADIOS(0,curr)  ! write out init values

    do tstep=1,steps
        if (rank==0) print '("Step ",i4,":")', tstep

        do it=1,iters
            call iterate(curr)
            curr = 2/curr  !  flip between 1 and 2, current and next array
            call heatEdges(curr)
            call exchange(curr)
            !print '("Rank ",i4," done exchange")', rank
        end do ! iterations

        call writeADIOS(tstep,curr) 
        !print '("Rank ",i4," done write")', rank

    end do ! steps


    ! Terminate
    deallocate (T)
    deallocate (heatmap)
    call MPI_Barrier (app_comm, ierr)
    call adios_finalize (rank, ierr)
    call MPI_Finalize (ierr)
end program heat_transfer



!!***************************
subroutine heatEdges(curr)
    use heat_common
    implicit none
    integer, intent(in) :: curr
    real*8, parameter :: edgetemp = 1000.0

    !! Heat the whole edges
    if (posx==0)     T(0,:,curr)     = edgetemp
    if (posx==npx-1) T(ndx+1,:,curr) = edgetemp
    if (posy==0)     T(:,0,curr)     = edgetemp
    if (posy==npy-1) T(:,ndy+1,curr) = edgetemp

end subroutine heatEdges

!!***************************
subroutine heat(curr)
    use heat_common
    implicit none
    integer, intent(in) :: curr
    integer :: mx, my, i, j
    real :: cx, cy
    integer :: mapx, mapy

    mx = size (heatmap,1)
    my = size (heatmap,2)
    cx = (mx) / (gndx+2.0)
    cy = (my) / (gndy+2.0)

!    if (rank==0) then
!        print '("mx=",i0," my=",i0," cx=",f9.3," cy=",5f9.3)', &
!            mx, my, cx, cy
!    endif
!    print '(i0,": offx=",i0," offy=",i0)', &
!        rank, offx, offy

    do j=0,ndy+1
        mapy = (offy+j) * cy 
        do i=0,ndx+1
           mapx = (offx+i) * cx 
!           if (rank==1) then
!              print '(i0,": i=",i0," mapx=",i0," j=",i0," mapy=",i0)', &
!                  rank, i, mapx, j, mapy
!           endif
           if (heatmap(mapx, mapy) /= 0.0) then
               T(i,j,curr) = (T(i,j,curr) + heatmap (mapx, mapy))/2.0
           endif
        enddo
    enddo

end subroutine heat


!!***************************
subroutine iterate(curr)
    use heat_common
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
    use heat_common
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
subroutine writeADIOS(tstep,curr)
    use heat_common
    implicit none
    include 'mpif.h'
    integer, intent(in) :: tstep
    integer, intent(in) :: curr

    integer*8 adios_handle, adios_groupsize
    integer adios_err
    character(2) :: mode = "w"


    if (rank==0.and.tstep==0) then
        print '("Writing: "," filename ",14x,"size(GB)",4x,"io_time(sec)",6x,"GB/s")'
    endif
  
    if (tstep > 0) mode = "a"

    call MPI_BARRIER(app_comm, adios_err)
    io_start_time = MPI_WTIME()
    call adios_open (adios_handle, "heat", outputfile, mode, app_comm, adios_err)
    adios_groupsize = 11*4 + 2*8*ndx*ndy 
    call adios_group_size (adios_handle, adios_groupsize, adios_totalsize, adios_err)
    call adios_write (adios_handle, "/dims/gndx", gndx, adios_err)
    call adios_write (adios_handle, "/dims/gndy", gndy, adios_err)
    call adios_write (adios_handle, "/info/nproc", nproc, adios_err)
    call adios_write (adios_handle, "/info/npx", npx, adios_err)
    call adios_write (adios_handle, "/info/npy", npy, adios_err)
    call adios_write (adios_handle, "/aux/offx", offx, adios_err)
    call adios_write (adios_handle, "/aux/offy", offy, adios_err)
    call adios_write (adios_handle, "/aux/ndx", ndx, adios_err)
    call adios_write (adios_handle, "/aux/ndy", ndy, adios_err)
    call adios_write (adios_handle, "step", tstep, adios_err)
    call adios_write (adios_handle, "iterations", iters, adios_err)
    call adios_write (adios_handle, "T", T(1:ndx,1:ndy,curr), adios_err)
    call adios_write (adios_handle, "dT", dT, adios_err)
    call adios_close (adios_handle, adios_err)
    call MPI_BARRIER(app_comm ,adios_err)
    io_end_time = MPI_WTIME()
    io_total_time = io_end_time - io_start_time
    sz = adios_totalsize * nproc/1024.d0/1024.d0/1024.d0 !size in GB
    gbs = sz/io_total_time
    if (rank==0) print '("Step ",i3,": ",a20,d12.2,2x,d12.2,2x,d12.3)', &
        tstep,outputfile,sz,io_total_time,gbs
end subroutine writeADIOS


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
    use heat_common

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


!!******  NOT  WORKING  YET **********
subroutine exchange_async(curr)
    use heat_common
    implicit none
    integer, intent(in) :: curr
    include 'mpif.h'
    integer request(8),status(MPI_STATUS_SIZE,8)

    request = MPI_REQUEST_NULL
    status  = 0

    ! Exchange ghost cells, in the order left-right-up-down
    !  call MPI_Isend(buf,nsize,type,target_rank,tag,comm,request,ierr) 
    !  call MPI_Irecv(buf,nsize,type,target_rank,tag,comm,request,ierr)

    ! send to left + receive from left
    if (posx > 0) then
        call MPI_Isend(T(1,:,curr), ndy+2, MPI_REAL8, rank-1, 0, app_comm, request(1), ierr) 
        call MPI_Irecv(T(0,:,curr), ndy+2, MPI_REAL8, rank-1, 0, app_comm, request(2), ierr) 
    endif
    ! send to right + receive from right
    if (posx < npx-1) then
        call MPI_Isend(T(ndx,:,curr), ndy+2, MPI_REAL8, rank+1, 0, app_comm, request(3), ierr) 
        call MPI_Irecv(T(ndx+1,:,curr), ndy+2, MPI_REAL8, rank+1, 0, app_comm, request(4), ierr) 
    endif

    ! send up + receive from above
    if (posy > 0 ) then
        call MPI_Isend(T(:,1,curr), ndy+2, MPI_REAL8, rank-npx, 0, app_comm, request(5), ierr) 
        call MPI_Irecv(T(:,0,curr), ndy+2, MPI_REAL8, rank-npx, 0, app_comm, request(6), ierr) 
    endif
    ! send down + receive from below 
    if (posy < npy-1) then
        call MPI_Isend(T(:,ndy,curr), ndy+2, MPI_REAL8, rank+npx, 0, app_comm, request(7), ierr) 
        call MPI_Irecv(T(:,ndy+1,curr), ndy+2, MPI_REAL8, rank+npx, 0, app_comm, request(8), ierr) 
    endif

    ! Wait for all communication to be finished
    call MPI_Waitall(8,request,status,ierr)

end subroutine exchange_async

