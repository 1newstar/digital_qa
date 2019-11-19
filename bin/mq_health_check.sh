#!/bin/bash
#*****************************************************************************
#
#Author:     Arnab Kumar Ray
#Purpose:    This script captures message queues statistics.
#Date:       20/09/2019
#
#To run the sheel script, following parameters need to pass
# $1   - Queue manger name
# $2   - List of queues separator by comma
# $3   - Thresold value for difference of get time & put time
# $4   - Application name for which queue depth need to compare 
# 
#*****************************************************************************

if [[ $# -lt 2 ]]; then
    echo "Insufficient argument passed"
else
    hostName=$(hostname --fqdn)
    divider="================================================================"
    printf "%s\n" "$divider"
    printf "%s\n" "MESSAGE QUEUE HEALTH CHECK - $hostName"
    dividerUnderline="----------------------------------------------------------------"
    printf "%s\n\n" "$dividerUnderline"

    getTimePutTimeThresold=1
    if [ -n "$3" ]; then
       getTimePutTimeThresold=$3
    fi

    MQ_CMD_OUTPUT=$(eval 'echo "DISPLAY STATUS" | dspmq | grep "$1"')
    queueStatus=$(echo "$MQ_CMD_OUTPUT" | awk '$2 ~ "STATUS\\(.+\\)" {gsub("STATUS\\(|\\)","");print $2}')
    if [ "$queueStatus" = "Running" ]; then
        printf "%s\n\n" "Queue manager $1 is running"

	#channel check
	MQ_CMD_OUTPUT=$(eval 'echo "DISPLAY CHANNEL(*)" | runmqsc $1')
	channelList=$(echo "$MQ_CMD_OUTPUT" | awk '$1 ~ "CHANNEL\\(.+\\)" {gsub("CHANNEL\\(|\\)","");print $1}' | grep -v "SYSTEM.")
	IFS=$'\n' read -rd '' -a channelList <<<"$channelList"
	for i in "${!channelList[@]}"; do
            if [[ $i -eq 0 ]]; then
               printf "%-40s%-20s\n" "Channel Name" "Status"
	       printf "%s\n\n" "$dividerUnderline"
            fi
            MQ_CMD_OUTPUT=$(eval 'echo "DISPLAY CHSTATUS(${channelList[$i]})" | runmqsc $1')
	    channelStatus=$(echo "$MQ_CMD_OUTPUT" | awk '$1 ~ "STATUS\\(.+\\)" {gsub("STATUS\\(|\\)","");print $1}')
	    IFS=$'\n' read -rd '' -a channelStatus <<<"$channelStatus"
	    if [ "${channelStatus[0]}" == "" ]; then
	       channelStatus="NOT RUNNING"
	    else
	       channelStatus=${channelStatus[0]}
	    fi
            printf "%-40s%-20s\n" "${channelList[$i]}" "$channelStatus"
	done
	printf "\n\n"

        count=0
        IFS=, read -ra ary <<<$2
        for i in "${!ary[@]}"; do
            queue_name=${ary[$i]};
            MQ_CMD_OUTPUT=$( eval 'echo "DISPLAY QSTATUS($queue_name) CURDEPTH IPPROCS MSGAGE LGETDATE LGETTIME LPUTDATE LPUTTIME" | runmqsc $1')

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
	       if [[ $queueDepth -gt 0 && $queueGetPutTimeDiff -gt $getTimePutTimeThresold ]]; then
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

        #Check message from response queue matches message depth from data out queue
	if [ -n "$4" ]; then
	   orghere=$(cd $(dirname $(ls -l $0 | awk '{print $NF;}')) && pwd)
           propFile="$orghere/../config/queueMapping.properties"
	   if [ -f "$propFile" ]; then
	      while IFS='=' read -r key value; do
	          KEY_CMD_OUTPUT=$( eval 'echo "DISPLAY CDEPTH($key) CURDEPTH" | runmqsc $2')
		  VAL_CMD_OUTPUT=$( eval 'echo "DISPLAY CDEPTH($value) CURDEPTH" | runmqsc $2')
	          keyQueueDepth=$(echo "$KEY_CMD_OUTPUT" | awk '$1 ~ "CURDEPTH\\(.+\\)" {gsub("CURDEPTH\\(|\\)","");print $1}')
	          valQueueDepth=$(echo "$VAL_CMD_OUTPUT" | awk '$1 ~ "CURDEPTH\\(.+\\)" {gsub("CURDEPTH\\(|\\)","");print $1}')
		  if [ "$keyQueueDepth" == "" -o "$valQueueDepth" == "" ]; then
		     continue;
                  fi
		  if [ "$keyQueueDepth" == "$valQueueDepth" ]; then
		     printf "%s\n\n" "Queue: $key depth: $keyQueueDepth equals with queue: $value depth: $valQueueDepth"
		  else
		     printf "%s\n\n" "Queue: $key depth: $keyQueueDepth is not equal to queue: $value depth: $valQueueDepth"
	          fi
              done < "$propFile"
           else
              echo "Properties file $propFile not found."
	   fi
	fi
    else
	printf "%s" "Queue Manager is not running"
    fi

    printf "\n\n%s\n" "$divider"
fi

