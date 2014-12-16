
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
    !integer*8, dimension(1:2) :: dims !local chunk
    integer*8, dimension(1:2) :: global_dims
    integer*8, dimension(1:2) :: offsets 

    INTEGER(HSIZE_T),  DIMENSION(2) :: count  
    INTEGER(HSSIZE_T), DIMENSION(2) :: offset 
    INTEGER(HSIZE_T),  DIMENSION(2) :: stride
    INTEGER(HSIZE_T),  DIMENSION(2) :: dims 


    integer*8 io_size

    INTEGER(HID_T) :: file_id
    INTEGER(HID_T) :: dset_id
    INTEGER(HID_T) :: dspace_id
    INTEGER(HID_T) :: memspace
    INTEGER(HID_T) :: plist_id

    INTEGER :: comm, info

    character (len=200) :: filename
    character(2) :: mode = "w"

    comm = MPI_COMM_WORLD
    info = MPI_INFO_NULL

    write(filename,'(a,".h5")') trim(outputfile)
    print '("rank ",i0," writes to: ",a)', rank, trim(filename)

    call MPI_BARRIER(app_comm, err)
    io_start_time = MPI_WTIME()

    ndims = 2
    dims(1) = ndx
    dims(2) = ndy

    global_dims(1) = gndx 
    global_dims(2) = gndy

    offset(1) = offx
    offset(2) = offy

    stride(1) = 1 
    stride(2) = 1 
    count(1) =  1 
    count(2) =  1

    io_size = 11*4 + 2*8*ndx*ndy 


    IF (tstep == 0) THEN

        call h5pcreate_f(H5P_FILE_ACCESS_F, plist_id, err)
        call h5pset_fapl_mpio_f(plist_id, comm, info, err)

        call h5fcreate_f (filename, H5F_ACC_TRUNC_F, file_id, err, access_prp = plist_id)
        call h5pclose_f(plist_id, err)

        call h5screate_simple_f(ndims, global_dims, dspace_id, err)
        call h5screate_simple_f(ndims, dims, memspace, err)

        call h5pcreate_f(H5P_DATASET_CREATE_F, plist_id, err)
        call h5pset_chunk_f(plist_id, ndims, dims, err)
        call h5dcreate_f(file_id, "T", H5T_NATIVE_DOUBLE, dspace_id, &
                     dset_id, err, plist_id)
        call h5sclose_f(dspace_id, err)

        call h5dget_space_f(dset_id, dspace_id, err)
        call h5sselect_hyperslab_f (dspace_id, H5S_SELECT_SET_F, &
                                    offsets, count, err, &
                                    stride, dims)

        call h5pcreate_f(H5P_DATASET_XFER_F, plist_id, err) 
        call h5pset_dxpl_mpio_f(plist_id, H5FD_MPIO_COLLECTIVE_F, err)

        call h5dwrite_f(dset_id, H5T_NATIVE_DOUBLE, T(1:ndx,1:ndy,curr), &
                        global_dims, err, &
                        file_space_id = dspace_id, mem_space_id = memspace, &
                        xfer_prp = plist_id)

        ! close hdf5 objects
        call h5pclose_f(plist_id, err)
        call h5dclose_f(dset_id, err)
        call h5sclose_f(dspace_id, err)
        call h5sclose_f(memspace, err)
        call h5fclose_f(file_id, err)

    END IF

    call MPI_BARRIER(app_comm ,err)
    io_end_time = MPI_WTIME()
    io_total_time = io_end_time - io_start_time
    sz = io_size * nproc/1024.d0/1024.d0/1024.d0 !size in GB
    gbs = sz/io_total_time
    if (rank==0) print '("Step ",i3,": ",a20,d12.2,2x,d12.2,2x,d12.3)', &
        tstep,filename,sz,io_total_time,gbs
end subroutine io_write

end module heat_io


