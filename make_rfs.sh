#!/usr/bin/env bash
# 
# Script to create Debian rootFS for Aakash(sun5i).
#
# Usage:
#
# Install 'gcc-arm-linux-gnueabihf'. For Debian system, include
# this repo in source list.
#
#       http://emdebian.org/~thibg/repo/
#
# Login as 'root' to run the script. DO NOT run it as 'sudo', some
# command may not work.
#
#       bash ./make_rfs.sh
#

# ---- Global variables ---
BOARD="a13_olinuxino"
CROSS_COMPILER="arm-linux-gnueabihf-"

UBOOT_SRC="https://github.com/androportal/uboot-allwinner"
LINUX_SUNXI_SRC="https://github.com/androportal/linux-sunxi"

UBOOT_BRANCH="sunxi"
LINUX_SUNXI_BRANCH="sunxi-3.0"

LINUX_SUNXI_DIR="linux-sunxi"

DEBIAN_ROOTFS_DIR="rootfs"
DEBIAN_ROOTFS_URL="http://ftp.debian.org/debian"
# ---- Global variables ends here ----


function install_deps() {
    # Install related dependencies to build rootfs.
    echo "Installing dependencies.."
    sudo apt-get install build-essential dpkg-dev kernel-wedge \
	make automake checkinstall git u-boot-tools debootstrap \
	qemu-user-static minicom
}


function build_uboot() {
    # Clone and build uboot.
    echo "Cloning uboot..."
    git clone -b ${UBOOT_BRANCH} ${UBOOT_SRC} --depth=1
    pushd uboot-allwinner
    # pwd
    make ${BOARD} CROSS_COMPILE=${CROSS_COMPILER}
    popd
    # pwd    
}


function build_kernel() {
    # Clone and build kernel and modules.
    echo "Cloning linux-sunxi[sunxi-3.0].."
    git clone -b ${LINUX_SUNXI_BRANCH} ${LINUX_SUNXI_SRC} \
	--depth=1 ${LINUX_SUNXI_DIR}
    
    pushd ${LINUX_SUNXI_DIR}
    
    echo "Compiling kernel..."
    make ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} uImage
    
    echo "Compiling modules"
    make ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} INSTALL_MOD_PATH=out modules
    
    echo "Installing modules in 'out' directory..."
    make ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} INSTALL_MOD_PATH=out \
	modules_install
    
    popd    
}


function build_rootfs() {
    # Bootstrap Debian rootfs and copy `qemu-arm-static` binary.
    echo "Bootstrapping stable version of Debian.."
    mkdir -p ${DEBIAN_ROOTFS_DIR}
    debootstrap --verbose --arch=armhf --variant=minbase --foreign stable \
	${DEBIAN_ROOTFS_DIR} ${DEBIAN_ROOTFS_URL}

    # Copy `qemu-arm-static` binary
    cp -v $(which qemu-arm-static) ${DEBIAN_ROOTFS_DIR}/usr/bin/
}


function ch-mount() {
    # Function to mount and bind required filesystem and devs
    echo "Mounting.."
    mount -t proc /proc ${DEBIAN_ROOTFS_DIR}/proc
    mount -t sysfs /sys ${DEBIAN_ROOTFS_DIR}/sys
    mount -o bind /dev ${DEBIAN_ROOTFS_DIR}/dev
    mount -o bind /dev/pts ${DEBIAN_ROOTFS_DIR}/dev/pts

    # No need to chroot inside rootfs. Commands will be executed externally
    #sudo chroot ${DEBIAN_ROOTFS_DIR}
}


function ch-umount() {
    # Function to unmount filesystem and devs
    echo "Umounting.."
    umount ${DEBIAN_ROOTFS_DIR}/proc
    umount ${DEBIAN_ROOTFS_DIR}/sys
    umount ${DEBIAN_ROOTFS_DIR}/dev
    umount ${DEBIAN_ROOTFS_DIR}/dev/pts
}


