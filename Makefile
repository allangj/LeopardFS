# Makefile for building a simple distribution
#
# Copyright (C) 2010 by Allan Granados  <allangj1_618@hotmail.com>
#                       Sebastian Lopez <slopez84@gmail.com>
#			Miguel Fonseca  <migue.fonseca@gmail.com>
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

.PHONY: all build buildkernel skeleton crossbusybox crosslighttpd devices tarfile help clean

# This top-level Makefile can *not* be executed in parallel
.NOTPARALLEL:


MYTMP			= tmp
ROOTFS			= $(MYTMP)/rootfs
PACKAGE			= $(MYTMP)/package
KERNELIMAGE		= $(MYTMP)/kernelimage
APPENDS			= appends
KPATCH			= $(APPENDS)/kpatch
FSSCRIPTS		= $(APPENDS)/fsscripts
DISNAME			= distribution
TOOLCHAINPATH		= /opt/arm-2009q1
PATH   			:= $(TOOLCHAINPATH)/bin:$(PATH)

export PATH


all: build tarfile

build: buildkernel crossbusybox crosslighttpd devices

temporal:
	@echo Creating temps rootfs and package 
	@mkdir -p $(ROOTFS) $(PACKAGE)

buildkernel: temporal
	@echo Unpacking the kernel
	@cd $(PACKAGE); tar xvfz ../../linux-2.6.29.tar.gz
	@echo Adding the patch
	@cp $(KPATCH)/crosscompilerpatch $(PACKAGE)/linux-2.6.29/patches/
	@echo crosscompilerpatch >> $(PACKAGE)/linux-2.6.29/patches/series
	@echo Applying patches
	@cd $(PACKAGE)/linux-2.6.29; quilt pop -a -f; quilt push -a
	@echo Building the kernel
	@cd $(PACKAGE)/linux-2.6.29; make
	@echo Creating uImage
	@cd $(PACKAGE)/linux-2.6.29; make uImage
	@echo Moving the uImage to tmp/kernelimage
	@mkdir $(KERNELIMAGE)
	@mv $(PACKAGE)/linux-2.6.29/arch/arm/boot/uImage $(KERNELIMAGE)/

skeleton: temporal
	@echo Creating the basics for the FS
	@echo Creating directories and permissions
	@cd $(ROOTFS); mkdir -p bin dev etc lib proc sbin tmp usr var sys
	@chmod 1777 $(ROOTFS)/tmp
	@cd $(ROOTFS); mkdir -p usr/bin usr/lib usr/sbin
	@cd $(ROOTFS); mkdir  -p var/lib var/lock var/log var/run var/tmp
	@chmod 1777 $(ROOTFS)/var/tmp
	@cd $(ROOTFS); mkdir -p etc/init.d dev/pts
	
	@echo Copying the basic C dynamic libraries from toolchain
	@cd $(ROOTFS)/lib; cp -a $(TOOLCHAINPATH)/arm-none-linux-gnueabi/libc/armv4t/lib/* ./

	@echo Copying rcS to the FS
	@cp $(FSSCRIPTS)/rcS $(ROOTFS)/etc/init.d/

	@echo Copying group to the FS
	@cp $(FSSCRIPTS)/group $(ROOTFS)/etc/

	@echo Copying passwd to the FS
	@cp $(FSSCRIPTS)/passwd $(ROOTFS)/etc/

	@echo Copying hosts to the FS
	@cp $(FSSCRIPTS)/hosts $(ROOTFS)/etc/

	@echo Copying inittab to the FS
	@cp $(FSSCRIPTS)/inittab $(ROOTFS)/etc	

	@echo Copying fstab to the FS
	@cp $(FSSCRIPTS)/fstab $(ROOTFS)/etc

	@echo Copying mdev.conf
	@cp $(FSSCRIPTS)/mdev.conf $(ROOTFS)/etc

crossbusybox: skeleton
	@echo Cross-compile busybox
	@echo Downloading busybox-1.18.5
	@cd $(PACKAGE); wget http://www.busybox.net/downloads/busybox-1.18.5.tar.bz2
	@echo Unpack busybox-1.18.5
	@cd $(PACKAGE); tar -xjvf busybox-1.18.5.tar.bz2
	@cd $(PACKAGE)/busybox-1.18.5; make defconfig
	@cd $(PACKAGE)/busybox-1.18.5; make install ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabi- CONFIG_PREFIX=../../rootfs

crosslighttpd: skeleton
	@mkdir -p /tmp/lightthpd
	@echo Cross-compile lighttpd
	@echo Downloading lighttpd-1.4.28
	@cd $(PACKAGE); wget http://download.lighttpd.net/lighttpd/releases-1.4.x/lighttpd-1.4.28.tar.gz
	@echo Unpack lighttpd-1.4.28
	@cd $(PACKAGE); tar xvfz lighttpd-1.4.28.tar.gz
	@cd $(PACKAGE)/lighttpd-1.4.28;./configure --host=arm-none-linux-gnueabi --disable-static --enable-shared --without-zlib --without-bzip2 --without-pcre
	@cd $(PACKAGE)/lighttpd-1.4.28; make; make install prefix=/tmp/lightthpd/
	@cd $(ROOTFS); cp -a /tmp/lightthpd/sbin/* sbin/; cp -a /tmp/lightthpd/lib/* lib/
	@rm /tmp/lightthpd -R -f
	@rm /tmp/pcre -R -f	
	
devices: skeleton
	@echo Creating basic devices: This section need SuperUsuer permission
	@cd $(ROOTFS)/dev; sudo mknod -m 600 mem c 1 1
	@cd $(ROOTFS)/dev; sudo mknod -m 666 null c 1 3
	@cd $(ROOTFS)/dev; sudo mknod -m 666 zero c 1 5
	@cd $(ROOTFS)/dev; sudo mknod -m 644 random c 1 8
	@cd $(ROOTFS)/dev; sudo mknod -m 600 tty0 c 4 0
	@cd $(ROOTFS)/dev; sudo mknod -m 600 tty1 c 4 1
	@cd $(ROOTFS)/dev; sudo mknod -m 600 ttyS0 c 4 64
	@cd $(ROOTFS)/dev; sudo mknod -m 666 tty c 5 0
	@cd $(ROOTFS)/dev; sudo mknod -m 600 console c 5 1

tarfile: skeleton buildkernel
	@echo Tar the directories created and remove the garbage
	@sudo rm $(PACKAGE) -R
	@echo Tar the directories
	@tar cfz $(DISNAME).tar tmp
	@echo Removing the garbage
	@sudo rm -R $(MYTMP)

help:
	@echo make build = Build all package and kernel but does not tar it into a file
	@echo make buildkernel = Create the kernel image
	@echo make skeleton = Create the skeleton of the FS
	@echo make crossbusybox = Crosscompile busybox
	@echo make crosslighttpd = Crosscompile lighttpd
	@echo make clean = Remove all creted files

clean:
	@echo Cleaning the mess
	@rm -R -f $(MYTMP)
	@rm -R -f $(DISNAME)


