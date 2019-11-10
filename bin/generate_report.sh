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
#
#*****************************************************************************

clear

if [[ $# -lt 3 ]]; then
    echo "Insufficient argument passed"
else
    rm -f $3
    startLine="================================================================"
    endLine=$startLine

    declare -A childJobNames
    declare -A childBuildNumbers
    jobNameList=""
    numRows=0
    folderPathUrl=""
    folderPath=""

    if [ -n "$4" ]; then
       folderPathUrl=$(echo "$4" | sed 's/\//\/job\//g')
       folderPath=$(echo "$4" | sed 's/\//\/jobs\//g')
    fi
    echo "folderPathUrl => $folderPathUrl"
    #parentBuildDetails=$(curl -s $JENKINS_URL$folderPathUrl/job/$1/$2/api/json)
    #echo "parentBuildDetails => $parentBuildDetails"
	
    #while read jobName buildNumber ; do
    #   childJobNames[$numRows]=$jobName
    #   childBuildNumbers[$numRows]=$buildNumber
    #   numRows=$((numRows + 1))
    #done < <(echo "$parentBuildDetails" | jq -r '.subBuilds[]|"\(.jobName) \(.buildNumber)"')

    #IFS=$'\n' childJobNamesSorted=($(sort <<<"${childJobNames[*]}")); unset IFS

    #for i in "${!childJobNamesSorted[@]}"; do
    #   for j in "${!childJobNames[@]}"; do
    #      if [ "${childJobNamesSorted[$i]}" = "${childJobNames[$j]}" ]; then
	#     childJobNames[$j]="";
	#     jobName="${childJobNamesSorted[$i]}"
	#     buildNumber="${childBuildNumbers[$j]}"
	#     #printf "%s %s => %s => %s\n" "$i" "$j" "$jobName" "$buildNumber"
	#     sed -n "/$startLine/,/$endLine/p" $JENKINS_HOME/$folderPath/jobs/$jobName/builds/$buildNumber/log > tmp.txt
	#     buildlogLineCount=$(cat tmp.txt | sed '/^\s*$/d' | wc -l)
	#     if [[ buildlogLineCount -gt 0 ]]; then
	#	 cat tmp.txt >> $3
	#	 if [[ $((i+1)) -lt ${#childJobNamesSorted[@]} ]]; then
    #                 printf "\n\n" >> $3
    #             fi
	#     fi
	#     break
	#  fi
    #   done
    #done

    #rm -f tmp.txt

    #childJobNamesSorted=($(echo "${childJobNamesSorted[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    #for i in "${!childJobNamesSorted[@]}"; do
    #   jobNameList="${jobNameList}, ${childJobNamesSorted[i]}"
    #done
    #echo "${jobNameList}" | sed -e 's/^[ \t]*//'
    #echo "${jobNameList:2}"

fi
