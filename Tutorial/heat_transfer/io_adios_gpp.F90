
!  ADIOS is freely available under the terms of the BSD license described
!  in the COPYING file in the top level directory of this source distribution.
!
!  Copyright (c) 2008 - 2009.  UT-BATTELLE, LLC. All rights reserved.
!
!
!  Simplest ADIOS/XML based I/O for the heat_transfer example
!
! (c) Oak Ridge National Laboratory, 2014
! Author: Norbert Podhorszki
!
module heat_io

contains

subroutine io_init()
    use heat_vars
    use adios_write_mod
    call adios_init ("heat_transfer.xml", app_comm, ierr)
end subroutine io_init

subroutine io_finalize()
    use heat_vars
    use adios_write_mod
    call adios_finalize (rank, ierr)
end subroutine io_finalize

subroutine io_write(tstep,curr)
    use heat_vars
    use adios_write_mod
    implicit none
    include 'mpif.h'
    integer, intent(in) :: tstep
    integer, intent(in) :: curr

    integer*8 adios_handle, adios_groupsize, adios_totalsize
    integer adios_err
    character (len=200) :: filename
    character(2) :: mode = "w"

    write(filename,'(a,".bp")') trim(outputfile)
  
    if (tstep > 0) mode = "a"

    call adios_open (adios_handle, "heat", filename, mode, app_comm, adios_err)
#include "gwrite_heat.fh"
    call adios_close (adios_handle, adios_err)

end subroutine io_write

end module heat_io


