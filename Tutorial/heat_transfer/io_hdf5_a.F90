
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

    integer :: ndims
    integer*8, dimension(1:2) :: dims

    integer*8 io_size

    INTEGER(HID_T) :: file_id
    INTEGER(HID_T) :: dset_id
    INTEGER(HID_T) :: dspace_id

    character (len=200) :: filename
    character(2) :: mode = "w"


    write(filename,'(a,".",i3.3,".",i3.3,".h5")') trim(outputfile), rank, tstep
    print '("rank ",i0," writes to: ",a)', rank, trim(filename)

    call MPI_BARRIER(app_comm, err)
    io_start_time = MPI_WTIME()

    ndims = 2
    dims(1) = ndx
    dims(2) = ndy

    call h5fcreate_f (filename, H5F_ACC_TRUNC_F, file_id, err)
    call h5screate_simple_f(ndims, dims, dspace_id, err) 
    call h5dcreate_f(file_id, "T", H5T_NATIVE_DOUBLE, dspace_id, &
                     dset_id, err)

    io_size = 11*4 + 2*8*ndx*ndy 

    call h5dwrite_f(dset_id, H5T_NATIVE_DOUBLE, T(1:ndx,1:ndy,curr), dims, err)


! close dataset
    call h5dclose_f(dset_id, err)

! close dataspace
    call h5sclose_f(dspace_id, err)

! close file
    call h5fclose_f(file_id, err)

    call MPI_BARRIER(app_comm ,err)
    io_end_time = MPI_WTIME()
    io_total_time = io_end_time - io_start_time
    sz = io_size * nproc/1024.d0/1024.d0/1024.d0 !size in GB
    gbs = sz/io_total_time
    if (rank==0) print '("Step ",i3,": ",a20,d12.2,2x,d12.2,2x,d12.3)', &
        tstep,filename,sz,io_total_time,gbs
end subroutine io_write

end module heat_io


