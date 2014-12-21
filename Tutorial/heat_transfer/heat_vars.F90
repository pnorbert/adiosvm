
!  ADIOS is freely available under the terms of the BSD license described
!  in the COPYING file in the top level directory of this source distribution.
!
!  Copyright (c) 2008 - 2009.  UT-BATTELLE, LLC. All rights reserved.
!
!
!  Global variables for the heat_transfer example
!
! (c) Oak Ridge National Laboratory, 2014
! Author: Norbert Podhorszki
!
module heat_vars
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

    ! MPI COMM_WORLD is for all codes started up at once on Cray XK6 
    integer :: wrank, wnproc

    ! MPI 'world' for this app variables
    integer :: app_comm, color
    integer :: rank, nproc
    integer :: ierr
    integer :: rank_left, rank_right, rank_up, rank_down ! neighbours' ranks

    integer   :: err

    real*8 :: start_time, end_time, total_time,gbs,sz
    real*8 :: io_start_time, io_end_time, io_total_time


end module heat_vars


