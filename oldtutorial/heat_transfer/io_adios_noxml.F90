
!  ADIOS is freely available under the terms of the BSD license described
!  in the COPYING file in the top level directory of this source distribution.
!
!  Copyright (c) 2008 - 2009.  UT-BATTELLE, LLC. All rights reserved.
!
!
!  Simplest ADIOS non-XML based I/O for the heat_transfer example
!
! (c) Oak Ridge National Laboratory, 2014
! Author: Norbert Podhorszki
!
module heat_io

    integer*8 :: g ! adios group

contains

subroutine io_init()
    use heat_vars
    use adios_write_mod
    implicit none
    call adios_init_noxml (app_comm, ierr)
    call adios_allocate_buffer (20, ierr)
    call adios_declare_group (g, "heat", "", 1, ierr)
    call adios_select_method (g, "MPI", "", "", ierr)
    !call adios_select_method (g, "MPI_AGGREGATE", "num_aggregators=2;num_ost=2;verbose=3", "", ierr)
end subroutine io_init

subroutine io_finalize()
    use heat_vars
    use adios_write_mod
    implicit none
    call adios_finalize (rank, ierr)
end subroutine io_finalize

subroutine io_write(tstep,curr)
    use heat_vars
    use adios_write_mod
    implicit none
    include 'mpif.h'
    integer, intent(in) :: tstep
    integer, intent(in) :: curr

    integer*8 :: adios_handle, adios_totalsize
    integer :: adios_err
    character (len=200) :: filename
    character(2) :: mode = "w"
    ! variables for definition
    integer*8 :: varid
    character(len=100) :: gdims, ldims, offs


    write(filename,'(a,".bp")') trim(outputfile)
    if (rank==0.and.tstep==1) then
        print '("Writing: "," filename ",14x,"size(GB)",4x,"io_time(sec)",6x,"GB/s")'
    endif
  
    if (tstep > 1) mode = "a"

    ! Define variables at the first time
    if (tstep.eq.1) then
        call adios_define_var (g, "gndx", "", adios_integer, &
                               "", "", "", varid)
        call adios_define_var (g, "gndy", "", adios_integer, &
                               "", "", "", varid)

        ! Define a global array
        ! option 2: define with string of actual values
        !          -> we can write the array only 
        !          -> but have to create strings here
        write (ldims, '(i0,",",i0)') ndx, ndy
        write (gdims, '(i0,",",i0)') gndx, gndy
        write (offs,  '(i0,",",i0)') offx, offy

        call adios_define_var (g, "T", "", adios_double, &
                               ldims, gdims, offs, varid)

        call adios_define_var (g, "dT", "", adios_double, &
                               ldims, gdims, offs, varid)
    endif

    call MPI_BARRIER(app_comm, adios_err)
    io_start_time = MPI_WTIME()
    call adios_open (adios_handle, "heat", filename, mode, app_comm, adios_err)
    call adios_write (adios_handle, "gndx", gndx, adios_err)
    call adios_write (adios_handle, "gndy", gndy, adios_err)
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


