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
    type(adios2_file) :: adios2_fhw

contains

subroutine io_init()
    use heat_vars
    use adios2
    implicit none

end subroutine io_init

subroutine io_finalize()
    use heat_vars
    use adios2
    implicit none

    call adios2_fclose(adios2_fhw, ierr)
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

    ! Define variables at the first time
    shape_dims(1) = gndx
    start_dims(1) = offx
    count_dims(1) = ndx

    shape_dims(2) = gndy
    start_dims(2) = offy
    count_dims(2) = ndy

    write(filename,'(a,".bp")') trim(outputfile)

    if (tstep.eq.0) then
        call adios2_fopen (adios2_fhw, filename, adios2_mode_write, app_comm, &
                           "adios2.xml", "SimulationOutput", ierr )
    end if

    call MPI_BARRIER(app_comm, adios2_err)
    io_start_time = MPI_WTIME()

    ! We need the temporary survive until EndStep, so we cannot just pass
    ! here the T(1:ndx,1:ndy,curr)
    allocate(T_temp(1:ndx,1:ndy))
    T_temp = T(1:ndx,1:ndy,curr)

    call adios2_fwrite(adios2_fhw, "T", T_temp, 2, shape_dims, &
                       start_dims, count_dims, adios2_err)

    call adios2_fwrite(adios2_fhw, "dT", dT, 2, shape_dims, &
                       start_dims, count_dims, adios2_advance_yes, adios2_err)

    deallocate(T_temp)

    call MPI_BARRIER(app_comm ,adios2_err)
end subroutine io_write


end module heat_io
