#!/bin/bash

OS_DRIVE=`lsblk -ls | awk '$NF == "/" { m = 1; next } m && $NF == "disk" { print $1 ; exit}'`

echo "====== data drives creation ======"
lsscsi | grep /dev | grep -v $OS_DRIVE
echo "====== data drives creation ======"

WIPE_DRIVES=`lsscsi -b | grep /dev | grep -v $OS_DRIVE | awk '{print $2}'`

INDEX=1

echo -e -n "\033[33mDo you want to wipe above drives to build drives? [y/n] \033[00m"
read YN
if [[ "$YN" == "y" || "$YN" == "yes" ]]
then
    for x in $WIPE_DRIVES
    do
        TARGET_PATH=/`hostname -s`/disk$INDEX
        TARGET_NAME=`hostname -s`_disk$INDEX
        umount $TARGET_PATH
        wipefs -f -a $x
        parted $x --script mklabel gpt
        #parted $x -a optimal --script mkpart ${TARGET_NAME} xfs 0% 100%
        parted $x -a none --script mkpart ${TARGET_NAME} xfs 0% 100%
        mkfs.xfs -f ${x}1
        mkdir -p $TARGET_PATH
        mount -t xfs ${x}1 $TARGET_PATH
        ((INDEX=INDEX+1))
    done
fi
