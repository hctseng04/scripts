#!/bin/bash

USERS_LIST=`ps aux | awk '{print $1}' | sort | uniq`
EXCLUDED_LIST="USER avahi chrony colord dbus dnsmasq geoclue libstor+ node_ex+ polkitd postfix rpc rtkit"

for skip_user in $EXCLUDED_LIST; do
    USERS_LIST=`echo $USERS_LIST | sed "s/$skip_user//g"`
done

(echo -e "USER RSS VMEM\n-------- -------- --------";
 for user in $USERS_LIST; do
   echo $user $(ps -U $user --no-headers -o rss,vsz \
     | awk '{rss+=$1; vmem+=$2} END{
           cmdrss=sprintf("numfmt --from-unit=K --to=iec --format %s %d", "%8.1f", rss);
           cmdrss | getline converted_rss;
           close(cmdrss);
           cmdvmem=sprintf("numfmt --from-unit=K --to=iec --format %s %d", "%8.1f", vmem);
           cmdvmem | getline converted_vmem;
           close(cmdvmem);
           print converted_rss" "converted_vmem
       }')
 done | sort -k3 -h
) | column -t -R2,3
