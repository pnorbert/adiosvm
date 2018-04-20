
!  ADIOS is freely available under the terms of the BSD license described
!  in the COPYING file in the top level directory of this source distribution.
!
!  Copyright (c) 2008 - 2009.  UT-BATTELLE, LLC. All rights reserved.
!
!
!  Write an ADIOS BP file 
!
! (c) Oak Ridge National Laboratory, 2009
! Author: Norbert Podhorszki
!
module heat_print

contains

subroutine print_array(xy,offset,rank, step)
    implicit none
    include 'mpif.h'
    real*8,    dimension(:,:), intent(in) :: xy
    integer*8, dimension(2),   intent(in) :: offset
    integer,   intent(in)                 :: rank, step

    integer :: size1,size2
    integer :: i,j

    size1 = size(xy,1)
    size2 = size(xy,2)

    write (100+rank, '("rank=",i0," size=",i0,"x",i0," offsets=",i0,":",i0," step=",i0)') &
        rank, size1, size2, offset(1), offset(2), step 
    write (100+rank, '(" time   row   columns ",i0,"...",i0)'), offset(2), offset(2)+size2-1  
    write (100+rank, '("        ",$)') 
    do j=1,size2
        write (100+rank, '(i9,$)'), offset(2)+j-1
    enddo
    write (100+rank, '(" ")')
    write (100+rank, '("--------------------------------------------------------------")') 
    do i=1,size1
        write (100+rank, '(2i5,$)') step,offset(1)+i-1
        do j=1,size2
            write (100+rank, '(f9.2,$)') xy(i,j)
        enddo
        write (100+rank, '(" ")')
    enddo

end subroutine print_array

end module heat_print


