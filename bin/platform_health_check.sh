#!/bin/bash
#*****************************************************************************
#
#Author:     Arnab Kumar Ray
#Purpose:    This script captures server health details.
#Date:       08/11/2019
#
#To run the sheel script, following parameters need to pass
# $1   - Host Name/IP Address of the virtual machine
# $2   - Threshold value for CPU usage
# $3   - Threshold value for Disk space usage
# $4   - List of file system separated by pipe sign (i.e. |) will be excluded
#        in disk usage command
# $5   - Threshold value for I/O usage
# $6   - Threshold value for Memory usage
# $7   - Threshold value for Network usage
#
#*****************************************************************************

threshold=0
itemType=""

cmpWithThreshold() {
  while read output;
  do
    #echo "$threshold $output"
    value=$(echo $output | awk '{print $1}' | cut -d'%' -f1)
    if [[ ${value%%.*} -gt ${threshold%%.*} ]]; then
       echo "$itemType $value is grater than the threshold value $threshold"
    elif [[ ${value%%.*} -lt ${threshold%%.*} ]]; then
       echo "$itemType $value is less than threshold value $threshold"
    else
       echo "$itemType $value is equal with threshold value $threshold"
    fi
  done
}

diskusageCmpWithThreshold() {
  while read output;
  do
    #echo "$threshold $output"
    usep=$(echo $output | awk '{print $1}' | cut -d'%' -f1)
    partition=$(echo $output | awk '{print $2}')
    if [[ $usep -gt $threshold ]]; then
       echo "$itemType $usep% of partition \"$partition\" is grater than the threshold value $threshold"
    elif [[ $usep -lt $threshold ]]; then
       echo "$itemType $usep% of partition \"$partition\" is less than threshold value $threshold"
    else
       echo "$itemType $usep% of partition \"$partition\" is equal with threshold value $threshold"
    fi
  done
}

if [[ $# -lt 7 ]]; then
   echo "Insufficient argument passed"
else
    divider="================================================================"
    printf "%s\n" "$divider"
    printf "%s\n" "SERVER HEALTH CHECK - $1"
    dividerUnderline="----------------------------------------------------------------"
    printf "%s\n\n" "$dividerUnderline"

    divider1="~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

    printf "%s\n" "CPU usage"
    printf "%s\n" "$divider1"
    result=$(top -bn 1 -i -c)
    if [ -z "$2" ]; then
       printf "%s\n" "$result"
    else
       threshold=$2
       itemType="CPU usage value"
       #
       # adding us and sy value of "CPU(s)" row. where
       # us, user : time running un-niced user processes
       # sy, system : time running kernel processes
       #
       printf "%s" "$result" | grep -F "%Cpu" | awk '{print $2+$4}' | cmpWithThreshold
    fi

    printf "\n%s\n" "Disk space usage"
    printf "%s\n" "$divider1"
    result=$(df -h)
    if [ -z "$3" ]; then
       printf "%s\n" "$result"
    else
       excludeList=$4
       threshold=$3
       itemType="Disk space usage value"
       if [ -n "$excludeList" ] ; then
          printf "%s" "$result" | sed 1d | grep -vE "^${excludeList}" | awk '{print $5 " " $6 " " $1}' | diskusageCmpWithThreshold
       else
	  printf "%s" "$result" | sed 1d | awk '{print $5 " " $6 " " $1}' | diskusageCmpWithThreshold
       fi
    fi

    printf "\n%s\n" "I/O usage"
    printf "%s\n" "$divider1"
    #result=$(iostat -c 1 2) #Show CPU only report with 1 seconds interval and 2 times reports
    result=$(iostat -c)
    if [ -z "$5" ]; then
       printf "%s\n" "$result"
    else
       threshold=$5
       itemType="I/O usage value"
       #
       # adding %user, %nice and %system value of "avg-cpu" rows(s). where
       # %user : percentage of CPU utilization that occurred while executing at the user (application) level
       # %nice : percentage of CPU utilization that occurred while executing at the user level with nice priority
       # %system : percentage of CPU utilization that occurred while executing at the system (kernel) level
       #
       printf "%s" "$result" | awk -F: '/avg-cpu:/ && $0 != "" { getline; print $0}' | awk '{print $1+$2+$3}' | cmpWithThreshold
    fi

    printf "\n%s\n" "Virtual memory"
    printf "%s\n" "$divider1"
    result=$(vmstat -S m) #Show in Megabytes with parameters -S and m/M. By default vmstat displays statistics in kilobytes.
    if [ -z "$6" ]; then
       printf "%s\n" "$result"
    else
       threshold=$6
       itemType="Virtual memory free value"
       #comparing free value with threshold
       printf "%s" "$result" | awk -F: '/free/ && $0 != "" { getline; print $0}' | awk '{print $4}' | cmpWithThreshold
    fi

    printf "\n%s\n" "Network"
    printf "%s\n" "$divider1"
    result=$(netstat)
    if [ -z "$7" ]; then
       printf "%s\n" "$result"
    else
       echo "Need to add compare logic"
    fi

    printf "\n\n%s\n" "$divider"
fi

#FREE_DATA=`free -m | grep Mem`
#CURRENT=`echo $FREE_DATA | cut -f3 -d' '`
#TOTAL=`echo $FREE_DATA | cut -f2 -d' '`
#echo RAM: $(echo "scale = 2; $CURRENT/$TOTAL*100" | bc)
#echo HDD: `df -lh | awk '{if ($6 == "/") { print $5 }}' | head -1 | cut -d'%' -f1`
