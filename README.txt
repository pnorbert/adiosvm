adiosvm
=======

Packages and howtos for creating a linux system for ADIOS tutorials

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
   $ sudo apt-get install  build-essential git-core libtool autoconf 
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
   Only if everything is okay with Soft-iWarp.

   Download dataspaces from www.dataspaces.org, or use 1.3 from adiosvm

   $ cd
   $ mkdir -p Software
   $ cd Software
   $ tar zxf ~/adiosvm/adiospackages/dataspaces-1.3.0.tar.gz 
   $ cd dataspaces-1.3.0
   $ ./configure --prefix=/opt/dataspaces/1.3.0 CC=mpicc FC=mpif90
   $ make
   $ make install

   Test DataSpaces: follow the instructions in 
      ~/adiosvm/adiospackages/test_dataspaces.txt

4. Install MXML

