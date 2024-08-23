#!/bin/bash

HDDS_LIST=( "/dev/sda"
            "/dev/sdb"
            "/dev/sdc"
            "/dev/sdd"
            "/dev/sde"
            "/dev/sdf"
            "/dev/sdg"
            "/dev/sdh" )

#TOTAL_HDDS="${#HDDS_LIST[@]}"

for index in "${HDDS_LIST[@]}";
do

    TARGET_NAME=`blkid -o export ${index}1 | grep PARTLABEL | cut -d "=" -f 2`
    TARGET_PATH=/${TARGET_NAME/_//}
    mkdir -p $TARGET_PATH
    mount -t xfs ${index}1 $TARGET_PATH

done
