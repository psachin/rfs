#!/usr/bin/env bash

# ---- Global variables ---
BOARD="a13_olinuxino"
CROSS_COMPILER="arm-linux-gnueabihf-"

UBOOT_SRC="https://github.com/androportal/uboot-allwinner"
LINUX_SUNXI_SRC="https://github.com/androportal/linux-sunxi"

UBOOT_BRANCH="sunxi"
LINUX_SUNXI_BRANCH="sunxi-3.0"

DEBIAN_ROOTFS_DIR="rootfs"
DEBIAN_ROOTFS_URL="http://ftp.debian.org/debian"

# ---- Global variables ends here ----

function install_deps() {
    echo "Installing dependencies"
    sudo apt-get install build-essential dpkg-dev kernel-wedge make automake checkinstall git u-boot-tools debootstrap qemu-user-static minicom
}


function build_uboot() {
    echo "Cloning uboot..."
    git clone -b ${UBOOT_BRANCH} ${UBOOT_SRC}
    
    pushd uboot-allwinner
    
    pwd
    
    make ${BOARD} CROSS_COMPILE=${CROSS_COMPILER}
    
    popd
    
    pwd    
}



function build_kernel() {
    echo "Cloning linux-sunxi[sunxi-3.0]"
    git clone -b ${LINUX_SUNXI_BRANCH} ${LINUX_SUNXI_SRC} --depth=1 demo-sunxi
    
    pushd demo-sunxi
    
    echo "Compiling kernel..."
    make ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} uImage
    
    echo "Compiling modules"
    make ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} INSTALL_MOD_PATH=out modules
    
    echo "Installing modules in 'out' directory..."
    make ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} INSTALL_MOD_PATH=out modules_install
    
    popd    
}


function build_rootfs() {
    echo "Bootstrapping stable version on Debian..."
    mkdir -p ${DEBIAN_ROOTFS_DIR}
    debootstrap --verbose --arch=armhf --variant=minbase --foreign stable ${DEBIAN_ROOTFS_DIR} ${DEBIAN_ROOTFS_URL}

    sudo cp -v $(which qemu-arm-static) ${DEBIAN_ROOTFS_DIR}/usr/bin/
}


function ch-mount() {
    echo "MOUNTING"
    sudo mount -t proc /proc ${DEBIAN_ROOTFS_DIR}/proc
    sudo mount -t sysfs /sys ${DEBIAN_ROOTFS_DIR}/sys
    sudo mount -o bind /dev ${DEBIAN_ROOTFS_DIR}/dev
    sudo mount -o bind /dev/pts ${DEBIAN_ROOTFS_DIR}/dev/pts

    # No need to chroot inside rootfs. Commands will be executed externally
    #sudo chroot ${DEBIAN_ROOTFS_DIR}
}


function ch-umount() {
    echo "UMOUNTING"
    sudo umount ${DEBIAN_ROOTFS_DIR}/proc
    sudo umount ${DEBIAN_ROOTFS_DIR}/sys
    sudo umount ${DEBIAN_ROOTFS_DIR}/dev
    sudo umount ${DEBIAN_ROOTFS_DIR}/dev/pts
}


function configure_rootfs() {

    # Mount and chroot into rootfs directory
    ch-mount

    
    echo "Perform additional configuration(second-stage)"
    #  debootstrap/debootstrap file is removed once second stage in
    #  completed.
    chroot ${DEBIAN_ROOTFS_DIR} debootstrap/debootstrap --second-stage
    

    echo -e "deb http://ftp.us.debian.org/debian stable main contrib\n\
deb http://ftp.debian.org/debian/ wheezy-updates main contrib" > ${DEBIAN_ROOTFS_DIR}/etc/apt/sources.list
    

    # echo "Setting proxy..."
    # chroot rootfs export http_proxy="http://10.118.248.42:3128/"
    # chroot rootfs export https_proxy="http://10.118.248.42:3128/"

    echo "Updating repository list..."
    chroot ${DEBIAN_ROOTFS_DIR} apt-get update


    # Get rid of language errors
    echo "export LANG=C" >> ${DEBIAN_ROOTFS_DIR}/root/.bashrc
    echo "export LANG=en_US.UTF-8 UTF-8" >> ${DEBIAN_ROOTFS_DIR}/root/.bashrc
    echo "export LANGUAGE=en_US.UTF-8" >> ${DEBIAN_ROOTFS_DIR}/root/.bashrc
    echo "export LC_ALL=en_US.UTF-8" >> ${DEBIAN_ROOTFS_DIR}/root/.bashrc
    # chroot rootfs dpkg-reconfigure locales # No need to run this
    
    echo "Installing essentials utilities..."
    chroot ${DEBIAN_ROOTFS_DIR} apt-get install apt-utils dialog locales --force-yes -y

    chroot ${DEBIAN_ROOTFS_DIR} apt-get install dhcp3-client udev netbase ifupdown iproute openssh-server --force-yes -y
    chroot ${DEBIAN_ROOTFS_DIR} apt-get install sudo iputils-ping wget net-tools ntpdate vim.tiny less nano bash-completion ssh --force-yes -y
    chroot ${DEBIAN_ROOTFS_DIR} apt-get install ethtool florence alsa-utils hal wicd netsurf lxde-core xorg --force-yes -y
    chroot ${DEBIAN_ROOTFS_DIR} apt-get install lightdm network-manager --force-yes -y


    # Language to use[TODO]
    # Encoding to use on the console[TOD]

    
    ch-umount
    
}



install_deps
build_uboot
build_kernel
build_rootfs
configure_rootfs








