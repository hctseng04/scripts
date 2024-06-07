#!/bin/bash

for i in $(ls /dev/mapper/mpath*)
do
    output=`multipath -ll ${i}`
    if [[ $output == *"round-robin"* ]]; then
        output_lines=`multipath -ll ${i} | wc -l`
        if [[ $output_lines != "5" ]]; then
            multipath -ll ${i}
        fi
    fi
    if [[ $output == *"service-time"* ]]; then
        output_lines=`multipath -ll ${i} | wc -l`
        if [[ $output_lines != "6" ]]; then
            multipath -ll ${i}
        fi
    fi
done
