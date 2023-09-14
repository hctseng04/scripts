#!/bin/bash

################################################################################
#
# Function : Using storcli or ssacli command to locate SSD or HDD address
#              via kernel device name (/dev/sdX).
#
# Author : Hsien-Chun Tseng
# Date : 2023/09/14
# Version : 1.1
#
################################################################################

STORCLI_INSTALLED=0
SMARTCLI_INSTALLED=0

# StorCli SAS Customization Utility
STORCLI_CMD="/opt/hpe/storcli/storcli64"

if [ ! -f $STORCLI_CMD ]; then
    STORCLI_CMD="/opt/MegaRAID/storcli/storcli64"
fi

# Smart Storage Adminstrator CLI
SMARTCLI_CMD="/opt/smartstorageadmin/ssacli/bin/ssacli"

if [[ -f $STORCLI_CMD ]]; then
    NUM_OF_CTRL=`$STORCLI_CMD show | grep "Number of Controllers" | grep -o -P '\d+'`
    if [[ $NUM_OF_CTRL > 0 ]]; then
        STORAGE_CLI=$STORCLI_CMD
    fi
    STORCLI_INSTALLED=1
fi

if [[ -f $SMARTCLI_CMD ]]; then
    NUM_OF_CTRL=`$SMARTCLI_CMD ctrl all show status | grep "Controller Status" | wc -l`    
    
    if [[ $NUM_OF_CTRL > 0 ]]; then
        STORAGE_CLI=$SMARTCLI_CMD
    fi
    SMARTCLI_INSTALLED=1
fi

while getopts d:s: option
do
    case "${option}"
    in
    d) DEVICE=${OPTARG,,};;
    s) SWITCH=${OPTARG,,};;
    esac
done

if [[ -z "$DEVICE" || -z "$SWITCH" ]]; then
    echo "./led_ctrl.sh -d /dev/sdX -s on|off"
