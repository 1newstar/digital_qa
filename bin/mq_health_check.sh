#!/bin/bash
#*****************************************************************************
#
#Author:     Arnab Kumar Ray
#Purpose:    This script captures message queues statistics.
#Date:       20/09/2019
#
#To run the sheel script, following parameters need to pass
# $1   - Host Name/IP Address of the virtual machine
# $2   - Queue manger name.
# $3   - List of queues separator by comma
#
#*****************************************************************************

clear

if [[ $# -ne 3 ]]; then
    echo "Insufficient argument passed"
else
    divider="================================================================"
    printf "%s\n" "$divider"
    printf "%s\n" "MESSAGE QUEUE HEALTH CHECK - $1"
    dividerUnderline="----------------------------------------------------------------"
    printf "%s\n\n" "$dividerUnderline"

    count=0
    IFS=, read -ra ary <<<$3
    for i in "${!ary[@]}"; do
       queue_name=${ary[$i]};
       MQ_CMD_OUTPUT=$( eval 'echo "display qstatus($queue_name) CURDEPTH IPPROCS MSGAGE LGETDATE LGETTIME LPUTDATE LPUTTIME" | runmqsc $2')

       queueDepth=$(echo "$MQ_CMD_OUTPUT" | awk '$1 ~ "CURDEPTH\\(.+\\)" {gsub("CURDEPTH\\(|\\)","");print $1}')
       queueIPProc=$(echo "$MQ_CMD_OUTPUT" | awk '$2 ~ "IPPROCS\\(.+\\)" {gsub("IPPROCS\\(|\\)","");print $2}')
       msg_age=$(echo "$MQ_CMD_OUTPUT" | awk '$1 ~ "MSGAGE\\(.+\\)" {gsub("MSGAGE\\(|\\)","");print $1}')

       lGetDate=$(echo "$MQ_CMD_OUTPUT" | awk '$1 ~ "LGETDATE\\(.+\\)" {gsub("LGETDATE\\(|\\)","");print $1}')
       lGetTime=$(echo "$MQ_CMD_OUTPUT" | awk '$2 ~ "LGETTIME\\(.+\\)" {gsub("LGETTIME\\(|\\)","");print $2}' | tr . : )
       lastGetDateTime="$lGetDate $lGetTime"
       lastGetDateTime=$( eval 'echo $lastGetDateTime | sed -r s/[.]+/:/g' )

       lPutDate=$(echo "$MQ_CMD_OUTPUT" | awk '$1 ~ "LPUTDATE\\(.+\\)" {gsub("LPUTDATE\\(|\\)","");print $1}' )
       lPutTime=$(echo "$MQ_CMD_OUTPUT" | awk '$2 ~ "LPUTTIME\\(.+\\)" {gsub("LPUTTIME\\(|\\)","");print $2}' | tr . : )
       lastPutDateTime="$lPutDate $lPutTime"
       lastPutDateTime=$(eval 'echo $lastPutDateTime | sed -r s/[.]+/:/g')

       if [ "$lastGetDateTime" == "" -o "$lastPutDateTime" == "" ]; then
          lastGetDateTime="NA"
          lastPutDateTime="NA"
          message="NA"
       else
          startDate=$(date -d "$lastGetDateTime" +%s)
          endDate=$(date -d "$lastPutDateTime" +%s)
          let queueGetPutTimeDiff=$(($startDate - $endDate))
          if [[ $queueDepth -gt 0 && $queueGetPutTimeDiff -gt 1 ]]; then
             message="Message(s) not consuming" 
          else
             message="Message(s) consuming"
          fi
       fi

       if [[ $count -eq 0 ]]; then
          divider1="---------------------------------------------------------------------------------"
          divider1=$divider1$divider1
          width=100
          printf "%-40s%-25s%-20s%-20s%-25s%-25s%-25s\n" "Queue Name" "Current queue depth" "Open input count" "Oldest message age" "Last put date & time" "Last get date & time" "Remarks"
          printf "%${width}s\n" "$divider1"
          count=$((count + 1))
       fi
       printf "%-40s%-25d%-20d%-20d%-25s%-25s%-25s\n" "$queue_name" "$queueDepth" "$queueIPProc" "$msg_age" "$lastPutDateTime" "$lastGetDateTime" "$message"

    done
    printf "\n\n%s\n" "$divider"
fi
