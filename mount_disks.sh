#!/bin/bash

OS_DRIVE=`lsblk -ls | awk '$NF == "/" { m = 1; next } m && $NF == "disk" { print $1 ; exit}'`

HDDS_LIST=`lsscsi -b | grep /dev | grep -v $OS_DRIVE | awk '{print $2}'`

for index in $HDDS_LIST;
do
    TARGET_NAME=`blkid -o export ${index}1 | grep PARTLABEL | cut -d "=" -f 2`
    TARGET_PATH=/${TARGET_NAME/_//}
    mkdir -p $TARGET_PATH
    mount -t xfs ${index}1 $TARGET_PATH
done
