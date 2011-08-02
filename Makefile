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

.PHONY: all build setenviroment skeleton crossbusybox devices help clean

# This top-level Makefile can *not* be executed in parallel
.NOTPARALLEL:

TOOLCHAINPATH		= /opt/arm-2009q1
PATH   			:= $(TOOLCHAINPATH)/bin:$(PATH)

export PATH


all: build

build: skeleton crossbusybox

skeleton:
	@echo Creating esqueleton of the FS
	@mkdir -p tmp/rootfs tmp/package
	@cd tmp/rootfs; mkdir bin dev etc lib proc sbin tmp usr var sys
	@chmod 1777 tmp/rootfs/tmp
	@cd tmp/rootfs; mkdir usr/bin usr/lib usr/sbin
	@cd tmp/rootfs; mkdir var/lib var/lock var/log var/run var/tmp
	@chmod 1777 tmp/rootfs/var/tmp
	@cd tmp/rootfs/lib; cp -a $(TOOLCHAINPATH)/arm-none-linux-gnueabi/libc/armv4t/lib/* ./

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

help:
	@echo make clean => Remove all creted files

clean:
	@echo Cleaning the mess
	@rm -R tmp


