#!/bin/bash

USERS_LIST=`ps aux | awk '{print $1}' | sort | uniq`
EXCLUDED_LIST="USER avahi chrony colord dbus dhcpd dnsmasq geoclue libstor+ node_ex+ polkitd postfix rpcuser rpc rtkit smmsp"

for skip_user in $EXCLUDED_LIST; do
    USERS_LIST=`echo $USERS_LIST | sed "s/$skip_user//g"`
done

(echo -e "USER RSS VMEM\n-------- -------- --------";
 for user in $USERS_LIST; do
   if [[ $user == *"+" ]]; then
       user_fullname=`id -nu \`cat /proc/\\\`ps aux | grep $user | grep -v grep | awk '{print $2}' | head -n 1\\\`/status | grep Uid: | awk '{print $2}'\``
   else
       user_fullname=$user
   fi
   echo $user $(ps -U $user_fullname --no-headers -o rss,vsz \
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
