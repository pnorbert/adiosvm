
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
    integer*8, dimension(3) :: dims
    integer*8, dimension(3) :: localdims
    integer*8, dimension(3) :: maxdims
    integer*8, dimension(3) :: offset 

    integer*8 io_size

    INTEGER(HID_T) :: file_id
    INTEGER(HID_T) :: dset_id
    INTEGER(HID_T) :: dspace_id
    INTEGER(HID_T) :: crp_list  ! creation properties
    INTEGER(HID_T) :: memspace
    INTEGER(HID_T) :: dataspace

    character (len=200) :: filename
    character(2) :: mode = "w"


    write(filename,'(a,".",i3.3,".h5")') trim(outputfile), rank
    print '("rank ",i0," writes to: ",a)', rank, trim(filename)

    call MPI_BARRIER(app_comm, err)
    io_start_time = MPI_WTIME()

    ndims =3

    !dims will adjust to the size of the dataset
    dims(1) = ndx
    dims(2) = ndy
    dims(3) = 1

    !localdims will stay fixed at the size of one timestep
    localdims(1) = ndx
    localdims(2) = ndy
    localdims(3) = 1

    !maxdims indicates that d3 is extensible
    maxdims(1) = ndx
    maxdims(2) = ndy
    maxdims(3) = H5S_UNLIMITED_F

    offset(1) = 0
    offset(2) = 0
    offset(3) = 0

    io_size = 11*4 + 2*8*ndx*ndy 

    IF (tstep > 0) THEN
        ! subsequent timestep, open existing file and dataset
        call h5fopen_f(filename, H5F_ACC_RDWR_F, file_id, err)
        call h5dopen_f(file_id, "T", dset_id, err)

        ! extend the dataset to allow for new timestep
        dims(3) = tstep + 1
        call h5dset_extent_f(dset_id, dims, err)

        call h5screate_simple_f (ndims, localdims, memspace, err)

        offset(3) = tstep

        call h5dget_space_f(dset_id, dataspace, err)
        call h5sselect_hyperslab_f(dataspace, H5S_SELECT_SET_F, &
                                   offset, localdims, err)

        ! Write current state
        call h5dwrite_f(dset_id, H5T_NATIVE_DOUBLE, T(1:ndx,1:ndy,curr), &
                        localdims, err, memspace, dataspace)

        ! close dataset
        call h5dclose_f(dset_id, err)

    ELSE
        ! first timestep, need to create file and dataset
        call h5fcreate_f (filename, H5F_ACC_TRUNC_F, file_id, err)
        
        ! create a dataspace to define shape of dataset
        call h5screate_simple_f(ndims, dims, dspace_id, err, maxdims) 

        ! enable chunking to allow growing the dataset
        call h5pcreate_f(H5P_DATASET_CREATE_F, crp_list, err)
        call h5pset_chunk_f(crp_list, ndims, dims, err)


        !create the dataset
        call h5dcreate_f(file_id, "T", H5T_NATIVE_DOUBLE, dspace_id, &
                         dset_id, err, crp_list)


        ! Write current state
        call h5dwrite_f(dset_id, H5T_NATIVE_DOUBLE, T(1:ndx,1:ndy,curr), &
                        dims, err)

        ! close dataset
        call h5dclose_f(dset_id, err)

        ! close dataspace
        call h5sclose_f(dspace_id, err)
        call h5pclose_f(crp_list, err)
    END IF

    ! close file
    call h5fclose_f(file_id, err)

    call MPI_BARRIER(app_comm ,err)

! I think the throughput numbers are based on the size of a single
! timestep (io_size), and may need to be adjusted for multiple timesteps

    io_end_time = MPI_WTIME()
    io_total_time = io_end_time - io_start_time
    sz = io_size * nproc/1024.d0/1024.d0/1024.d0 !size in GB
    gbs = sz/io_total_time
    if (rank==0) print '("Step ",i3,": ",a20,d12.2,2x,d12.2,2x,d12.3)', &
        tstep,filename,sz,io_total_time,gbs
end subroutine io_write

end module heat_io


