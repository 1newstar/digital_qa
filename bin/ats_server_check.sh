#!/bin/bash
#*****************************************************************************
#
#Author:     Arnab Kumar Ray
#Purpose:    This script captures details of long running queries, persistent
#            blocking sessions, long running index rebuilding job, long running
#            archival job, CPU utilization and Disk space usage in database.
#Date:       20/09/2019
#
#To run the sheel script, following parameters need to pass
# $1   - Host Name/IP Address of the machine to check live/Not Live
# $2   - Folder Path to check whether new file generated or not
#
#*****************************************************************************
#./ats_server_check.sh "www.google.com" "/media/sf_data"

if [[ $# -lt 2 ]]; then
    echo "Insufficient argument passed"
else
    divider="================================================================"
    printf "%s\n" "$divider"
    printf "%s\n" "ATS SERVER CHECK"
    dividerUnderline="----------------------------------------------------------------"
    printf "%s\n\n" "$dividerUnderline"

    if ping -c 1 -W 1 "$1" > /dev/null ; then
       printf "%s\n\n" "$1 is alive"
    else
       printf "%s\n\n" "$1 is not alive"
    fi

    result=$(ps -ef | grep TheLauncher | wc -l)
    if [[ $result -gt 1 ]]; then
        printf "%s\n\n" "The scheduler is running"
    else
        printf "%s\n\n" "The scheduler is stopped"
    fi

    if [ ! -d "$2" ]; then
       printf "%s\n\n" "$2 folder not found"
    else
       result=$(find $2 -maxdepth 1 -ctime -1 -type f | wc -l)
       if [[ $result -eq 0 ]]; then
           printf "%s\n\n" "No new file created from yesterday to today"
       else
           printf "%s\n\n" "Total $result new file(s) created from yesterday to today"
       fi
    fi
    printf "\n\n%s\n" "$divider"
fi