else
    
    if ! [[ $SWITCH == "on" || $SWITCH == "off" ]]; then
        echo "./led_ctrl.sh -d /dev/sdX -s on|off"
        exit 1
    fi
    
    if [[ -f $STORAGE_CLI ]]; then
        if [[ -b $DEVICE ]]; then
            
            if [[ $STORAGE_CLI == $SMARTCLI_CMD ]]; then
                ## process the Smart Storage Adminstrator CLI
                
                SERIAL=`udevadm info --name $DEVICE | grep SCSI_IDENT_SERIAL= | cut -d "=" -f 2`
                if [[ $SERIAL == "" ]]; then
                    echo "$DEVICE serial not found!"
                    exit 1
                fi
                
                SLOT_LIST=`$STORAGE_CLI ctrl all show | grep Slot | sed 's/^.*Slot/Slot/' | awk '{print $2}'`
                SLOT_LIST_ARR=($SLOT_LIST)
                
                SERIAL_FOUND_FLAG=0
                for i in "${SLOT_LIST_ARR[@]}"
                do
                    PHY_DRV_LIST=`$STORAGE_CLI ctrl slot=$i pd all show status | sed 's/ (.*//' | sed 's/^.*physicaldrive //'`
                    PHY_DRV_LIST_ARR=($PHY_DRV_LIST)
                    for j in "${PHY_DRV_LIST_ARR[@]}"
                    do
                        #SERIAL_TMP=`$STORAGE_CLI ctrl slot=$i pd $j show | grep "Serial Number:" | cut -d ":" -f 2 | tr -d ' '`
                        SERIAL_FOUND=`$STORAGE_CLI ctrl slot=$i pd $j show | grep $SERIAL | wc -l`
                        if [[ $SERIAL_FOUND == 1 ]]; then
                            # ctrl slot=0 pd 1I:1:1 modify led=on
                            SERIAL_FOUND_FLAG=1
                            if [[ $SWITCH == "on" ]]; then
                                $STORAGE_CLI ctrl slot=$i pd $j modify led=on
                                echo "$DEVICE led is on."
                                break
                            elif [[ $SWITCH == "off" ]]; then
                                $STORAGE_CLI ctrl slot=$i pd $j modify led=off
                                echo "$DEVICE led is off."
                                break
                            else
                                echo "unknown switch option: $SWITCH"
                                exit 1
                            fi
                        fi ## end if [[ $SERIAL_FOUND == 1 ]]
                    done ## end for j in
                done ## end for i in
                
                if [[ $SERIAL_FOUND_FLAG == 0 ]]; then
                    SLOT_LIST=`$STORAGE_CLI ctrl all show | grep Slot | sed 's/^.*Slot/Slot/' | awk '{print $2}'`
                    SLOT_LIST_ARR=($SLOT_LIST)
                    
                    for i in "${SLOT_LIST_ARR[@]}"
                    do
                        LG_DRV_LIST=`$STORAGE_CLI ctrl slot=$i ld all show status | sed 's/ (.*//' | sed 's/^.*logicaldrive //'`
                        LG_DRV_LIST_ARR=($LG_DRV_LIST)
                        for j in "${LG_DRV_LIST_ARR[@]}"
                        do
                            PHY_DRV_LIST=`$STORAGE_CLI ctrl slot=$i ld $j show | grep physicaldrive | sed 's/ (.*//' | sed 's/^.*physicaldrive //'`
                            PHY_DRV_LIST_ARR=($PHY_DRV_LIST)
                            for k in "${PHY_DRV_LIST_ARR[@]}"
                            do
                                if [[ $SWITCH == "on" ]]; then
                                    $STORAGE_CLI ctrl slot=$i pd $k modify led=on
                                    echo "$DEVICE led is on."
                                elif [[ $SWITCH == "off" ]]; then
                                    $STORAGE_CLI ctrl slot=$i pd $k modify led=off
                                    echo "$DEVICE led is off."
                                else
                                    echo "unknown switch option: $SWITCH"
                                    exit 1
                                fi
                            done ## end for k in
                        done ## end for j in
                    done ## end for i in
                fi ## end if [[ $SERIAL_FOUND_FLAG == 0 ]]
            else
                ## process the StorCli SAS Customization Utility
                
                WWN=`udevadm info --name $DEVICE | grep SCSI_IDENT_TARGET_NAA_REG= | cut -d "=" -f 2`
                if [[ $WWN == "" ]]; then
                    WWN=`udevadm info --name $DEVICE | grep SCSI_IDENT_LUN_NAA_REG= | cut -d "=" -f 2`
                fi
                
                if [[ $WWN != "" ]]; then
                    DRIVE_LOC=`$STORAGE_CLI /call/eall/sall show all|grep -C6 -i $WWN | grep "Device attributes" | awk '{print $2}'`
                else
                    #WWN=`udevadm info --name $DEVICE | grep SCSI_IDENT_LUN_NAA_REGEXT= | cut -d "=" -f 2`
                    CTRL_NUM=`$STORAGE_CLI /call/vall show all |grep -B60 $DEVICE | grep Controller | grep -o -P '\d+'`
                    DRIVE_LOC_TMP=`$STORAGE_CLI /call/vall show all |grep -B40 $DEVICE | grep \ Onln | awk '{print $1}'`
                    DRIVE_LOC_TMP=${DRIVE_LOC_TMP//:/\/s}
                    DRIVE_LOC_ARR=($DRIVE_LOC_TMP)
                    DRIVE_LOC=""
                    for i in "${DRIVE_LOC_ARR[@]}"
                    do
                        DRIVE_LOC="$DRIVE_LOC /c$CTRL_NUM/e${i}"
                    done
                fi # end if [[ $WWN != "" ]];
                
                if [[ $DRIVE_LOC == "" ]]; then
                    echo "unexpected condition!"
                    exit 1
                fi
                
                #DRIVE_LOC=`echo $DRIVE_LOC|cut -d ' ' -f1`
                DRIVE_LOC_ARR=($DRIVE_LOC)
                
                for i in "${DRIVE_LOC_ARR[@]}"
                do
                    if [[ $SWITCH == "on" ]]; then
                        $STORAGE_CLI $i start locate
                    elif [[ $SWITCH == "off" ]]; then
                        $STORAGE_CLI $i stop locate
                    else
                        echo "unknown switch option: $SWITCH"
                        exit 1
                    fi
                done ## end for i in "${DRIVE_LOC_ARR[@]}"
                
                rm -rf storcli.log*
                
            fi ## end if [[ $STORAGE_CLI == $SMARTCLI_CMD ]]
        else
            echo "$DEVICE is not found!"
        fi ## end if [[ -b $DEVICE ]]
    else
        if [ $STORCLI_INSTALLED == 0 ]; then
            echo "Please install storcli rpm."
        fi
        if [ $SMARTCLI_INSTALLED == 0 ]; then
            echo "Please install ssacli rpm."
        fi
    fi
fi
