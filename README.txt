diosvm
=======

Packages and howtos for creating a linux system for ADIOS tutorials

Required steps to get plain ADIOS working: I.1-6,8 II.1,4 III.1

Steps:

I. Set up a Linux VM
====================

1. Install VirtualBox 

2. Get a linux ISO image
   We currently use Lubuntu 16.04 64bit and the descriptions below all refer to that system. Debian based systems use 'apt-get' to install packages. 


3. Create a new VM
   Type=Linux, System=Ubuntu (32bit)
   Memory: at least 2048MB, we use 3072MB just for the sake of it
   Virtual hard drive: VMDK type, dynamically allocated, about 16GB
      - the more the better, but an exported images should fit on an USB stick...
   Video memory: 64MB - we don't really know how much is needed
      - do not enable 2D video or 3D acceleration
   Processor: 2 CPUs 
      - 1 is enough, 2 builds codes faster
   Storage: load the linux iso image into the DVD drive. 


   - Start the VM and install linux, preferably with updates. 
    Your name: ADIOS
    Your computer's nane: adiosVM
    Username: adios
    password: adios 
    Log in automatically: yes, because this is a tutorial vm

    Note: if you use a computer name other than adiosVM, make sure you substitute for the name
    everywhere in this document (e.g. Flexpath install)

   - Instead of restart, shut down and remove the linux DVD, start again

   Whenever Lubuntu offers updates, do it...

4. LXTerminal: Bottom left corner of screen has the start menu, open System Tools/LXTerminal
   - LXTerminal setup (if you don't like the default one)
     - Start LXTerminal
     - Edit/Profile preferences
     - Display tab: increase the scrollback to a few thousand lines (e.g. 5120)
     - Style tab: set font and background/foreground to your style
       (Monospace 12 and black font on white background for the tutorial VM)

   - Add terminal icon to task bar: right-click on task bar, select Add/Remove Panel Items
     Select Application Launch Bar, click Preferences
     Add System Tools/LXTerminal to the Launchers list

5. Virtualbox Guest Additions
   $ sudo apt-get update
   $ sudo apt-get install dkms 
     - Dynamic Kernel Modules, to ensure rebuilding Guest Additions at future kernel updates
     - or just reinstall Guest Additions each time if you don't want dkms installed

   - VirtualBox VM menu: Devices/Insert Guest Additions CD Image
     - under Lubuntu it will not autorun, so in a terminal
     $ cd /media/adios/VBOXADDITIONS*/
     $ sudo ./VBoxLinuxAdditions.run

     - this allows for resizing the window and 
       for copy/paste between the VM and your host machine
       (and sharing folders between your host machine and this VM if you want)
     - set in VirtualBox main menu:  Devices/Shared Clipboard/Bidirectional)
     Note: This has to be repeated when updating or recompiling the kernel unless 
           the dkms package is installed
     - reboot the machine

6. Install some linux packages (sudo apt-get install or can use sudo synaptic)
   $ sudo apt-get install apt-file 
   $ sudo apt-file update
   $ sudo apt-get install build-essential git-core libtool libtool-bin autoconf subversion cmake
   $ sudo apt-get install gfortran 
   $ sudo apt-get install pkg-config 
   $ sudo apt-get autoremove 
   -- this one is to remove unused packages, probably 0 at this point

   - Set HISTORY to longer: 
     $ vi ~/.bashrc
     increase HISTSIZE (to 5000) and HISTFILESIZE (to 10000)

   - Turn off screen saver and lock
     Start menu / Preferences  / Power Manager
     Display tab:
       Turn off flag to Handle display power management
       Set Blank after to the max (60 minutes on Lubuntu)
     Security tab: 
       Automatically lock the session: Never
       Turn off flag to lock screen when system is going to sleep


7. Shared folder between your host machine and the VM (optional)
   This is not needed for tutorial, just if you want to share files between host and vm.

   - In VirtualBox, while the VM is shut down, set up a shared folder, with auto-mount.
   - Start VM. You can see a folder  /media/sf_<your folder name>
   - Need to set group rights for adios user to use the folder
     $ sudo vi /etc/group 
     add "adios" to the vboxfs entry so that it looks like this

     vboxsf:x:999:adios
   - log out and back, run 'groups' to check if you got the group rights.



8. Download this repository
   You can postpone step 6 and 7 after 8 if you have a github account
   and want to edit this repository content.

   $ cd
   $ git clone https://github.com/pnorbert/adiosvm.git

