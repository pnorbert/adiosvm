adiosvm
=======

Packages and howtos for creating a linux system for ADIOS tutorials

Required steps to get plain ADIOS working: I.1,2,3,5 II.1,4 III.1

Steps:

I. Set up a Linux VM
====================

1. Install VirtualBox 

2. Get a debian linux ISO image
   We currently use Ubuntu 12.04 64bit and the descriptions below all refer to that system. 

   Note: We could not install Soft-iWarp (Infiniband layer) on Ubuntu 12.04 32bit and Ubuntu 10.4
      That means DataSpaces does not work and staging demos with DataSpaces don't work.

3. Create a new VM
   Type=Linux, System=Ubuntu (64bit)
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
     - Click left-top icon (Dash Home) and search for Terminal
       - start it and immediately on the icon in the tray: right-click and "Lock to Launcher"
     - install updates (will come up automatically)

   - VirtualBox VM menu: Devices/Insert Guest Additions CD Image
     - will install kernel modules, need adios password to run
     - this allows for resizing the window and 
       for copy/paste between the VM and your host machine
        (set Devices/Shared Clipboard/Bidirectional)
     Note: This has to be repeated when recompiling the kernel for Soft-iWarp...

   - You can remove the LibreOffice products to save some disk space.
     - Start Ubuntu Software Center
     - Click for Installed and search for "Libre", remove one by one
     - Ah well, df -h will reveal we did not save anything visible amount of space

   - Terminal setup (if you don't like the default one)
     - Start Terminal
     - Edit/Profile preferences
       General tab: unclick "Use the system fixed with font"
       Colors tab: Black on white
     - Scrolling tab: increase the scrollback to a few thousand lines (e.g. 5120)

   - Set HISTORY to longer: 
     $ vi ~/.bashrc
     increase HISTSIZE (to 5000) and HISTFILESIZE (to 10000)

   - Turn off screen saver and lock
     System Settings / Brightness and Lock
     Turn off screen when inactive for: Never
     Lock: off

4. Shared folder between your host machine and the VM (optional)
   This is not needed for tutorial, just if you want to share files between host and vm.

   - In VirtualBox, while the VM is shut down, set up a shared folder, with auto-mount.
   - Start VM. You can see a folder  /media/sf_<your folder name>
   - Need to set group rights for adios user to use the folder
     $ sudo vi /etc/group 
     add "adios" to the vboxfs entry so that it looks like this

     vboxsf:x:999:adios
   - log out and back, run 'groups' to check if you got the group rights.


5. Install some linux packages (apt-get install)
   $ sudo apt-get install  build-essential git-core libtool autoconf apt-file subversion cmake
   $ sudo apt-get autoremove 
     - this one to get rid of unnecessary packages after removing LibreOffice

6. Download this repository
   You can postpone step 6 and 7 after 8 if you have a github account
   and want to edit this repository content.

   $ cd
   $ git clone https://github.com/pnorbert/adiosvm.git

7. VIM setup
   $ sudo apt-get vim
   copy from this repo: vimrc to ~/.vimrc
   $ cp ~/adiosvm/vimrc .vimrc

8. Github access setup
   This is only needed to get ADIOS master from github.

   We need an account to github and a config for ssh.
   A minimum .ssh/config is found in this repository:  
   $ cd 
   $ mkdir .ssh
   $ cp ~/adiosvm/ssh_config ~/.ssh/config

   If the shared folder has access to you .ssh:

   $ cp /media/sf_<yourfolder>/.ssh/config .ssh
   $ cp /media/sf_<yourfolder>/.ssh/id_dsa_github* .ssh

   If you have a github account and the config already, and postponed
   step 6, get the adiosvm repo now:

   $ sudo apt-get corkscrew
   $ git clone github-cork:pnorbert/adiosvm.git


II. Preparations to install ADIOS
=================================

1. Linux Packages
   $ sudo apt-get install gfortran mpich2

2. Install Soft-iWarp to get the Infiniband network
   This is required to enable DataSpaces on the VM, which is required to run
   the staging demos. 
   
   Another staging software is Flexpath which does not require anything. But
   not all staging demos work with it.

   See install guide: 
      http://voidreflections.blogspot.com/2011/03/how-to-install-soft-iwarp-on-ubuntu.html

   We prepared those commands in a single script, run that:

   $ ~/adiosvm/softiwarp.install

   Add a line to the end in /etc/security/limits.conf
   $ sudo vi /etc/security/limits.conf
   *                -       memlock         unlimited

   Restart the VM

   At each time we need to run ~/adiosvm/softiwarp.setup to load the infiniband 
   and softiwarp kernel modules!


3. Install DataSpaces
   Only if you want staging demos.
   Only if everything is okay with Soft-iWarp.

   Download dataspaces from www.dataspaces.org, or use 1.3 from adiosvm

   $ cd
   $ mkdir -p Software
   $ cd Software
   $ tar zxf ~/adiosvm/adiospackages/dataspaces-1.3.0.tar.gz 
   $ cd dataspaces-1.3.0
   $ ./configure --prefix=/opt/dataspaces/1.3.0 CC=mpicc FC=mpif90
   $ make
   $ sudo make install

   Test DataSpaces: follow the instructions in 
      ~/adiosvm/adiospackages/test_dataspaces.txt

4. Install MXML
   $ cd ~/Software
   $ tar zxf ~/adiosvm/adiospackages/mxml-2.7.tar.gz 
   $ cd mxml-2.7/
   $ ./configure --prefix=/opt/mxml
   $ make
   $ sudo make install

   In ~/.bashrc, add to LD_LIBRARY_PATH "/opt/mxml/lib"

5. Compression libraries
   Only if you want to demo the transform library.

   zlib and bzip2 are installed as linux packages:
   $ sudo apt-get install bzip2 libbz2-dev zlib1g zlib1g-dev

   SZIP and ISOBAR are provided in adiospackages/

   $ cd ~/Software
   $ tar zxf ~/adiosvm/adiospackages/szip-2.1.tar.gz 
   $ cd szip-2.1/
   $ ./configure --prefix=/opt/szip
   $ make
   $ sudo make install

   In ~/.bashrc, add to LD_LIBRARY_PATH "/opt/szip/lib"

   $ cd ~/Software
   $ tar zxf ~/adiosvm/adiospackages/isobar.0.3.0.tgz 
   $ cd isobar.0.3.0

   On 32bit systems, edit
      projs/ISOBAR_library/nbproject/Makefile-gcc-release-x64-static.mk
   and remove -m64 from CFLAGS

   $ make install

     This creates ./lib/libisobar.a
   
   Manually install it to /opt/isobar
   $ sudo mkdir /opt/isobar
   $ cd /opt/isobar
   $ sudo ln -s $HOME/Software/isobar.0.3.0/include 
   $ sudo ln -s $HOME/Software/isobar.0.3.0/lib 

6. Flexpath support
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
   - we only need to install: dill cercs_env gen_thread atl ffs evpath
   - comment out the rest of packages
   - change the build area
     BUILD_AREA=/home/adios/Software/chaos
     RESULTS_FILES_DIR=$HOME/Software/chaos
   - change the install target
     INSTALL_DIRECTORY=/opt/chaos

   $ perl chaos_build.pl -c build_config.adiosVM 

   Type anon for both username and password if requested at svn checkout commands.

   In ~/.bashrc, add to LD_LIBRARY_PATH "/opt/chaos/lib"


7. Sequential HDF5 support
   Only if you want bp2h5 conversion code.

   $ cd ~/Software
   $ tar jxf ~/adiosvm/adiospackages/hdf5-1.8.12.tar.bz2
   $ mv hdf5-1.8.12 hdf5-1.8.12-serial
   $ cd hdf5-1.8.12-serial
   $ ./configure --with-zlib=/usr --with-szlib=/opt/szlib --prefix=/opt/hdf5-1.8.12 --enable-fortran
   $ make -j 4
   $ sudo make install


8. Parallel HDF5 support
   Only if you want PHDF5 transport method in ADIOS.

   $ cd ~/Software
   $ tar jxf ~/adiosvm/adiospackages/hdf5-1.8.12.tar.bz2
   $ mv hdf5-1.8.12 hdf5-1.8.12-parallel
   $ cd hdf5-1.8.12-parallel
   $ ./configure --with-zlib=/usr --with-szlib=/opt/szlib --prefix=/opt/hdf5-1.8.12-parallel --enable-parallel --enable-fortran --with-pic  CC=mpicc FC=mpif90

   Verify that in the Features list:
        Parallel HDF5: yes

   Note: the -fPIC option is required for building parallel NetCDF4 later

   $ make -j 4
   $ sudo make install


9. Sequential NetCDF support
   Only if you want bp2ncd conversion code.

   $ cd ~/Software
   $ tar zxf ~/adiosvm/adiospackages/netcdf-4.3.0.tar.gz
   $ mv netcdf-4.3.0 netcdf-4.3.0-serial
   $ cd netcdf-4.3.0-serial
   $ ./configure --prefix=/opt/netcfdf-4.3.0 --enable-netcdf4 CPPFLAGS="-I/opt/hdf5-1.8.12/include" LDFLAGS="-L/opt/hdf5-1.8.12/lib"
   $ make -j 4
   $ make check         
     This testing is optional
   $ sudo make install


10. Parallel NetCDF4 support (not PNetCDF!)
  ###   Just forget about this. It breaks the adios build  ###
   Only if you want NC4PAR transport method in ADIOS.

   $ cd ~/Software
   $ tar zxf ~/adiosvm/adiospackages/netcdf-4.3.0.tar.gz
   $ mv netcdf-4.3.0 netcdf-4.3.0-parallel
   $ cd netcdf-4.3.0-parallel
   $ ./configure --prefix=/opt/netcfdf-4.3.0-parallel --enable-netcdf4 --with-pic CPPFLAGS="-I/opt/hdf5-1.8.12-parallel/include" LDFLAGS="-L/opt/hdf5-1.8.12-parallel/lib -L/opt/szip/lib" LIBS="-lsz" CC=mpicc FC=mpif90
   $ make -j 4
   $ sudo make install
   
    

III. ADIOS Installation
=======================

1. Download ADIOS
   1. ADIOS 1.6 is in this repo: 
   $ cd ~/Software
   $ tar zxf ~/adiosvm/adiospackages/adios-1.6.0.tar.gz
   $ cd adios-1.6.0

   2. Download ADIOS master from repository
   $ cd ~/Software
   $ git clone github-cork:ornladios/ADIOS.git
     OR
   $ git clone https://github.com/ornladios/ADIOS.git
   $ cd ADIOS

2. Build ADIOS
   Then:
   $ cp ~/adiosvm/adiospackages/runconf.adiosvm .
   $ . ./runconf.adiosvm
   $ make -j 4; make -j 4 

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
   In ~/.bashrc, add to LD_LIBRARY_PATH "/opt/adios/1.6.0/lib" and 
     add to PATH "/opt/adios/1.6.0/bin"



IV. ADIOS Tutorial code
=======================

   For ADIOS 1.6, the tutorial is included in this repository
   ~/adiosvm/Tutorial

   


