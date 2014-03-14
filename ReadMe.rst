=============================
Build Debian Image for Aakash
=============================

Script to create Debian rootFS.

It can
------

#. Installs dependencies
#. Clone and compiles uboot
#. Clone and compiles sunxi kernel
#. Create rootFS using debootstrap
#. Configures and install essential packages
#. Creates user ``aakash`` with passwd ``aakash``
#. Copies kernel modules and firmware to rootFS

   
Usage
-----

#. Make sure to install ``gcc-arm-linux-gnueabihf``. For Debian
   system, include following repo-url in source list.

      http://emdebian.org/~thibg/repo/

#. Login as **root** to run the script. DO NOT run it as 'sudo', some
   commands may not work. ::

        bash ./make_rfs.sh

#. The script will prompt once for default language and encoding.

#. Once the build is complete, `uboot` & `uImage` has to be copied to
   SD-card
   
   #. Follow `this
      <https://github.com/androportal/linux-on-aakash/blob/debian/debian-wheezy-aakash.rst#transferring-u-boot-to-sdcard>`_
      link to transfer `uboot` to SD-card
  
   #. Follow instructions from step **1** to **10** described `here
      <https://github.com/androportal/linux-on-aakash/blob/debian/debian-wheezy-aakash.rst#copy-kernel--modules-to-sdcard>`_. to
      copy `uImage`

#. Now copy the content of ``rootfs/`` directory to the 2nd primary
   partition mentioned in above link.

#. The bootable SD-card should be ready with Debian.