9. VIM setup
   $ sudo apt-get install vim
   copy from this repo: vimrc to ~/.vimrc
   $ cp ~/adiosvm/vimrc .vimrc

   On Lubuntu for some reason, the root creates ~/.viminfo which we need to remove
   This will allow vi/vim to create it again under adios user and use it to remember
   positions in files opened before
   $ sudo rm ~/.viminfo

10. Github access setup
   This is only needed to get ADIOS master from github.

   We need an account to github and a config for ssh.
   A minimum .ssh/config is found in this repository:  
   $ cd 
   $ mkdir .ssh
   $ cp ~/adiosvm/ssh_config ~/.ssh/config

   If the shared folder has access to you .ssh:

   $ cp /media/sf_<yourfolder>/.ssh/config .ssh
   $ cp /media/sf_<yourfolder>/.ssh/id_dsa_github* .ssh

   If you need a proxy to get to GitHub, use corkscrew and edit
   ~/.ssh/config to add the proxy command to each entry
   $ sudo apt-get install corkscrew

   If you have a github account and the config already, and postponed
   step 6, get the adiosvm repo now:

   $ git clone github:pnorbert/adiosvm.git

   Git settings:
   $ git config --global user.name "<your name>"
   $ git config --global user.email "<your email>"
   $ git config --global core.editor vim

   Of course, set an editor what you like.

II. Preparations to install ADIOS
=================================

1. Linux Packages
   $ sudo apt-get install openmpi-common openmpi-bin libopenmpi-dev 
   $ sudo apt-get install gfortran 
   $ sudo apt-get install python-cheetah python-yaml


2. Install DataSpaces
   Only if you want staging demos.

   Download dataspaces from www.dataspaces.org, or use 1.6 from adiosvm

   $ cd
   $ mkdir -p Software
   $ cd Software
   $ tar zxf ~/adiosvm/adiospackages/dataspaces-1.6.0.tar.gz 
   $ cd dataspaces-1.6.0
   $ ./autogen.sh
   $ ./configure --prefix=/opt/dataspaces --enable-dart-tcp CC=mpicc FC=mpif90 CFLAGS="-g -std=gnu99" LIBS="-lm"
   $ make
   $ sudo make install

   Test DataSpaces: follow the instructions in 
      ~/adiosvm/adiospackages/test_dataspaces.txt


3. OBSOLETE: Install MXML
   adios-1.10 includes mxml-2.9 and will build it with adios. 
   Only, if you want the mxml library as standalone package:
   $ cd ~/Software
   $ tar zxf ~/adiosvm/adiospackages/mxml-2.9.tar.gz 
   $ cd mxml-2.9/
   $ ./configure --prefix=/opt/mxml
   $ make
   $ sudo make install

   In ~/.bashrc, add to LD_LIBRARY_PATH "/opt/mxml/lib"


4. Compression libraries
   Only if you want to demo the transform library.

   zlib and bzip2 are installed as linux packages:
   $ sudo apt-get install bzip2 libbz2-dev zlib1g zlib1g-dev

   SZIP and ISOBAR are provided in adiospackages/

   $ cd ~/Software
   $ tar zxf ~/adiosvm/adiospackages/szip-2.1.tar.gz 
   $ cd szip-2.1/
   $ ./configure --prefix=/opt/szip --with-pic
   $ make
   $ sudo make install

   In ~/.bashrc, add to LD_LIBRARY_PATH "/opt/szip/lib"

   $ cd ~/Software
   $ tar zxf ~/adiosvm/adiospackages/isobar.0.3.0.tgz 
   $ cd isobar.0.3.0

   Edit
      projs/ISOBAR_library/nbproject/Makefile-gcc-release-x64-static.mk
   and add -fPIC to CFLAGS
   On 32bit systems, also remove -m64 from CFLAGS

   $ make install

     This creates ./lib/libisobar.a
   
   Manually install it to /opt/isobar
   $ sudo mkdir /opt/isobar
   $ cd /opt/isobar
   $ sudo ln -s $HOME/Software/isobar.0.3.0/include 
   $ sudo ln -s $HOME/Software/isobar.0.3.0/lib 


