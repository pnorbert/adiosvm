
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
module heat_io

contains

subroutine io_init()
    use heat_vars
    use HDF5

    ! Initialize FORTRAN interface
    call h5open_f(err)

end subroutine io_init

subroutine io_finalize()
    use heat_vars
    use HDF5

    ! Close FORTRAN interface.
    call h5close_f(err)

end subroutine io_finalize

subroutine io_write(tstep,curr)
    use heat_vars
    use HDF5
    implicit none
    include 'mpif.h'
    integer, intent(in) :: tstep
    integer, intent(in) :: curr

    integer*8 io_size

    INTEGER(HID_T) :: file_id

    character (len=200) :: filename
    character(2) :: mode = "w"


    write(filename,'(a,".",i3.3,".h5")') trim(outputfile), rank
    print '("rank ",i0," writes to: ",a)', rank, trim(filename)

  
    if (tstep > 0) mode = "a"

    call MPI_BARRIER(app_comm, err)
    io_start_time = MPI_WTIME()
! TODO: generate filename from outputfile
    call H5Fcreate_f (filename, H5F_ACC_TRUNC_F, file_id, err)
!    call adios_open (adios_handle, "heat", outputfile, mode, app_comm, adios_err)
    io_size = 11*4 + 2*8*ndx*ndy 
!    call adios_group_size (adios_handle, adios_groupsize, adios_totalsize, adios_err)
!    call adios_write (adios_handle, "/dims/gndx", gndx, adios_err)
!    call adios_write (adios_handle, "/dims/gndy", gndy, adios_err)
!    call adios_write (adios_handle, "/info/nproc", nproc, adios_err)
!    call adios_write (adios_handle, "/info/npx", npx, adios_err)
!    call adios_write (adios_handle, "/info/npy", npy, adios_err)
!    call adios_write (adios_handle, "/aux/offx", offx, adios_err)
!    call adios_write (adios_handle, "/aux/offy", offy, adios_err)
!    call adios_write (adios_handle, "/aux/ndx", ndx, adios_err)
!    call adios_write (adios_handle, "/aux/ndy", ndy, adios_err)
!    call adios_write (adios_handle, "step", tstep, adios_err)
!    call adios_write (adios_handle, "iterations", iters, adios_err)
!    call adios_write (adios_handle, "T", T(1:ndx,1:ndy,curr), adios_err)
!    call adios_write (adios_handle, "dT", dT, adios_err)
!    call adios_close (adios_handle, adios_err)
    call MPI_BARRIER(app_comm ,err)
    io_end_time = MPI_WTIME()
    io_total_time = io_end_time - io_start_time
    sz = io_size * nproc/1024.d0/1024.d0/1024.d0 !size in GB
    gbs = sz/io_total_time
    if (rank==0) print '("Step ",i3,": ",a20,d12.2,2x,d12.2,2x,d12.3)', &
        tstep,filename,sz,io_total_time,gbs
end subroutine io_write

end module heat_io


