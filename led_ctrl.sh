#!/bin/bash

################################################################################
#
# Function : Using storcli command to locate SSD or HDD address
#              via kernel device name (/dev/sdaX).
#
# Author : Hsien-Chun Tseng
# Date : 2023/09/14
# Version : 1.0
#
################################################################################

while getopts d:s: option
do
    case "${option}"
    in
    d) DEVICE=${OPTARG,,};;
    s) SWITCH=${OPTARG,,};;
    esac
done

if [[ -z "$DEVICE" || -z "$SWITCH" ]]; then
    echo "./led_ctrl.sh -d /dev/sdaX -s on|off"
else
    if ! [[ $SWITCH == "on" || $SWITCH == "off" ]]; then
        echo "./led_ctrl.sh -d /dev/sdaX -s on|off"
        exit 1
    fi
    if [[ -f "/opt/MegaRAID/storcli/storcli64" ]]; then
        if [[ -b $DEVICE ]]; then
            WWN=`udevadm info --name $DEVICE | grep SCSI_IDENT_TARGET_NAA_REG= | cut -d "=" -f 2`
            if [[ $WWN == "" ]]; then
                WWN=`udevadm info --name $DEVICE | grep SCSI_IDENT_LUN_NAA_REG= | cut -d "=" -f 2`
            fi
            if [[ $WWN != "" ]]; then
                DRIVE_LOC=`/opt/MegaRAID/storcli/storcli64 /call/eall/sall show all|grep -C6 -i $WWN | grep "Device attributes" | awk '{print $2}'`
            else
                #WWN=`udevadm info --name $DEVICE | grep SCSI_IDENT_LUN_NAA_REGEXT= | cut -d "=" -f 2`
                CTRL_NUM=`/opt/MegaRAID/storcli/storcli64 /call/vall show all |grep -B60 $DEVICE | grep Controller | grep -o -P '\d+'`
                DRIVE_LOC_TMP=`/opt/MegaRAID/storcli/storcli64 /call/vall show all |grep -B40 $DEVICE | grep \ Onln | awk '{print $1}'`
                DRIVE_LOC_TMP=${DRIVE_LOC_TMP//:/\/s}
                DRIVE_LOC_ARR=($DRIVE_LOC_TMP)
                DRIVE_LOC=""
                for i in "${DRIVE_LOC_ARR[@]}"
                do
                    DRIVE_LOC="$DRIVE_LOC /c$CTRL_NUM/e${i}"
                done
            fi
            if [[ $DRIVE_LOC == "" ]]; then
                echo "unexpected condition!"
                exit 1
            fi

            #DRIVE_LOC=`echo $DRIVE_LOC|cut -d ' ' -f1`
            DRIVE_LOC_ARR=($DRIVE_LOC)
            for i in "${DRIVE_LOC_ARR[@]}"
            do
                if [[ $SWITCH == "on" ]]; then
                    /opt/MegaRAID/storcli/storcli64 $i start locate
                elif [[ $SWITCH == "off" ]]; then
                    /opt/MegaRAID/storcli/storcli64 $i stop locate
                else
                    echo "unknown switch option: $SWITCH"
                    exit 1
                fi
            done
        else
            echo "$DEVICE is not found!"
        fi
    else
        echo "Please install storcli (ssacli-X.XX-XX.X.x86_64.rpm)"
    fi
fi

rm -rf storcli.log*
