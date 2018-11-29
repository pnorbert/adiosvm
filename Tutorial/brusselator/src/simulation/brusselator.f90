!--------------------------------------------------------------------
!
!
! PURPOSE
!
! This program solves Brusselator equations in 3 dimensions
! u_t = a + u^2v - (b+1)u + Du (u_{xx} + u_{yy} + u_{zz})
! v_t = bu - u^2v + Dv (v_{xx} + v_{yy} + v_{zz})
!
! .. Parameters ..
!  Nx       = number of modes in x - power of 2 for FFT
!  Ny       = number of modes in y - power of 2 for FFT
!  Nz       = number of modes in z - power of 2 for FFT
!  Nt       = number of timesteps to take
!  Tmax       = maximum simulation time
!  plotgap      = number of timesteps between plots
!  pi = 3.14159265358979323846264338327950288419716939937510d0
!  Lx       = width of box in x direction
!  Ly       = width of box in y direction
!  Lz       = width of box in z direction
!  tol        =max error each timestep
! .. Scalars ..
!  pp       = order of the splitting method
!  i        = loop counter in x direction
!  j        = loop counter in y direction
!  k        = loop counter in z direction
!  n        = loop counter for timesteps direction
!  allocatestatus = error indicator during allocation
!  start      = variable to record start time of program
!  finish     = variable to record end time of program
!  count_rate   = variable for clock count rate
!  dt       = timestep
!  modescalereal  = Number to scale after backward FFT
!  myid       = Process id
!  ierr       = error code
!  p_row      = number of rows for domain decomposition
!  p_col      = number of columns for domain decomposition
!  plotnum      = number of plot to save
!  stat       = error indicator when reading inputfile
! .. Arrays ..
!  uhigh      = approximate solution u higher order
!  vhigh      = approximate solution v higher order
!  ulow       = approximate solution u lower order
!  vlow       = approximate solution v lower order
!  uhat       = Fourier transform of u
!  vhat       = Fourier transform of v
!  savearray      = stores the realpart to save the data
! .. Vectors ..
!  kx       = fourier frequencies in x direction squared
!  ky       = fourier frequencies in y direction squared
!  kz       = fourier frequencies in z direction squared
!  x        = x locations
!  y        = y locations
!  z        = z locations
!  time       = times at which save data
!  nameconfig   = array to store filename for data to be saved
!  dpcomm
!  intcomm
! .. Special Structures ..
!  decomp     = contains information on domain decomposition
!  sp       see http://www.2decomp.org/ for more information
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
! Check that the initial iterate is consistent with the
! boundary conditions for the domain specified
!--------------------------------------------------------------------
! External routines required
!
! External libraries required
! 2DECOMP&FFT  -- Domain decomposition and Fast Fourier Library
!     (http://www.2decomp.org/index.html)
! MPI library

PROGRAM main
    USE decomp_2d
    USE decomp_2d_fft
    USE decomp_2d_io
    USE BRUSSELATOR_IO
    USE MPI
    IMPLICIT NONE
    INTEGER(kind=4)                                 ::  Nx=64
    INTEGER(kind=4)                                 ::  Ny=64
    INTEGER(kind=4)                                 ::  Nz=64
    INTEGER(kind=4)                                 ::  nmax=10000000
    REAL(kind=8)                                    ::  Tmax=60.0
    INTEGER(kind=4)                                 ::  plotgap
    REAL(kind=8), PARAMETER                         ::  pi=3.14159265358979323846264338327950288419716939937510d0
    REAL(kind=8), PARAMETER                         ::  Lx=1.0,Ly=1.0,Lz=1.0

    !equation specific
    REAL(kind=8), PARAMETER                         ::  a=2.0d0
    REAL(kind=8), PARAMETER                         ::  b=18.20d0
    REAL(kind=8), PARAMETER                         ::  Du=0.050d0
    REAL(kind=8), PARAMETER                         ::  Dv=0.050d0
    REAL(kind=8)                                    ::  dt=0.1**3
    REAL(kind=8)                                    ::  plottime=0.0
    INTEGER(kind=4)                                 ::  plotnum=0
    COMPLEX(kind=8)                                 ::  utemp, vtemp, uhatemp
    COMPLEX(kind=8),  DIMENSION(:),     ALLOCATABLE ::  kx,ky,kz
    REAL(kind=8),     DIMENSION(:),     ALLOCATABLE ::  x,y,z
    COMPLEX(kind=8),  DIMENSION(:,:,:), ALLOCATABLE ::  uhigh,vhigh
    REAL(kind=8),     DIMENSION(:,:,:), ALLOCATABLE ::  savefield
    COMPLEX(kind=8),  DIMENSION(:,:,:), ALLOCATABLE ::  uhat,vhat
    REAL(kind=8),     DIMENSION(:),     ALLOCATABLE ::  time
    real(kind=8),     DIMENSION(:),     ALLOCATABLE ::  xcoords, ycoords, zcoords
    REAL(kind=8)                                    ::  modescalereal, myerr,allerr,mymaxv,mymaxu,maxu,maxv
    INTEGER(kind=4)                                 ::  i,j,k,l,n,m,mm,ll,AllocateStatus,stat
    INTEGER(kind=4)                                 ::  wid,myid,numprocs,ierr,comm,color=1
    TYPE(DECOMP_INFO)                               ::  decomp
    INTEGER(kind=4)                                 ::  p_row=0, p_col=0
    INTEGER(kind=4)                                 ::  start, finish,  starttot, finishtot, count_rate, ind
    CHARACTER*500                                   ::  nameconfig
    CHARACTER*200                                   ::  numberfile
    character(len=100)                              ::  fname

    ! splitting coeffiecents
    COMPLEX(kind=8), DIMENSION(1:6), PARAMETER  ::  aa=(/&
        CMPLX(0.0442100822731214759d0 , -0.0713885293035937610d0,8),&
        CMPLX(0.157419072651724312d0  , -0.1552628290245811054d0,8),&
        CMPLX(0.260637333463417766d0  ,  0.0774417252676963806d0,8),&
        CMPLX(0.059274548196998816d0  , +0.354231218126596507d0,8),&
        CMPLX(0.353043498499040389d0  , +0.0768951336684972038d0,8),&
        CMPLX(0.125415464915697242d0  , -0.281916718734615225d0,8)/)
    COMPLEX(kind=8), DIMENSION(1:6), PARAMETER  ::  bb=(/&
        CMPLX(0.0973753110633760585d0 , -0.112390152630243038d0,8),&
        CMPLX(0.179226865237094561d0  , -0.0934263750859694959d0,8),&
        CMPLX(0.223397823699529381d0  , +0.205816527716212533d0,8),&
        CMPLX(0.223397823699529381d0  , +0.205816527716212533d0,8),&
        CMPLX(0.179226865237094561d0  , -0.0934263750859694959d0,8),&
        CMPLX(0.0973753110633760585d0 , -0.112390152630243038d0,8)/)
    COMPLEX(kind=8), DIMENSION(1:6), PARAMETER  ::  cc=(/&
        CMPLX(0.125415464915697242d0 , -0.281916718734615225d0,8),&
        CMPLX(0.353043498499040389d0 , +0.0768951336684972038d0,8),&
        CMPLX(0.059274548196998816d0 , +0.354231218126596507d0,8),&
        CMPLX(0.260637333463417766d0 , +0.0774417252676963806d0,8),&
        CMPLX(0.157419072651724312d0 , -0.1552628290245811054d0,8),&
        CMPLX(0.0442100822731214759d0 ,-0.0713885293035937610d0,8)/)
    INTEGER(kind=4)   ::  pp=3
    INTEGER(kind=4)   ::  ss=6

    plottime=plotgap
    ! initialisation of MPI
    CALL system_clock(starttot,count_rate)
    CALL MPI_INIT(ierr)
    CALL MPI_COMM_RANK(MPI_COMM_WORLD, wid, ierr)
    CALL MPI_COMM_SPLIT(MPI_COMM_WORLD, color, wid, comm, ierr)

    CALL MPI_COMM_SIZE(comm, numprocs, ierr)
    CALL MPI_COMM_RANK(comm, myid, ierr)

    CALL processArgs(fname,Nx,Ny,Nz,nmax,plotgap,comm)
    if (plotgap .eq. 0) then
      if (myid .eq. 0) print *, "plotgap cannot be 0"
      call MPI_Abort(MPI_COMM_WORLD, -1, ierr)
    endif
    if(myid.eq.0) write(6,*) 'Information: ',trim(fname),Nx,Ny,Nz,nmax,plotgap

    CALL decomp_2d_init(Nx,Ny,Nz,p_row,p_col,comm)
    ! get information about domain decomposition choosen
    CALL decomp_info_init(Nx,Ny,Nz,decomp) ! physical domain
    ! initialise FFT library
    CALL decomp_2d_fft_init

    CALL io_init (fname,decomp, nx, ny, nz, comm, ierr)

    ALLOCATE(Uhigh(decomp%xst(1):decomp%xen(1),&
        decomp%xst(2):decomp%xen(2),&
        decomp%xst(3):decomp%xen(3)),&
        Vhigh(decomp%xst(1):decomp%xen(1),&
        decomp%xst(2):decomp%xen(2),&
        decomp%xst(3):decomp%xen(3)),&
        uhat(decomp%zst(1):decomp%zen(1),&
        decomp%zst(2):decomp%zen(2),&
        decomp%zst(3):decomp%zen(3)),&
        vhat(decomp%zst(1):decomp%zen(1),&
        decomp%zst(2):decomp%zen(2),&
        decomp%zst(3):decomp%zen(3)),&
        savefield(decomp%xst(1):decomp%xen(1),&
        decomp%xst(2):decomp%xen(2),&
        decomp%xst(3):decomp%xen(3)),&
        kx(decomp%zst(1):decomp%zen(1)), &
        ky(decomp%zst(2):decomp%zen(2)), &
        kz(decomp%zst(3):decomp%zen(3)), &
        x(decomp%xst(1):decomp%xen(1)),&
        y(decomp%xst(2):decomp%xen(2)),&
        z(decomp%xst(3):decomp%xen(3)),&
        time(1:nmax),&
        stat=AllocateStatus)
    IF (AllocateStatus .ne. 0) then
      print *, "Could not allocate memory. Terminating .."
      STOP
    ENDIF

    ! Allocate memory for coordinates
    IF (myid.eq.0) then
      ALLOCATE (xcoords(Nx),ycoords(Ny),zcoords(Nz),&
        stat=AllocateStatus)
      IF (AllocateStatus .ne. 0) then
        print *, "Could not allocate memory for coordinates on the root process. Terminating .."
        STOP
      ENDIF
    ENDIF

    IF (myid.eq.0) THEN
        PRINT *,'allocated space'
    END IF
    CALL MPI_BARRIER(comm,ierr)
    modescalereal=1.0d0/REAL(Nx,KIND(0d0))
    modescalereal=modescalereal/REAL(Ny,KIND(0d0))
    modescalereal=modescalereal/REAL(Nz,KIND(0d0))
    ! setup fourier frequencies and grid points
    CALL getgrid(myid,Nx,Ny,Nz,Lx,Ly,Lz,pi,fname,x,y,z,kx,ky,kz,decomp,xcoords,ycoords,zcoords)
    IF (myid.eq.0) THEN
        PRINT *,'Setup grid and fourier frequencies'
    END IF

    !initial condition
    CALL MPI_BARRIER(comm,ierr)
    CALL initialdata(Nx,Ny,Nz,x,y,z,uhigh,vhigh,decomp)
    n=1
    time(n)=0.0
    plotnum=10000000
    !Write initial data to disc
!    CALL savedata(Nx,Ny,Nz,plotnum,fname,savefield,uhigh,vhigh,decomp,n,xcoords,ycoords,zcoords)

    ! Free memory used by coordinates
    if (myid .eq. 0) then
      deallocate(xcoords)
      deallocate(ycoords)
      deallocate(zcoords)
    endif

    IF (myid.eq.0) THEN
        PRINT *,'Got initial data, starting timestepping'
    END IF
    CALL system_clock(start,count_rate)
    !main loop
    DO WHILE ((n<nmax))
        n=n+1
        DO l=1,ss
          ! Solve first nonlinear part
          CALL nonlinear1(dt,aa(l),uhigh,vhigh,decomp)
          ! Solve second nonlinear part
          CALL nonlinear2(dt,bb(l),uhigh,vhigh,decomp)
          ! solve linear part exactly in Fourier space
          CALL linear(a,b,Du,Dv,dt,modescalereal,cc(l),kx,ky,kz,uhigh,vhigh,uhat,vhat,decomp)
          !end loop on stages for splitting method indexed by l
        END DO
        time(n)=time(n-1)+dt

        !write data
        if (mod(n,plotgap) .eq. 0) then
        !IF (time(n).ge.plottime) THEN
            plotnum=plotnum+1
            plottime=plottime+plotgap
            IF (myid.eq.0) THEN
                PRINT *,'time',time(n),', n',n,', plot',plotnum
            END IF
            CALL savedata(Nx,Ny,Nz,plotnum,fname,savefield,uhigh,vhigh,decomp,n)
            ! If time greater than plotting time
        END IF
    END DO  !timestepping

    !last data output
    plotnum=plotnum+1
    plottime=plottime+plotgap
    IF ((myid.eq.0).and.(n.eq.nmax)) THEN
        PRINT *,'time',time(n),'n',n,'plot',plotnum
    END IF
    CALL savedata(Nx,Ny,Nz,plotnum,fname,savefield,uhigh,vhigh,decomp,n)
    CALL system_clock(finish,count_rate)
    IF (myid.eq.0) THEN
        PRINT *,'Finished time stepping steps:', n
        PRINT*,'Program took ',REAL(finish-start)/REAL(count_rate),'for time stepping', &
            REAL(finish-start)/REAL(count_rate)*numprocs
    END IF
    CALL MPI_BARRIER(comm,ierr)
    ! clean up
    CALL decomp_2d_fft_finalize
    CALL decomp_2d_finalize
    DEALLOCATE(uhigh,vhigh,&
        uhat,vhat,&
        kx,ky,x,y,savefield,&
        time,stat=AllocateStatus)
    IF (AllocateStatus .ne. 0) STOP

    IF (myid.eq.0) THEN
        PRINT *,'Program execution complete'
    END IF

    CALL IO_FINALIZE(ierr)
    CALL MPI_FINALIZE(ierr)
    CALL system_clock(finishtot,count_rate)
    IF (myid.eq.0) THEN
        PRINT*,'Program took total',REAL(finishtot-starttot)/REAL(count_rate),'for execution', &
            REAL(finishtot-starttot)/REAL(count_rate)*numprocs
    END IF
END PROGRAM main

!!***************************
subroutine usage(comm)
    use mpi
    implicit none
    integer :: rank, ierr, comm
    call MPI_Comm_rank(comm, rank, ierr)

    if (rank .eq. 0) then
        print *, "Usage: brusselator  output  nx  ny nz  steps plotgap"
        print *, "output: name of output file"
        print *, "nx:       global array size in X dimension per processor (power of 2 for FFT)"
        print *, "ny:       global array size in Y dimension per processor (power of 2 for FFT)"
        print *, "nz:       global array size in Z dimension per processor (power of 2 for FFT)"
        print *, "steps:    the total number of steps"
        print *, "plotgap:  frequency of output (no. of steps between output)"
    endif
end subroutine usage

!!***************************
subroutine processArgs(fname,nx,ny,nz,nmax,plotgap,comm)
    use mpi
    implicit none
#ifndef __GFORTRAN__
#ifndef __GNUC__
    interface
         integer function iargc()
         end function iargc
    end interface
#endif
#endif
    character(len=256) :: npx_str, npy_str, npz_str
    character(len=256) :: steps_str,iters_str,nmax_str, plotgap_str
    integer :: numargs
    integer :: nx,ny,nz
    integer :: nmax, ierr
    integer(kind=4) :: plotgap
    character*(*) :: fname
    integer       :: myrank
    integer       :: comm

    ierr = 0
    call MPI_Comm_rank (comm, myrank, ierr)

    !! process arguments
    numargs = iargc()
    !print *,"Number of arguments:",numargs
    if ( numargs < 6 ) then
        call usage(comm)
        CALL MPI_BARRIER(comm,ierr)
        call MPI_Abort(MPI_COMM_WORLD, -1, ierr)
        !call exit(1)
    endif
    call getarg(1, fname)
    call getarg(2, npx_str)
    call getarg(3, npy_str)
    call getarg(4, npz_str)
    call getarg(5, nmax_str)
    call getarg(6, plotgap_str)
!    call getarg(6, iters_str)
    read (npx_str,'(i5)') nx
    read (npy_str,'(i5)') ny
    read (npz_str,'(i6)') nz
    read (nmax_str,'(i6)') nmax
    read (plotgap_str,'(i6)', iostat=ierr) plotgap
    if (ierr.ne. 0) then
      if (myrank.eq.0)then
        print *, "ERROR: Incorrect value found for plotgap."
        print *, "Must be an integer, instead found ", trim(plotgap_str)
        print *, "The definition of plotgap was changed recently."
        print *, "It now represents output frequency, that is, the no. of timesteps between outputs."
        print *, "Previously, it was the time gap in seconds between outputs."
      endif
      CALL MPI_BARRIER(comm,ierr)
      call MPI_Abort(MPI_COMM_WORLD, -1, ierr)
    endif
!    read (steps_str,'(i6)') steps
!    read (iters_str,'(i6)') iters
end subroutine processArgs