5. Flexpath support
   Only if you want staging demos.
   We need to get CHAOS from Georgia Tech and build it. This will take a while...
   
   $ sudo apt-get install bison libbison-dev flex
   $ sudo mkdir -p /opt/chaos
   $ sudo chgrp adios /opt/chaos
   $ sudo chmod g+w /opt/chaos
   $ cd ~/Software
   $ svn --username anon --password anon co https://anon@svn.research.cc.gatech.edu/kaos/chaos_base/trunk chaos
   $ cd chaos
   $ cp build_config build_config.adiosVM
   Edit build_config.adiosVM
   - we only need to install: dill cercs_env atl ffs evpath
   - comment out the rest of packages
   - change the build area
     BUILD_AREA=/home/adios/Software/chaos
     RESULTS_FILES_DIR=$HOME/Software/chaos
   - change the install target
     INSTALL_DIRECTORY=/opt/chaos

   $ perl chaos_build.pl -c build_config.adiosVM 

   Enter 'anon' for both username and password if requested at svn checkout commands.
   Enter 'adios' for a question like "Password for 'default' GNOME keyring:"

   In ~/.bashrc, add to LD_LIBRARY_PATH "/opt/chaos/lib"


6. Sequential HDF5 support
   Only if you want bp2h5 conversion code.

   $ cd ~/Software
   $ tar jxf ~/adiosvm/adiospackages/hdf5-1.8.17.tar.bz2
   $ mv hdf5-1.8.17 hdf5-1.8.17-serial
   $ cd hdf5-1.8.17-serial
   $ ./configure --with-zlib=/usr --with-szlib=/opt/szip --prefix=/opt/hdf5-1.8.17 --enable-fortran
   $ make -j 4
   $ sudo make install

   In ~/.bashrc, add to PATH "/opt/hdf5-1.8.17/bin"


7. Parallel HDF5 support
   Only if you want PHDF5 transport method in ADIOS.

   $ cd ~/Software
   $ tar jxf ~/adiosvm/adiospackages/hdf5-1.8.17.tar.bz2
   $ mv hdf5-1.8.17 hdf5-1.8.17-parallel
   $ cd hdf5-1.8.17-parallel
   $ ./configure --with-zlib=/usr --with-szlib=/opt/szip --prefix=/opt/hdf5-1.8.17-parallel --enable-parallel --enable-fortran --with-pic  CC=mpicc FC=mpif90

   Verify that in the Features list:
        Parallel HDF5: yes

   Note: the -fPIC option is required for building parallel NetCDF4 later

   $ make -j 4
   $ sudo make install


8. Sequential NetCDF support
   Only if you want bp2ncd conversion code.

   $ cd ~/Software
   $ tar zxf ~/adiosvm/adiospackages/netcdf-4.4.0.tar.gz
   $ mv netcdf-4.4.0 netcdf-4.4.0-serial
   $ cd netcdf-4.4.0-serial
   $ ./configure --prefix=/opt/netcdf-4.4.0 --enable-netcdf4 CPPFLAGS="-I/opt/hdf5-1.8.17/include" LDFLAGS="-L/opt/hdf5-1.8.17/lib"
   $ make -j 4
   $ make check         
     This testing is optional
   $ sudo make install


9. Parallel NetCDF4 support (not PNetCDF!)
  ###   Just forget about this. It breaks the adios build  ###
   Only if you want NC4PAR transport method in ADIOS.

   $ cd ~/Software
   $ tar zxf ~/adiosvm/adiospackages/netcdf-4.4.0.tar.gz
   $ mv netcdf-4.4.0 netcdf-4.4.0-parallel
   $ cd netcdf-4.4.0-parallel
   $ ./configure --prefix=/opt/netcdf-4.4.0-parallel --enable-netcdf4 --with-pic CPPFLAGS="-I/opt/hdf5-1.8.17-parallel/include" LDFLAGS="-L/opt/hdf5-1.8.17-parallel/lib -L/opt/szip/lib" LIBS="-lsz" CC=mpicc FC=mpif90
   $ make -j 4
   $ sudo make install
   

10. Fastbit indexing support (needed for queries)
   $ cd ~/Software
   $ svn co https://code.lbl.gov/svn/fastbit/trunk fastbit
     username and password: anonsvn
   $ cd fastbit/
   $ ./configure --with-pic -prefix=/opt/fastbit
   $ make
   -- this will be slooooow
   $ sudo make install
   $ make clean  
   -- src/ is about 1.4GB after build

   In ~/.bashrc, add to LD_LIBRARY_PATH "/opt/fastbit/lib"

III. ADIOS Installation
=======================

