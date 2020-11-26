#!/bin/bash
set -eux -o pipefail
if [ $(id -u) != 0 ]; then
	echo >&2 "must be executed as root"
	exit 1
fi

# ashmem
if [ -f "/lib/modules/$(uname -r)/kernel/drivers/staging/android/ashmem_linux.ko" ]; then
	/sbin/modprobe ashmem_linux
	if [ ! -e /dev/ashmem ]; then
		mknod /dev/ashmem c 10 55
	fi
fi

# binder (newer kernel uses /dev/binderfs directory; older kernel uses /dev/binder file)
if [ -f "/lib/modules/$(uname -r)/kernel/drivers/android/binder_linux.ko" ]; then
	/sbin/modprobe binder_linux
	if grep binder /proc/filesystems; then
		if [ ! -e /dev/binderfs/binder-control ]; then
			mkdir -p /dev/binderfs
			mount -t binder none /dev/binderfs
		fi
	else
		if [ ! -e /dev/binder ]; then
			mknod /dev/binder c 511 0
		fi
	fi
fi