function configure_rootfs() {
    # Mount and chroot into rootfs directory
    ch-mount
    
    echo "Perform additional configuration(second-stage)"
    #  Note: debootstrap/debootstrap file is removed once second stage
    #  in completed.
    chroot ${DEBIAN_ROOTFS_DIR} debootstrap/debootstrap --second-stage
    
    echo -e "deb http://ftp.us.debian.org/debian stable main contrib\n\
deb http://ftp.debian.org/debian/ wheezy-updates main contrib" > ${DEBIAN_ROOTFS_DIR}/etc/apt/sources.list
    
    # echo "Setting proxy..."
    # chroot rootfs export http_proxy="http://10.118.248.42:3128/"
    # chroot rootfs export https_proxy="http://10.118.248.42:3128/"

    echo "Updating repository list.."
    chroot ${DEBIAN_ROOTFS_DIR} apt-get update

    # TODO:Get rid of language errors
    echo "export LANG=C" >> ${DEBIAN_ROOTFS_DIR}/root/.bashrc
    echo "export LANG=en_US.UTF-8 UTF-8" >> ${DEBIAN_ROOTFS_DIR}/root/.bashrc
    echo "export LANGUAGE=en_US.UTF-8" >> ${DEBIAN_ROOTFS_DIR}/root/.bashrc
    echo "export LC_ALL=en_US.UTF-8" >> ${DEBIAN_ROOTFS_DIR}/root/.bashrc
    # chroot rootfs dpkg-reconfigure locales # No need to run this

    echo "LANG=\"en_US.UTF-8\"" >> ${DEBIAN_ROOTFS_DIR}/etc/default/locale
    
    echo "Installing essentials utilities..."
    chroot ${DEBIAN_ROOTFS_DIR} apt-get install apt-utils dialog locales \
	--force-yes -y

    chroot ${DEBIAN_ROOTFS_DIR} apt-get install dhcp3-client udev netbase \
	ifupdown iproute openssh-server --force-yes -y
    chroot ${DEBIAN_ROOTFS_DIR} apt-get install sudo iputils-ping wget \
	net-tools ntpdate vim.tiny less nano bash-completion ssh \
	--force-yes -y
    chroot ${DEBIAN_ROOTFS_DIR} apt-get install ethtool florence \
	alsa-utils hal wicd netsurf lxde-core xorg --force-yes -y
    chroot ${DEBIAN_ROOTFS_DIR} apt-get install lightdm network-manager \
	--force-yes -y

    # TODO: Default language
    # TODO: Encoding to use on the console

    # Create user 'aakash', and assign permissions
    chroot ${DEBIAN_ROOTFS_DIR} useradd aakash -m -s /bin/bash \
	-G adm,sudo,audio -p `mkpasswd aakash`
    
    # Enable auto-login.
    sed -i.orig -e 's/^#autologin-user=/autologin-user=aakash/g' \
	${DEBIAN_ROOTFS_DIR}/etc/lightdm/lightdm.conf

    # Auto-load modules.
    echo "8192cu" >> ${DEBIAN_ROOTFS_DIR}/etc/modules
    echo "ft5x_ts" >> ${DEBIAN_ROOTFS_DIR}/etc/modules

    # Set hostname 
    echo "debian" > ${DEBIAN_ROOTFS_DIR}/etc/hostname
    echo -e "127.0.1.1\tdebian" >> ${DEBIAN_ROOTFS_DIR}/etc/hosts

    # Finally, unmount rootfs
    ch-umount
}


function copy_modules() {
    # Copy kernel modules to rootfs
    if [ -d ${DEBIAN_ROOTFS_DIR}/lib/modules ];
    then
	echo "Copying modules.."
	cp -rv ${LINUX_SUNXI_DIR}/out/lib/modules/3.0.76+ \
	    ${DEBIAN_ROOTFS_DIR}/lib/modules/
    else
	mkdir -p ${DEBIAN_ROOTFS_DIR}/lib/modules
	cp -rv ${LINUX_SUNXI_DIR}/out/lib/modules/3.0.76+ \
	    ${DEBIAN_ROOTFS_DIR}/lib/modules/
    fi

    # Download and copy wifi firmware
    if [ -d ${DEBIAN_ROOTFS_DIR}/lib/firmware ];
    then
	wget -c http://mirrors.arizona.edu/raspbmc/downloads/bin/lib/wifi/rtlwifi/rtl8192cufw.bin \
	    --directory-prefix=${DEBIAN_ROOTFS_DIR}/lib/firmware
    else
	mkdir -p ${DEBIAN_ROOTFS_DIR}/lib/firmware
	wget -c http://mirrors.arizona.edu/raspbmc/downloads/bin/lib/wifi/rtlwifi/rtl8192cufw.bin \
	    --directory-prefix=${DEBIAN_ROOTFS_DIR}/lib/firmware
    fi
}


install_deps
build_uboot
build_kernel
build_rootfs
configure_rootfs
copy_modules