1. Download ADIOS
   1. ADIOS 1.10 is in this repo: 
   $ cd ~/Software
   $ tar zxf ~/adiosvm/adiospackages/adios-1.10.0.tar.gz
   $ cd adios-1.10.0

   2. Download ADIOS master from repository
   $ cd ~/Software
   $ git clone github:ornladios/ADIOS.git
     OR
   $ git clone https://github.com/ornladios/ADIOS.git
   $ cd ADIOS
   $ ./autogen.sh

2. Build ADIOS
   Then:
   $ cp ~/adiosvm/adiospackages/runconf.adiosvm .
   $ . ./runconf.adiosvm
   $ make -j 4

3. Test ADIOS a bit
   $ make check

   $ cd tests/suite
   $ ./test.sh 01
     and so on up to 16 tests
     Some test fail because multiple processes write a text file which is 
     compared to a reference file, but some lines can get mixed up. Try 
     running the same test a couple of times. One 'OK' means the particular
     test is okay.

4. Install 
   $ sudo make install
   In ~/.bashrc, add to LD_LIBRARY_PATH "/opt/adios/1.10/lib" and 
     add to PATH "/opt/adios/1.10/bin"

5. Build and install python wrapper

   To build Adios python wrapper, install following packages by:
   $ sudo apt-get install python python-dev
   $ sudo apt-get install python-numpy

   Note: To use a parallel version, we need mpi4py. 

   $ sudo apt-get install python-pip
   $ sudo -H pip install mpi4py
   
   Alternatively, we can install from a source code too:

   $ wget https://bitbucket.org/mpi4py/mpi4py/downloads/mpi4py-2.0.0.tar.gz
   $ tar xvf mpi4py-2.0.0.tar.gz
   $ cd mpi4py-2.0.0
   $ python setup.py build
   $ sudo python setup.py install

   Then, we are ready to install adios and adios_mpi python module. An
   easy way is to use "pip".
   
   $ sudo -H "PATH=$PATH" pip install --upgrade \
     --global-option build_ext --global-option -lrt adios adios_mpi

   If there is any error, we can build from source. Go to the
   wrapper/numpy directory under the adios source directory:
   $ cd wrapper/numpy

   Type the following to build Adios python wrapper:
   $ python setup.py build_ext 
   If not working, add " -lrt"

   The following command is to install:
   $ sudo "PATH=$PATH" python setup.py install

   Same for adios_mpi module:
   $ python setup_mpi.py build_ext -lrt
   $ sudo "PATH=$PATH" python setup_mpi.py install

   Test:
   A quick test can be done:
   $ cd wrapper/numpy/tests
   $ python test_adios.py
   $ mpirun -n 4 python test_adios_mpi.py


IV. ADIOS Tutorial code
=======================

   For ADIOS 1.10, the tutorial is included in this repository
   ~/adiosvm/Tutorial

1. Linux Packages
   KSTAR demo requires gnuplot
   $ sudo apt-get install gnuplot
   


V. Build Visit from release
===========================

Simple way: install binary release
  - download a release from https://wci.llnl.gov/simulation/computer-codes/visit/executables
  E.g.:
  $ cd /opt
  $ sudo tar zxf visit2_10_2.linux-x86_64-ubuntu14.tar.gz
  $ sudo mv visit2_10_2.linux-x86_64 visit


Complicated way:

- Need to have many linux packages installed.
- Build a Visit release using it's build script that
  downloads/builds a lot of dependencies.

1. Linux packages
  $ sudo apt-get install dialog gcc-multilib subversion libx11-dev tcl tk
  $ sudo apt-get install libglu1-mesa-dev 
  $ sudo libxt-dev
  $ sudo apt-get install xutils-dev

  For Silo reader to believe in good Qt installation
  $ sudo apt-get install libxmu-dev libxi-dev

  Qt development packages (required or visit will build its own)
  $ sudo apt-get libqt4-dev 
  This will install all dependent packages

