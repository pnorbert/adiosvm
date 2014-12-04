
!  ADIOS is freely available under the terms of the BSD license described
!  in the COPYING file in the top level directory of this source distribution.
!
!  Copyright (c) 2008 - 2009.  UT-BATTELLE, LLC. All rights reserved.
!
!
!  Write fort.<rank+100> text files, one per process
!
! (c) Oak Ridge National Laboratory, 2009
! Author: Norbert Podhorszki
!
module heat_io

contains

subroutine io_init()
end subroutine io_init

subroutine io_finalize()
end subroutine io_finalize

subroutine io_write(tstep,curr)
    use heat_vars
    implicit none
    include 'mpif.h'
    integer, intent(in) :: tstep
    integer, intent(in) :: curr

    integer :: i,j

    if (tstep==0) then
        write (100+rank, '("rank=",i0," size=",i0,"x",i0," offsets=",i0,":",i0," step=",i0)') &
            rank, ndx, ndy, offx, offy, tstep 
        write (100+rank, '(" time   row   columns ",i0,"...",i0)'), offy, offy+ndy-1  
        write (100+rank, '("        ",$)') 
        do j=1,ndy
            write (100+rank, '(i9,$)'), offy+j-1
        enddo
        write (100+rank, '(" ")')
        write (100+rank, '("--------------------------------------------------------------")') 
    else
        write (100+rank, '(" ")')
    endif

    do i=1,ndx
        write (100+rank, '(2i5,$)') tstep,offx+i-1
        do j=1,ndy
            write (100+rank, '(f9.2,$)') T(i,j,curr)
        enddo
        write (100+rank, '(" ")')
    enddo
end subroutine io_write

end module heat_io


