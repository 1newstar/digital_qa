#!/bin/bash
#*****************************************************************************
#
#Author:     Arnab Kumar Ray
#Purpose:    This script consolidates the console log details of jenkins job.
#Date:       20/09/2019
#
#To run the sheel script, following parameters need to pass
# $1   - Parent job name for which build console log of all child jobs need
#        to consolidate
# $2   - Parent job build number for which build console log of all child jobs
#        need to consolidate
# $3   - File name of generated report
# $4   - Folder path of the job. No need to pass parameter if job created
#        under jenkins home path
# $5   - jenkins user name
# $6   - jenkins password
# $7   - Error file name which will contain only error lines
# $8   - Error line pattern. For multiple errors use pipe separator(i.e. |)
#
#*****************************************************************************

if [[ $# -lt 3 ]]; then
    echo "Insufficient argument passed"
else
    rm -f $3
    rm -f $8
    startLine="================================================================"
    endLine=$startLine

    declare -A childJobNames
    declare -A childBuildNumbers
    jobNameList=""
    numRows=0
    folderPathUrl=""
    folderPath=""
    curlCredential=""

    if [ -n "$4" ]; then
       folderPathUrl=$(echo "$4" | sed 's/\//\/job\//g')
       folderPath=$(echo "$4" | sed 's/\//\/jobs\//g')
    fi
    if [ -n "$5" -a -n "$6" ]; then
       curlCredential="-u $5:$6"
    fi

    parentBuildDetails=$(curl $curlCredential -s $JENKINS_URL$folderPathUrl/job/$1/$2/api/json)

    #fetch child job name and corresponding build number from parent job
    while read jobName buildNumber ; do
       childJobNames[$numRows]=$jobName
       childBuildNumbers[$numRows]=$buildNumber
       numRows=$((numRows + 1))
    done < <(echo "$parentBuildDetails" | jq -r '.subBuilds[]|"\(.jobName) \(.buildNumber)"')

    #retrieve log details of ascending order sorted child job name list
    IFS=$'\n' childJobNamesSorted=($(sort <<<"${childJobNames[*]}")); unset IFS
    for i in "${!childJobNamesSorted[@]}"; do
       for j in "${!childJobNames[@]}"; do
          if [ "${childJobNamesSorted[$i]}" = "${childJobNames[$j]}" ]; then
	     childJobNames[$j]="";
	     jobName="${childJobNamesSorted[$i]}"
	     buildNumber="${childBuildNumbers[$j]}"
	     #printf "%s %s => %s => %s\n" "$i" "$j" "$jobName" "$buildNumber"
	     sed -n "/$startLine/,/$endLine/p" $JENKINS_HOME/$folderPath/jobs/$jobName/builds/$buildNumber/log > tmp.txt
	     buildlogLineCount=$(cat tmp.txt | sed '/^\s*$/d' | wc -l)
	     if [[ buildlogLineCount -gt 0 ]]; then
		 cat tmp.txt >> $3
		 if [[ $((i+1)) -lt ${#childJobNamesSorted[@]} ]]; then
                     printf "\n\n" >> $3
                 fi
	     fi
	     break
	  fi
       done
    done

    rm -f tmp.txt

    if [ -n "$7" -a -n "$8" ]; then
       if test -f "$3"; then
          cat "$3" | grep -E -i "$8" > $7
       fi
    fi

    childJobNamesSorted=($(echo "${childJobNamesSorted[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    for i in "${!childJobNamesSorted[@]}"; do
       jobNameList="${jobNameList}, ${childJobNamesSorted[i]}"
    done

    echo "${jobNameList:2}" | sed "s/\(.*\), /\1 and /"

fi