2. Build latest Visit release (with many dependencies)
   https://wci.llnl.gov/codes/visit/source.html

   Visit 2.7.2 release uses adios 1.6.0 but it downloads and builds its own
   version without compression or staging. 

   $ cd ~/Software
   $ mkdir -p visit
   $ cd visit
   $ wget http://portal.nersc.gov/svn/visit/trunk/releases/2.7.2/build_visit2_7_2
     Or download the latest build script from the website
     https://wci.llnl.gov/codes/visit/source.html

   $ chmod +x build_visit2_7_2
   $ ./build_visit2_7_2 --parallel --mesa --mxml --adios --hdf5 --xdmf --zlib --szip --silo
   $ ./build_visit --system-qt --parallel --mesa --mxml --adios --hdf5 --xdmf --zlib --szip --silo --console

    This script should be started again and again after fixing build problems.
    All log is founf in build_visit2_7_2_log, appended at each try.

    In the dialogs, just accept everything


                     |     You many now try to run VisIt by cd'ing into the     │  
                     │ visit2.7.2/src/bin directory and invoking "visit".       │  
                     │                                                          │  
                     │     To create a binary distribution tarball from this    │  
                     │ build, cd to                                             │  
                     │ /home/adios/Software/visit/visit2.7.2/src                │  
                     │     then enter: "make package"                           │  
                     │                                                          │  
                     │     This will produce a tarball called                   │  
                     │ visitVERSION.ARCH.tar.gz, where     VERSION is the       │  
                     │ version number, and ARCH is the OS architecure.          │  
                     │                                                          │  
                     │     To install the above tarball in a directory called   │  
                     │ "INSTALL_DIR_PATH",    enter: svn_bin/visit-install      │  
                     │ VERSION ARCH INSTALL_DIR_PATH                            |



3. Build Visit from svn trunk
- Get Visit trunk from repository and build against dependencies
  that has been built in the previous step
- You need to do step 2 (build visit from source release)

   $ cd ~/Software
   $ svn co http://portal.nersc.gov/svn/visit/trunk/src visit.src
   $ cd visit.src
   
   Get the local build cmake config created by build_visit2.7.2 and edit
   $ cp ~/Software/visit/adiosVM.cmake ./config-site
   
     - Add CMAKE_INSTALL_PREFIX to point to desired installation target (/opt/visit):

         VISIT_OPTION_DEFAULT(CMAKE_INSTALL_PREFIX /opt/visit)

     - Edit VISIT_ADIOS_DIR to point to desired ADIOS install (/opt/adios/1.10):

         VISIT_OPTION_DEFAULT(VISIT_ADIOS_DIR /opt/adios/1.10)


   Configure visit with cmake that was built by visit release
   $ rm CMakeCache.txt
   $ ~/Software/visit/cmake-2.8.10.2/bin/cmake .
   $ make -j 4
   $ make install


   If a dependency package's version is updated, you need to download and build a new one.
   E.g. with VTK 6.1

   $ cd ~/Software/visit
   $ wget http://www.vtk.org/files/release/6.1/VTK-6.1.0.tar.gz
   $ tar zxf VTK-6.1.0.tar.gz
   $ mkdir VTK-6.1.0-build
   $ cd VTK-6.1.0-build
   
   In ../build_visit2.7.1_log, search for "Configuring VTK . . ." and see how cmake was called (a long line).
   Replace the CMAKE_INSTALL_PREFIX:PATH and run that command

   $ "/home/adios/Software/visit/visit/cmake/2.8.10.2/linux-x86_64_gcc-4.6/bin/cmake" <whatever appears here> ../VTK-6.1.0




V. Build Plotter
=================

