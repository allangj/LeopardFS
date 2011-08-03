# Makefile for building a simple distribution
#
# Copyright (C) 2010 by Allan Granados  <allangj1_618@hotmail.com>
#                       Sebastian Lopez <>
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

build: temporal buildkernel skeleton crossbusybox tarfile

temporal:
	@echo Creating temps rootfs and package 
	@mkdir -p tmp/rootfs tmp/package

buildkernel:
	@echo Unpacking the kernel
	@cd tmp/package; tar xvfz ../../linux-2.6.29.tar.gz
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
	
	@echo Copying the basic C dynamic libraries from toolchain
	@cd tmp/rootfs/lib; cp -a $(TOOLCHAINPATH)/arm-none-linux-gnueabi/libc/armv4t/lib/* ./

	echo Creating rcS
	touch rcS
	@echo '#!'/bin/sh > rcS
	@echo PATH = /sbin:/bin:/usr/sbin:/usr/bin >> rcS
	@echo umask 022 >> rcS
	@echo export PATH >> rcS
	@echo mount -a >> rcS
	@echo mkdir /dev/pts >> rcS
	@echo mount -t devpts devpts /dev/pts -o mode=0622  >> rcS 
	@echo 'echo /sbin/mdev > /proc/sys/kernel/hotplug' >> rcS
	@echo mdev -s >> rcS
	@echo mkdir /var/lock >> rcS
	@echo klogd >> rcS
	@echo syslogd >> rcS
	@echo hwclock -s >> rcS
	@echo Moving rcS to the FS
	@mv rcS tmp/rootfs/etc

	@echo Creating inittab
	@touch inittab
	@echo ::sysinit:/etc/rcS > inittab
	@echo ::restart:/sbin/init >> inittab
	@echo ttyS0::askfirst:-/bin/sh >> inittab
	@echo ::shutdown:/bin/umount –a -r >> inittab
	@echo ::respawn:/sbin/getty 115200 ttyS0 >> inittab
	@echo Moving inittab to the FS
	@mv inittab tmp/rootfs/etc
	
	@echo Creating fstab
	@touch fstab
	@echo proc            /proc           proc    defaults        0 0 > fstab
	@echo none            /dev/pts        devpts  gid=5,mode=620  0 0 >> fstab
	@echo none            /sys            sysfs   defaults        0 0 >> fstab
	@echo none            /dev            tmpfs   defaults        0 0 >> fstab
	@echo none            /tmp            tmpfs   defaults        0 0 >> fstab
	@echo none            /var            tmpfs   defaults        0 0 >> fstab
	@echo Moving fstab to the FS
	@mv fstab tmp/rootfs/etc

	@echo Creating mdev.conf
	@touch mdev.conf
	@echo rtc0 root:root 660 @ln -sf /dev/$MDEV /dev/rtc > mdev.conf
	@echo controlC0 root:root 660 @ln -sf /dev/$MDEV /dev/snd/$MDEV >> mdev.conf
	@echo pcmC0D0c root:root 660 @ln -sf /dev/$MDEV /dev/snd/$MDEV >> mdev.conf
	@echo pcmC0D0p root:root 660 @ln -sf /dev/$MDEV /dev/snd/$MDEV >> mdev.conf
	@echo timer root:root 660 @ln -sf /dev/$MDEV /dev/snd/$MDEV >> mdev.conf
	@echo event0 root:root 660 @ ln -sf /dev/$MDEV /dev/input/$MDEV >> mdev.conf
	@echo fb0 root:root 660 @ln -sf /dev/$MDEV /dev/fb/0 >> mdev.conf
	@echo fb1 root:root 660 @ln -sf /dev/$MDEV /dev/fb/1 >> mdev.conf
	@echo fb2 root:root 660 @ln -sf /dev/$MDEV /dev/fb/2 >> mdev.conf
	@echo i2c-0 root:root 660 @ln -sf /dev/$MDEV /dev/i2c/0 >> mdev.conf
	@echo Moving mdev.conf to the FS
	@mv mdev.conf tmp/rootfs/etc

crossbusybox:
	@echo Cross-compile busybox
	@echo Downloading busybox-1.18.5
	@cd tmp/package; wget http://www.busybox.net/downloads/busybox-1.18.5.tar.bz2
	@echo Unpack busybox-1.18.5
	@cd tmp/package; tar -xjvf busybox-1.18.5.tar.bz2
	@cd tmp/package/busybox-1.18.5; make defconfig
	@cd tmp/package/busybox-1.18.5; make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabi-
	@cd tmp/package/busybox-1.18.5; make install CONFIG_PREFIX=../../rootfs	

devices:
	@echo Creating basic devices: Bug permission
	@cd tmp/rootfs/dev; mknod -m 600 mem c 1 1
	@cd tmp/rootfs/dev; mknod -m 666 null c 1 3
	@cd tmp/rootfs/dev; mknod -m 666 zero c 1 5
	@cd tmp/rootfs/dev; mknod -m 644 random c 1 8
	@cd tmp/rootfs/dev; mknod -m 600 tty0 c 4 0
	@cd tmp/rootfs/dev; mknod -m 600 tty1 c 4 1
	@cd tmp/rootfs/dev; mknod -m 600 ttyS0 c 4 64
	@cd tmp/rootfs/dev; mknod -m 666 tty c 5 0
	@cd tmp/rootfs/dev; mknod -m 600 console c 5 1

tarfile:
	@echo Tar the directories created and remove the garbage
	@rm tmp/package -R
	@echo Tar the directories
	@tar cfz distribution.tar tmp
	@echo Removing the garbage
	@rm tmp -R

help:
	@echo make clean => Remove all creted files

clean:
	@echo Cleaning the mess
	@rm -R tmp


