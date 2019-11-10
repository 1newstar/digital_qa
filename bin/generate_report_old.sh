#!/bin/bash
#*****************************************************************************
#
#Author:     Arnab Kumar Ray
#Purpose:    This script consolidates the console log details of jenkins job.
#Date:       20/09/2019
#
#To run the sheel script, following parameters need to pass
# $1   - File name of generated report
# $2   - List of jobs separated by comma for which report needs to generate
# $3   - List of build iterations separated by comma for which report needs
#        to generate
# $4   - Folder path of the job. No need to pass parameter if job created
#        under jenkins home path
#
#Number of Jenkins Job(s) should match with number of Build Iteration(s).
#
#*****************************************************************************

if [[ $# -lt 3 ]]; then
    echo "Insufficient argument passed"
else
    rm -f $1
    startLine="================================================================"
    endLine="$startLine"
    folderPathUrl=""
    folderPath=""

    if [ -n "$4" ]; then
       folderPathUrl=$(echo "$4" | sed 's/\//\/job\//g')
       folderPath=$(echo "$4" | sed 's/\//\/jobs\//g')
    fi

    IFS=, read -ra ary1 <<<$2
    IFS=, read -ra ary2 <<<$3
    if [[ ${#ary1[@]} -ne ${#ary2[@]} ]]; then
        echo "Number of Jobs must be matched with number of Iteration"
    else

	for i in "${!ary1[@]}"; do
           JOB_NAME=$(echo ${ary1[$i]} | sed -e 's/ //g');
	   NUM_OF_ITE=$(echo ${ary2[$i]} | sed -e 's/ //g');
           BUILD_NUMBER=$(curl -s $JENKINS_URL$folderPathUrl/job/$JOB_NAME/lastBuild/buildNumber)

           if [ "$BUILD_NUMBER" == "" -o "$NUM_OF_ITE" == "" ]; then
               continue
           fi

           for ((j=1; j<=$NUM_OF_ITE; j++)); do
              #echo "$j  Last Build Number for $JOB_NAME job is $BUILD_NUMBER"
              sed -n "/$startLine/,/$endLine/{/$endLine/!p}" $JENKINS_HOME/$folderPath/jobs/$JOB_NAME/builds/$BUILD_NUMBER/log >> $1

              if [[ $((j+1)) -le $NUM_OF_ITE ]]; then
                  BUILD_NUMBER=$((BUILD_NUMBER-1))
                  printf "******************************************************\n\n" >> $1
              fi

           done

           if [[ $((i+1)) -lt ${#ary1[@]} ]]; then
               printf "\n\n" >> $1
           fi

         done
    fi
fi
