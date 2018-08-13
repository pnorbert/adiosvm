MODULE BRUSSELATOR_IO
    use mpi
    use decomp_2d
    use adios2
    public 

    integer*8, dimension(3) :: sizes, subsizes, starts
    type(adios2_adios)      :: adios2_handle
    type(adios2_io)         :: ad_io
    type(adios2_engine)     :: ad_engine
    type(adios2_variable)   :: var_xcoords, var_ycoords, var_zcoords
    type(adios2_variable)   :: var_plotnum, var_u_r, var_u_i, var_v_r, var_v_i
    type(adios2_operator)   :: ad_operator
    integer                 :: operation_id
    logical                 :: adios2_initialized

    CONTAINS

    !----------------------------------------------------------------------------!
    SUBROUTINE io_init (fname,decomp, nx, ny, nz, compression_method, &
                        compression_param_key, compression_param_value, ierr)
    !----------------------------------------------------------------------------!
        implicit none

        character*(*), intent(in)       :: fname
        type(decomp_info), intent(in)   :: decomp
        integer, intent(in)             :: nx, ny, nz
        CHARACTER(len=15)               :: compression_method, &
                                           compression_param_key, &
                                           compression_param_value
        integer, intent(out)            :: ierr

        ierr = 0
        ! Code for getting sizes, subsizes, and starts copied from 2decomp_fft
        ! determine subarray parameters
        sizes(1) = decomp%xsz(1)
        sizes(2) = decomp%ysz(2)
        sizes(3) = decomp%zsz(3)

        subsizes(1) = decomp%xsz(1)
        subsizes(2) = decomp%xsz(2)
        subsizes(3) = decomp%xsz(3)
        starts(1) = decomp%xst(1)-1  ! 0-based index
        starts(2) = decomp%xst(2)-1
        starts(3) = decomp%xst(3)-1

#ifdef ADIOS2
        ! Init adios2
        call adios2_init_config (adios2_handle, "adios2_config.xml", mpi_comm_world, &
            adios2_debug_mode_on, ierr)

        ! Init IO object
        call adios2_declare_io (ad_io, adios2_handle, "SimulationOutput", ierr)

        ! Define variables

        ! Coordinates x, y, z
        call adios2_define_variable (var_xcoords, ad_io, "x_coord", adios2_type_dp, 1, &
            1_8 * (/ nx /), 1_8 * (/ 0 /), 1_8 * (/ nx /), .true., ierr)
        call adios2_define_variable (var_ycoords, ad_io, "y_coord", adios2_type_dp, 1, &
            1_8 * (/ ny /), 1_8 * (/ 0 /), 1_8 * (/ ny /), .true., ierr)
        call adios2_define_variable (var_zcoords, ad_io, "z_coord", adios2_type_dp, 1, &
            1_8 * (/ nz /), 1_8 * (/ 0 /), 1_8 * (/ nz /), .true., ierr)

        ! Per-timestep data - plotnum, u, v
        call adios2_define_variable (var_plotnum, ad_io, "plotnum", adios2_type_integer4, ierr)
        call adios2_define_variable (var_u_r, ad_io, "u_real", adios2_type_dp, 3, &
            sizes, starts, subsizes, .true., ierr)
        call adios2_define_variable (var_u_i, ad_io, "u_imag", adios2_type_dp, 3, &
            sizes, starts, subsizes, .true., ierr)
        call adios2_define_variable (var_v_r, ad_io, "v_real", adios2_type_dp, 3, &
            sizes, starts, subsizes, .true., ierr)
        call adios2_define_variable (var_v_i, ad_io, "v_imag", adios2_type_dp, 3, &
            sizes, starts, subsizes, .true., ierr)

        if( compression_method /= '' .or. compression_method /= 'none' )
            call adios2_define_operator(ad_operator, adios, 'Compressor', &
                                        compression_method, ierr)
        end if

        if( ad_operator%valid .eqv. .true. ) then
            call adios2_add_operation(operation_id, var_u_r, ad_operator, &
                                      compression_param_key, &
                                      compression_param_value, ierr)
            call adios2_add_operation(operation_id, var_u_i, ad_operator, &
                                      compression_param_key, &
                                      compression_param_value, ierr)
            call adios2_add_operation(operation_id, var_v_r, ad_operator, &
                                      compression_param_key, &
                                      compression_param_value, ierr)
            call adios2_add_operation(operation_id, var_v_i, ad_operator, &
                                      compression_param_key, &
                                      compression_param_value, ierr)
        end if

        ! Open file
        call adios2_open (ad_engine, ad_io, fname, adios2_mode_write, &
            mpi_comm_world, ierr)
