#!/bin/bash

device=sdb
sleepInterval=30s
maxCount=5

############

count=0


while true; do

        if [ "$(hdparm -C /dev/${device} | grep -c standby)" != "1" ]; then

                if [ -f /root/hash ]; then 
                        lastHash=$(cat /root/hash)
                        thisHash=$(cat /sys/block/${device}/stat | column -t | awk '{ print $2" "$4" "$5" "$6" "$7" "$8" "$9" "$12" "$13" "$14" "$15" "$16" "$17}') 

                        if [ "${thisHash}" == "${lastHash}" ]; then 
                                count=$((count+1))
                                echo "No disk activity on ${device} in the past ${sleepInterval}. (check ${count} of ${maxCount})"
                        else
                                echo "Disk activity detected on ${device}."
                                echo ${thisHash} > /root/hash
                                count=0
                        fi
                else
                        cat /sys/block/${device}/stat | column -t | awk '{ print $2" "$4" "$5" "$6" "$7" "$8" "$9" "$12" "$13" "$14" "$15" "$16" "$17}' > /root/hash
                fi
                if [ "${count}" -gt "${maxCount}" ]; then 
                        echo "Spinning down ${device}."
                        hdparm -Y /dev/${device} 2>&1 > /dev/null 
                fi
                sleep ${sleepInterval}
        else
                echo "Device ${device} is in standby mode."
                sleep ${sleepInterval}
        fi

done
