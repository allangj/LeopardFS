# Makefile for building a simple distribution
#
# Copyright (C) 2010 by Allan Granados  <allangj1_618@hotmail.com>
#                       Sebastian Lopez <>
#			Miguel Fonseca  <>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You could see a copy of the GNU General Public License at
# http://www.gnu.org/licenses/gpl-2.0.html

#--------------------------------------------------------------
# Just run 'make menuconfig', configure stuff, then run 'make'.
# You shouldn't need to mess with anything beyond this point...
#--------------------------------------------------------------

.PHONY: all build buildkernel skeleton crossbusybox devices tarfile help clean

# This top-level Makefile can *not* be executed in parallel
.NOTPARALLEL:

TOOLCHAINPATH		= /opt/arm-2009q1
PATH   			:= $(TOOLCHAINPATH)/bin:$(PATH)

export PATH


all: build

build: temporal buildkernel skeleton crossbusybox devices tarfile

temporal:
	@echo Creating temps rootfs and package 
	@mkdir -p tmp/rootfs tmp/package

buildkernel:
	@echo Unpacking the kernel
	@cd tmp/package; tar xvfz ../../linux-2.6.29.tar.gz
	@echo Adding the patch
	@cp appends/kpatch/crosscompilerpatch tmp/package/linux-2.6.29/patches/
	@echo crosscompilerpatch >> tmp/package/linux-2.6.29/patches/series
	@echo Applying patches
	@cd tmp/package/linux-2.6.29; quilt pop -a -f; quilt push -a
	@echo Building the kernel
	@cd tmp/package/linux-2.6.29; make
	@echo Creating uImage
	@cd tmp/package/linux-2.6.29; make uImage
	@echo Moving the uImage to tmp/kernelimage
	@mkdir tmp/kernelimage
	@mv tmp/package/linux-2.6.29/arch/arm/boot/uImage tmp/kernelimage/

skeleton:
	@echo Creating the basics for the FS
	@echo Creating directories and permissions
	@cd tmp/rootfs; mkdir bin dev etc lib proc sbin tmp usr var sys
	@chmod 1777 tmp/rootfs/tmp
	@cd tmp/rootfs; mkdir usr/bin usr/lib usr/sbin
	@cd tmp/rootfs; mkdir var/lib var/lock var/log var/run var/tmp
	@chmod 1777 tmp/rootfs/var/tmp
	@cd tmp/rootfs; mkdir etc/init.d dev/pts
	
	@echo Copying the basic C dynamic libraries from toolchain
	@cd tmp/rootfs/lib; cp -a $(TOOLCHAINPATH)/arm-none-linux-gnueabi/libc/armv4t/lib/* ./

	@echo Copying rcS to the FS
	@cp appends/fsscripts/rcS tmp/rootfs/etc/init.d/

	@echo Copying group to the FS
	@cp appends/fsscripts/group tmp/rootfs/etc/

	@echo Copying passwd to the FS
	@cp appends/fsscripts/passwd tmp/rootfs/etc/

	@echo Copying hosts to the FS
	@cp appends/fsscripts/hosts tmp/rootfs/etc/

	@echo Copying inittab to the FS
	@cp appends/fsscripts/inittab tmp/rootfs/etc	

	@echo Copying fstab to the FS
	@cp appends/fsscripts/fstab tmp/rootfs/etc

	@echo Copying mdev.conf
	@cp appends/fsscripts/mdev.conf tmp/rootfs/etc

crossbusybox:
	@echo Cross-compile busybox
	@echo Downloading busybox-1.18.5
	@cd tmp/package; wget http://www.busybox.net/downloads/busybox-1.18.5.tar.bz2
	@echo Unpack busybox-1.18.5
	@cd tmp/package; tar -xjvf busybox-1.18.5.tar.bz2
	@cd tmp/package/busybox-1.18.5; make defconfig
	@cd tmp/package/busybox-1.18.5; make install ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabi- CONFIG_PREFIX=../../rootfs

devices:
	@echo Creating basic devices: This section need SuperUsuer permission
	@cd tmp/rootfs/dev; sudo mknod -m 600 mem c 1 1
	@cd tmp/rootfs/dev; sudo mknod -m 666 null c 1 3
	@cd tmp/rootfs/dev; sudo mknod -m 666 zero c 1 5
	@cd tmp/rootfs/dev; sudo mknod -m 644 random c 1 8
	@cd tmp/rootfs/dev; sudo mknod -m 600 tty0 c 4 0
	@cd tmp/rootfs/dev; sudo mknod -m 600 tty1 c 4 1
	@cd tmp/rootfs/dev; sudo mknod -m 600 ttyS0 c 4 64
	@cd tmp/rootfs/dev; sudo mknod -m 666 tty c 5 0
	@cd tmp/rootfs/dev; sudo mknod -m 600 console c 5 1

tarfile:
	@echo Tar the directories created and remove the garbage
	@sudo rm tmp/package -R
	@echo Tar the directories
	@tar cfz distribution.tar tmp
	@echo Removing the garbage
	@sudo rm tmp -R

help:
	@echo make clean => Remove all creted files

clean:
	@echo Cleaning the mess
	@rm -R tmp