If you still want to use the our own plotter instead of / besides visit.

  $ sudo apt-get install grace

  If not installed Visit yet:
  $ sudo apt-get install libglu1-mesa-dev libxt-dev

  $ mkdir ~/Software/plotter
  $ cd ~/Software/plotter


  1. Build Mesa library
  $ cd ~/Software/plotter
  $ tar zxf ~/adiosvm/plotterpackages/Mesa-7.8.2.tar.gz
  $ cd Mesa-7.8.2
  $ ./configure CFLAGS="-I/usr/include/i386-linux-gnu -O2 -DUSE_MGL_NAMESPACE -fPIC -DGLX_USE_TLS" CXXFLAGS="-O2 -DUSE_MGL_NAMESPACE -fPIC -DGLX_USE_TLS" --prefix=/opt/plotter --with-driver=osmesa --disable-driglx-direct 
  $ make -j 4
  $ sudo make install


  2. Build vtk-5.8 (saved from old Visit config)
  
  $ tar zxf  ~/adiosvm/plotterpackages/visit-vtk-5.8.tar.gz
  $ mkdir vtk-5.8-build
  $ cd vtk-5.8-build
  $ export LD_LIBRARY_PATH=/opt/plotter/lib:$LD_LIBRARY_PATH
  $ cmake -DCMAKE_INSTALL_PREFIX:PATH=/opt/plotter ../visit-vtk-5.8

  Check if CMakeCache.txt has VTK_OPENGL_HAS_OSMESA:BOOL=ON, if not, turn on and rerun cmake. 
  It has to find the Mesa options and have this in CMakeCache.txt

    //Path to a file.
    OSMESA_INCLUDE_DIR:PATH=/opt/plotter/include

    //Path to a library.
    OSMESA_LIBRARY:FILEPATH=/opt/plotter/lib/libOSMesa.so
    ...
    //Use mangled Mesa with OpenGL.
    VTK_USE_MANGLED_MESA:BOOL=OFF  <-- This is OFF!!


  $ make -j 4
  $ sudo make install


  3. Build plotter
  $ cd ~/Software
  $ svn co https://svn.ccs.ornl.gov/svn-ewok/wf.src/trunk/plotter 
    ...OR...
  $ tar zxf ~/adiosvm/plotterpackages/plotter.tar.gz
  $ cd plotter
  
  Edit Makefile.adiosVM to point to the correct ADIOS, HDF5 (sequential), NetCDF (sequential), Grace and VTK libraries. 

  $ make
  $ sudo INSTALL_DIR=/opt/plotter INSTALL_CMD=install make install
  
  In ~/.bashrc, add to PATH "/opt/plotter/bin"




VI. Clean-up a bit
==================
Not much space left after building visit and plotter. You can remove this big offenders

1.9GB  ~/Software/plotter/vtk-5.8-build
1.3GB  ~/Software/visit/qt-everywhere-opensource-src-4.8.3
       ~/Software/visit/qt-everywhere-opensource-src-4.8.3.tar.gz
       ~/Software/visit/VTK*-build




VII. Installing R and pbdR 
===========================

This is for the pbdR tutorial. Not required for an ADIOS-only tutorial. 

Packages that will be needed: 
$ sudo apt-get install libcurl4-gnutls-dev

Install R
---------
See instructions on http://cran.r-project.org/bin/linux/ubuntu/

$ sudo vi /etc/apt/sources.list
add a line to the end:
deb http://mirrors.nics.utk.edu/cran/bin/linux/ubuntu xenial/

Add the key for this mirror
$ sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9
$ sudo apt-get update
$ sudo apt-get install r-base r-base-dev
$ sudo apt-get install openssl libssl-dev libssh2-1-dev libcurl4-openssl-dev

If these above don't work, you need to resort building from source.
from http://cran.r-project.org/sources.html
e.g. http://cran.r-project.org/src/base/R-3/R-3.1.2.tar.gz


--- non-SUDO version below, SUDO below ---

    $ sudo mkdir -p /opt/R/library
    $ sudo chgrp -R adios /opt/R
    $ sudo chmod -R g+w /opt/R
    
    $ export R_LIBS_USER=/opt/R/library
    $ R
    install.packages("ggplot2", repos="https://cran.cnr.berkeley.edu/", lib="/opt/R/library")
    install.packages("rlecuyer", repos="http://mirrors.nics.utk.edu/cran/", lib="/opt/R/library")
    install.packages("raster", repos="http://mirrors.nics.utk.edu/cran/", lib="/opt/R/library")
    install.packages("devtools", repos="http://mirrors.nics.utk.edu/cran/")
    library(devtools)
    install_github("RBigData/pbdMPI")
    install_github("RBigData/pbdSLAP")
    install_github("wrathematics/RNACI")
    install_github("RBigData/pbdBASE")
    install_github("RBigData/pbdDMAT")
    install_github("RBigData/pbdDEMO")
    install_github("RBigData/pbdPAPI")
    install.packages("pbdPROF", repos="http://mirrors.nics.utk.edu/cran/")
    quit()
    
    
    $ cd ~/Software
    $ git clone https://github.com/sgn11/pbdADIOS.git
    $ R CMD INSTALL pbdADIOS --configure-args="--with-adios-home=/opt/adios/1.10" --no-test-load
    
    Add to ~/.bashrc
        export R_LIBS_USER=/opt/R/library


