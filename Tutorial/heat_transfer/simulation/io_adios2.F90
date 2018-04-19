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

    call adios2_init_config (adios, "adios2.xml",  app_comm, adios2_debug_mode_on, ierr)
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

    integer :: adios2_err
    character (len=200) :: filename
    ! variables for definition
    integer*8 :: varid
    ! character(len=100) :: gdims, ldims, offs
    ! in this case shape = gdims, start = offs, count = ldims
    integer*8, dimension(2) :: shape_dims, start_dims, count_dims
    real*8, dimension(:,:), allocatable :: T_temp

    write(filename,'(a,".bp")') trim(outputfile)

    ! Define variables at the first time
    if (tstep.eq.0) then

        call adios2_open (bp_writer, io, filename, adios2_mode_write, adios2_err)

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

    call adios2_begin_step( bp_writer, adios2_step_mode_append, 0., &
                            adios2_err)

    ! We need the temporary survive until EndStep, so we cannot just pass
    ! here the T(1:ndx,1:ndy,curr)
    allocate(T_temp(1:ndx,1:ndy))
    T_temp = T(1:ndx,1:ndy,curr)
    call adios2_put_deferred( bp_writer, var_T, T_temp, adios2_err )
    call adios2_put_deferred( bp_writer, var_dT, dT, adios2_err )

    call adios2_end_step( bp_writer, adios2_err)

    deallocate(T_temp)

    call MPI_BARRIER(app_comm ,adios2_err)
end subroutine io_write


end module heat_io
