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
    use adios2
    implicit none
    ! adios handlers
    type(adios2_adios)    :: adios
    type(adios2_io)       :: io
    type(adios2_engine)   :: bp_writer
    type(adios2_variable) :: var_gndx, var_gndy, var_T
    type(adios2_attribute) :: attr_unit, attr_desc

contains

subroutine io_init()
    use heat_vars
    use adios2
    implicit none

    call adios2_init (adios, "adios2.xml",  app_comm, adios2_debug_mode_on, ierr)
    call adios2_declare_io (io, adios, 'SimulationOutput', ierr )

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

    integer :: adios2_err, istatus
    ! variables for definition
    integer*8 :: varid
    ! character(len=100) :: gdims, ldims, offs
    ! in this case shape = gdims, start = offs, count = ldims
    integer*8, dimension(2) :: shape_dims, start_dims, count_dims
    real*8, dimension(:,:), allocatable :: T_temp

    ! Define variables at the first time
    if (tstep.eq.0) then

        call adios2_open (bp_writer, io, outputfile, adios2_mode_write, adios2_err)
        ! For information purposes only:
        if (rank == 0) then
            print '("Using ",a, " engine for output")', bp_writer%type
        endif

        ! Define T array dimensions
        shape_dims(1) = gndx
        start_dims(1) = offx
        count_dims(1) = ndx

        shape_dims(2) = gndy
        start_dims(2) = offy
        count_dims(2) = ndy

        call adios2_define_variable (var_T, io, "T", adios2_type_dp, &
                                     2, shape_dims, &
                                     start_dims, count_dims, &
                                     adios2_constant_dims,  &
                                     adios2_err )
        call adios2_define_attribute(attr_unit, io, "unit", "C", "T", adios2_err);
        call adios2_define_attribute(attr_desc, io, "description", "Temperature from simulation", "T", adios2_err);

    endif

    call MPI_BARRIER(app_comm, adios2_err)

    call adios2_begin_step( bp_writer, adios2_step_mode_append, -1., &
                            istatus, adios2_err)

    ! We need the temporary array survive until EndStep, 
    ! so we cannot just pass here the T(1:ndx,1:ndy,curr)
    allocate(T_temp(1:ndx,1:ndy))
    T_temp = T(1:ndx,1:ndy,curr)

    call adios2_put( bp_writer, var_T, T_temp, adios2_err )

    call adios2_end_step( bp_writer, adios2_err)

    deallocate(T_temp)

    call MPI_BARRIER(app_comm ,adios2_err)
end subroutine io_write


end module heat_io