--- SUDO version below, non-SUDO above ---

    Install 'rlecuyer' 
    ------------------
    from http://cran.r-project.org/web/packages/rlecuyer/index.html
    
    $ sudo R
    > install.packages("rlecuyer", repos="http://mirrors.nics.utk.edu/cran/")
    should get messages ending with:
    * DONE (rlecuyer)
    > q()
    quit R (or ctrl+D)
    
    Test if it is installed correctly:
    $ R
    > library(help=rlecuyer)
    > q()
    
    > install.packages("raster", repos="http://mirrors.nics.utk.edu/cran/")
    
    Install pbdR
    -------------
    
    $ sudo R
    install.packages("devtools", repos="http://mirrors.nics.utk.edu/cran/")
    library(devtools)
    install_github("RBigData/pbdMPI")
    install_github("RBigData/pbdSLAP")
    install_github("wrathematics/RNACI")
    install_github("RBigData/pbdBASE") 
    install_github("RBigData/pbdDMAT") 
    install_github("RBigData/pbdDEMO") 
    install_github("RBigData/pbdPAPI") 
    install.packages("pbdPROF", repos="http://mirrors.nics.utk.edu/cran/")
    > q()
    
    
    Install pbdADIOS
    ----------------
    $ cd ~/Software
    $ git clone https://github.com/sgn11/pbdADIOS.git
    $ sudo R CMD INSTALL pbdADIOS --configure-args="--with-adios-home=/opt/adios/1.10" --no-test-load
    -- quick test
    $ R
    > library(pbdADIOS)
    Loading required package: pbdMPI
    Loading required package: rlecuyer
    > quit()
    
--- end of SUDO version above ---

Quick test of pbdR
------------------
$ cd ~/adiosvm
$ mpirun -np 2 Rscript test_pbdR.r 
COMM.RANK = 0
[1] 0
COMM.RANK = 1
[1] 1


Download pbdR tutorial examples
-------------------------------
$ cd 
$ wget https://github.com/RBigData/RBigData.github.io/blob/master/tutorial/scripts.zip?raw=true
$ unzip  scripts.zip?raw=true

or get it using a browser from http://r-pbd.org/tutorial

Quick test of scripts:
----------------------
$ scripts/pbdMPI/quick_examples
$ mpirun -np 4 Rscript 1_rank.r
COMM.RANK = 0
[1] 0
COMM.RANK = 1
[1] 1
COMM.RANK = 2
[1] 2
COMM.RANK = 3
[1] 3


Install R Studio
----------------
$ sudo apt-get install libjpeg62
$ cd adiosvm/Rpackages
 if not there, get it from the web
$ wget http://download1.rstudio.org/rstudio-0.98.1091-i386.deb

$ sudo dpkg -i rstudio-0.98.1091-i386.deb


VII. Others
===========
  
Enable GDB debugging
--------------------
See http://askubuntu.com/questions/146160/what-is-the-ptrace-scope-workaround-for-wine-programs-and-are-there-any-risks
Ubuntu prohibits ptrace to see other processes so gdb will fail with permissions. 
Enable GDB binary to see your processes:

  $ sudo apt-get install libcap2-bin 
  $ sudo setcap cap_sys_ptrace=eip /usr/bin/gdb


GLOBAL/GTAGS
-------------
   GTAGS is useful for quickly finding definitions of functions in source codes in VIM
   It needs to be installed from source to make it work in VIM
   $ cd ~/Software
   $ tar zxf ~/adiosvm/linuxpackages/global-6.3.4.tar.gz
   $ cd global-6.3.4
   $ ./configure
   $ make
   $ sudo make install

   $ mkdir -p ~/.vim/plugin
   $ cp ~/adiosvm/linuxpackages/gtags.vim ~/.vim/plugin/
   NOTE: .vimrc already contains the flag to turn it on

   Generate the tags for a source
   $ cd ~/Software/ADIOS/src
   $ gtags
   $ ls G*
   GPATH  GRTAGS  GSYMS  GTAGS

   $ vi write/adios_posix.c
   /adios_posix_read_version
   Hit Ctrl-\ Ctrl-\
   Vi should open new file core/adios_bp_v1.c and jump to the definition of adios_posix_read_version
   :b#    -- to go back to the previous file

   If there are multiple finds, you can move among them with Ctrl-\ Ctrl-[   and  Ctrl-\ Ctrl-] 
   The commands can be modified at the bottom of ~/.vim/plugin/gtags.vim


   Add a path of any software so that gtags will search the GTAGS file there to find external references. 
   In .bashrc, add
   export GTAGSLIBPATH=/home/adios/Software/ADIOS/src
 
   You also need to run gtags in your application (top) source directory too, to get global/gtag working.



