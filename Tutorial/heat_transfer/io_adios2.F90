!  ADIOS is freely available under the terms of the BSD license described
!  in the COPYING file in the top level directory of this source distribution.
!
!  Copyright (c) 2008 - 2017.  UT-BATTELLE, LLC. All rights reserved.
!  ADIOS2 I/O for the heat_transfer example
!
! (c) Oak Ridge National Laboratory, 2018
! Author: William F Godoy
!
module heat_io

    implicit none
    ! adios handlers
    integer*8 :: adios, io, bp_writer, var_gndx, var_gndy, var_T, var_dT

contains

subroutine io_init()
    use heat_vars
    use adios2
    implicit none

    call adios2_init (adios, app_comm, adios2_debug_mode_on, ierr)
    call adios2_declare_io (io, adios, 'heat', ierr )
end subroutine io_init

subroutine io_finalize()
    use heat_vars
    use adios2
    implicit none

    call adios2_close(bp_writer, ierr)
    call adios2_finalize (adios, ierr)
end subroutine io_finalize

subroutine io_write(tstep,curr)
    use heat_vars
    use adios2
    implicit none
    include 'mpif.h'
    integer, intent(in) :: tstep
    integer, intent(in) :: curr

    integer*8 :: adios_handle, adios_totalsize
    integer :: adios2_err
    character (len=200) :: filename
    character(2) :: mode = "w"
    ! variables for definition
    integer*8 :: varid
    ! character(len=100) :: gdims, ldims, offs
    ! in this case shape = gdims, start = offs, count = ldims
    integer*8, dimension(2) :: shape_dims, start_dims, count_dims

    write(filename,'(a,".bp")') trim(outputfile)
    if (rank==0.and.tstep==1) then
        print '("Writing: "," filename ",14x,"size(GB)",4x,"io_time(sec)",6x,"GB/s")'
    endif

    ! if (tstep > 1) mode = "a"

    ! Define variables at the first time
    if (tstep.eq.1) then

        call adios2_open (bp_writer, io, filename, adios2_mode_write, adios2_err)

        if( rank == 0 ) then
            ! global variables
            call adios2_define_variable (var_gndx, io, "gndx", gndx, adios2_err)
            call adios2_define_variable (var_gndy, io, "gndy", gndy, adios2_err)

            call adios2_put_sync (bp_writer, var_gndx, gndx, adios2_err)
            call adios2_put_sync (bp_writer, var_gndy, gndy, adios2_err)
        end if

        ! Define T and dT array dimensions
        shape_dims(1) = gndx
        start_dims(1) = offx
        count_dims(1) = ndx

        shape_dims(2) = gndy
        start_dims(2) = offy
        count_dims(2) = ndy

        call adios2_define_variable (var_T, io, "T", 2, shape_dims, &
                                     start_dims, count_dims, &
                                     adios2_constant_dims,  &
                                     T(1:ndx,1:ndy,curr), adios2_err )

        call adios2_define_variable( var_dT, io, "dT", 2, shape_dims, &
                                     start_dims, count_dims, &
                                     adios2_constant_dims, dT, adios2_err )
    endif

    call MPI_BARRIER(app_comm, adios2_err)
    io_start_time = MPI_WTIME()

    call adios2_begin_step( bp_writer, adios2_step_mode_next_available, 0., &
                            adios2_err)
    call adios2_put_sync( bp_writer, var_T, T(1:ndx,1:ndy,curr), adios2_err )
    call adios2_put_sync( bp_writer, var_dT, dT, adios2_err )

    call adios2_end_step( bp_writer, adios2_err)

    call MPI_BARRIER(app_comm ,adios2_err)
    io_end_time = MPI_WTIME()
    io_total_time = io_end_time - io_start_time
    sz = adios_totalsize * nproc/1024.d0/1024.d0/1024.d0 !size in GB
    gbs = sz/io_total_time
    if (rank==0) print '("Step ",i3,": ",a20,f12.4,2x,f12.3,2x,f12.3)', &
        tstep,filename,sz,io_total_time,gbs
end subroutine io_write


end module heat_io