#endif
    end subroutine io_init


    !----------------------------------------------------------------------------!
    SUBROUTINE write_coordinates (xcoords, ycoords, zcoords)
    !----------------------------------------------------------------------------!
        ! This routine is called once, by the root process.
        implicit none

        real(kind=8), intent(in)    :: xcoords(:), ycoords(:), zcoords(:)
        integer                     :: ierr

        call adios2_put (ad_engine, var_xcoords, xcoords, adios2_mode_sync, ierr)
        call adios2_put (ad_engine, var_ycoords, ycoords, adios2_mode_sync, ierr)
        call adios2_put (ad_engine, var_zcoords, zcoords, adios2_mode_sync, ierr)

    END SUBROUTINE write_coordinates
    !----------------------------------------------------------------------------!


    !----------------------------------------------------------------------------!
    SUBROUTINE savedata(Nx,Ny,Nz,plotnum,name,field,u,v,decomp)
    !----------------------------------------------------------------------------!
        !--------------------------------------------------------------------
        !
        !
        ! PURPOSE
        !
        ! This subroutine saves a three dimensional real array in binary 
        ! format
        !
        ! INPUT
        !
        ! .. Scalars ..
        !  Nx				= number of modes in x - power of 2 for FFT
        !  Ny				= number of modes in y - power of 2 for FFT
        !  Nz				= number of modes in z - power of 2 for FFT
        !  plotnum			= number of plot to be made
        ! .. Arrays ..
        !  field 			= real data to be saved
        !  name_config		= root of filename to save to 
        !
        ! .. Output	..	
        ! plotnum			= number of plot to be saved
        ! .. Special Structures ..
        !  decomp			= contains information on domain decomposition
        !					see http://www.2decomp.org/ for more information
        ! LOCAL VARIABLES
        !
        ! .. Scalars ..
        !  i				= loop counter in x direction
        !  j				= loop counter in y direction
        !  k				= loop counter in z direction
        !  count			= counter
        !  iol				= size of file
        ! .. Arrays ..
        ! 	number_file		= array to hold the number of the plot
        !
        ! REFERENCES
        !
        ! ACKNOWLEDGEMENTS
        !
        ! ACCURACY
        !		
        ! ERROR INDICATORS AND WARNINGS
        !
        ! FURTHER COMMENTS
        !--------------------------------------------------------------------
        ! External routines required
        ! 
        ! External libraries required
        ! 2DECOMP&FFT	 -- Domain decomposition and Fast Fourier Library
        !			(http://www.2decomp.org/index.html)
        ! MPI library
        USE decomp_2d
        USE decomp_2d_fft
        USE decomp_2d_io
        IMPLICIT NONE					 
        INCLUDE 'mpif.h'
        ! Declare variables
        INTEGER(KIND=4), INTENT(IN)						:: Nx,Ny,Nz
        INTEGER(KIND=4), INTENT(IN)						:: plotnum
        TYPE(DECOMP_INFO), INTENT(IN)					::  decomp
        REAL(KIND=8), DIMENSION(decomp%xst(1):decomp%xen(1),&
            decomp%xst(2):decomp%xen(2),&
            decomp%xst(3):decomp%xen(3)), &
            INTENT(INOUT) :: field
        COMPLEX(KIND=8), DIMENSION(decomp%xst(1):decomp%xen(1),&
            decomp%xst(2):decomp%xen(2),&
            decomp%xst(3):decomp%xen(3)), &
            INTENT(IN) :: u,v
        CHARACTER*100, INTENT(IN)	     				:: name
        CHARACTER*100               					:: name_config
        INTEGER(kind=4)									:: i,j,k,iol,count,ind
        CHARACTER*100									:: number_file
        integer                                         :: ierr, myrank
    
    
        ! create character array with full filename
        ! write out using 2DECOMP&FFT MPI-IO routines

        ! Write U real
        ind=index(name,' ') -1
        name_config=name(1:ind)//'u'
        DO k=decomp%xst(3),decomp%xen(3); DO j=decomp%xst(2),decomp%xen(2); DO i=decomp%xst(1),decomp%xen(1)
        field(i,j,k)=REAL(u(i,j,k))
        END DO; END DO; END DO

#ifdef ADIOS2
        call mpi_comm_rank (mpi_comm_world, myrank, ierr)
        call adios2_begin_step (ad_engine, ierr)
        !if (myrank .eq. 0) call adios2_put (ad_engine, var_plotnum, plotnum, adios2_mode_sync, ierr)
        call adios2_put (ad_engine, var_plotnum, plotnum, adios2_mode_sync, ierr)
        call adios2_put (ad_engine, var_u_r, field, adios2_mode_sync, ierr)
#else
        ind = index(name_config,' ') - 1
        WRITE(number_file,'(i0)') plotnum
        number_file = name_config(1:ind)//number_file
        ind = index(number_file,' ') - 1
        number_file = number_file(1:ind)//'.datbin'	
        CALL decomp_2d_write_one(1,field,number_file, decomp)
#endif
    
        ! Write V real
        ind=index(name,' ') -1
        name_config=name(1:ind)//'v'
        DO k=decomp%xst(3),decomp%xen(3); DO j=decomp%xst(2),decomp%xen(2); DO i=decomp%xst(1),decomp%xen(1)
        field(i,j,k)=REAL(v(i,j,k))
        END DO; END DO; END DO

#ifdef ADIOS2
        call adios2_put (ad_engine, var_v_r, field, adios2_mode_sync, ierr)
#else
        ind = index(name_config,' ') - 1
        WRITE(number_file,'(i0)') plotnum
        number_file = name_config(1:ind)//number_file
        ind = index(number_file,' ') - 1
        number_file = number_file(1:ind)//'.datbin'	
        CALL decomp_2d_write_one(1,field,number_file, decomp)
#endif

        ! Write U imag and V imag - Not in the original Brusselator code

#ifdef ADIOS2
        ! Write U imag
        DO k=decomp%xst(3),decomp%xen(3); DO j=decomp%xst(2),decomp%xen(2); DO i=decomp%xst(1),decomp%xen(1)
        field(i,j,k)=AIMAG(u(i,j,k))
        END DO; END DO; END DO

        call adios2_put (ad_engine, var_u_i, field, adios2_mode_sync, ierr)

        ! Write V imag
        DO k=decomp%xst(3),decomp%xen(3); DO j=decomp%xst(2),decomp%xen(2); DO i=decomp%xst(1),decomp%xen(1)
        field(i,j,k)=AIMAG(v(i,j,k))
        END DO; END DO; END DO

        call adios2_put (ad_engine, var_v_i, field, adios2_mode_sync, ierr)
        call adios2_end_step (ad_engine, ierr)
#endif
    END SUBROUTINE savedata
    
    
    !----------------------------------------------------------------------------!
    SUBROUTINE IO_FINALIZE(ierr)
    !----------------------------------------------------------------------------!
        implicit none
    
        integer, intent(out) :: ierr

#ifdef ADIOS2
        call adios2_close    (ad_engine, ierr)
        call adios2_finalize (adios2_handle, ierr)
#endif
    
    END SUBROUTINE IO_FINALIZE

END MODULE BRUSSELATOR_IO

