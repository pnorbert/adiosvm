
!  ADIOS is freely available under the terms of the BSD license described
!  in the COPYING file in the top level directory of this source distribution.
!
!  Copyright (c) 2008 - 2009.  UT-BATTELLE, LLC. All rights reserved.
!
!
!  ADIOS/XML based I/O for the heat_transfer example
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
    if (rank==0.and.tstep==0) then
        print '("Writing: "," filename ",14x,"size(GB)",4x,"io_time(sec)",6x,"GB/s")'
    endif
  
    if (tstep > 0) mode = "a"

    call MPI_BARRIER(app_comm, adios_err)
    io_start_time = MPI_WTIME()
    call adios_open (adios_handle, "heat", filename, mode, app_comm, adios_err)
    adios_groupsize = 11*4 + 2*8*ndx*ndy 
    call adios_group_size (adios_handle, adios_groupsize, adios_totalsize, adios_err)
    call adios_write (adios_handle, "gndx", gndx, adios_err)
    call adios_write (adios_handle, "gndy", gndy, adios_err)
    call adios_write (adios_handle, "/info/nproc", nproc, adios_err)
    call adios_write (adios_handle, "/info/npx", npx, adios_err)
    call adios_write (adios_handle, "/info/npy", npy, adios_err)
    call adios_write (adios_handle, "offx", offx, adios_err)
    call adios_write (adios_handle, "offy", offy, adios_err)
    call adios_write (adios_handle, "ndx", ndx, adios_err)
    call adios_write (adios_handle, "ndy", ndy, adios_err)
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
    if (rank==0) print '("Step ",i3,": ",a20,f12.4,2x,f12.3,2x,f12.3)', &
        tstep,filename,sz,io_total_time,gbs
end subroutine io_write

end module heat_io


