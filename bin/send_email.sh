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
# $1   - Parent Job Name
# $2   - Job Name List separated by comma
# $3   - Report File Name
# $4   - From email address
# $5   - Recipient List email address separated by single space
# $6   - Folder path of the job. No need to pass parameter if job created
#        under jenkins home path
#
#*****************************************************************************

if [[ $# -lt 5 ]]; then
    echo "Insufficient argument passed"
else
    curDateTime=$(date "+%d-%m-%Y %H:%M:%S")
    folderPath=""
    extMsg=""

    if [ -n "$6" ]; then
       folderPath="$6"
    fi

    [[ -f "$3" ]] && attachments=( -A "$3" )
    appFlowCheckRpt="$JENKINS_HOME/workspace$folderPath/$1/AppFlowCheckReport.zip"
    [[ -f "$appFlowCheckRpt" ]] && attachments+=( -A "$appFlowCheckRpt" )
    [[ -f "$appFlowCheckRpt" ]] && extMsg="Please check AppFlowCheckReport.zip under workspace folder of $folderPath/$1."

    if [[ "${#attachments[@]}" -gt 0 ]]; then
        echo "PFA Digital QA log file for $2 job(s). $extMsg

Thank You,
Digital QA

**** System generated mail. This email box is not monitored, please do not reply or send mails to this ID ****

" | mailx -s "Digital QA Log File - ${curDateTime}" -r "$4" "${attachments[@]}" $5

	echo "Mail sent successfully"
    else
	echo "$3 file not found"
    fi
fi
