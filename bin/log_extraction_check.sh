#!/bin/bash
#*****************************************************************************
#
#Author:     Arnab Kumar Ray
#Purpose:    This script extracts all ERROR trace logs from all the log files
#            where log date & time matches within specified date & time range.
#Date:       20/09/2019
#
#To run the sheel script, following parameters need to pass
# $1   - Host Name/IP Address of the virtual machine
# $2   - Time interval (in minutes) within which ERROR trace needs to extract
# $3   - Log files folder path
#
#*****************************************************************************

clear

if [[ $# -ne 3 ]]; then
    echo "Insufficient argument passed"
elif [[ "$2" -le 0 ]]; then
   echo "Value of parameter time_interval should be greater than 0"
elif [ ! -d "$3" ]; then
   echo "Value of parameter log_folder_path not found"
else
    fileFound="false"
    errorFound="false"
    fromDateTime=$( date --date="-$2min" "+%Y-%m-%d %H:%M:%S")
    toDateTime=$( date "+%Y-%m-%d %H:%M:%S" )
    divider="================================================================"
    printf "%s\n" "$divider"
    printf "%s\n" "APPLICATION LOG CHECK - $1"
    dividerUnderline="----------------------------------------------------------------"
    printf "%s\n\n" "$dividerUnderline"

    divider1="~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    printf "%s\n" "$divider1$divider1$divider1"
    printf "Extraction of ERROR from log file(s) within time range %s and %s\n" "$fromDateTime" "$toDateTime"
    printf "%s\n\n" "$divider1$divider1$divider1"

    for file in $( find $3 -mmin -$2 -type f \( -name "*log*" -o -name "*.log" \) -size +0c | sort )
    do
       if [ $fileFound == "false" ]; then
	  fileFound="true"
       fi
       fileName=$( basename "$file" )
       fName="${fileName%.*}"
       fExt="${fileName##*.}"
       #printf "\nPrcoessing file %s\n" "$fName.$fExt"
       #printf "%s\n" "$divider1"

       date_time_list=$( awk '{print $1 " " $2 " " $3 " " $4}' $file | sed 's/\]//g' | awk '{
          split("JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC", month, " ");
          for (i=1; i<=12; i++) mdigit[month[i]]=i;
          m=toupper(substr($0,4,3));
          dat=substr($0,8,4)"-"sprintf("%02d",mdigit[m])"-"substr($0,1,2)" "substr($0,13,8);
          print dat;
       }' | awk -v d1="$fromDateTime" -v d2="$toDateTime" '$0>=d1 && $0<=d2' )
       IFS=$'\n' read -rd '' -a date_time_arr <<<"$date_time_list"
       #echo "Array Length ${#date_time_arr[@]}"
       #for key in "${!date_time_arr[@]}";
       #do
          #echo "$key ${date_time_arr[$key]}"
       #done

       if [[ "${#date_time_arr[@]}" -eq 0 ]]; then
          #printf "Within the specified time range no ERROR details found in log file %s is:\n" "$fName.$fExt"
          continue
       elif [[ "${#date_time_arr[@]}" -eq 1 ]]; then
          startDateTime="${date_time_arr[0]}"
          endDateTime=$toDateTime
       else
          startDateTime="${date_time_arr[0]}"
          endDateTime="${date_time_arr[${#date_time_arr[@]}-1]}"
       fi

       if [ "$startDateTime" != "" -a "$endDateTime" != "" ]; then
          startDateTime=$( date -d "$startDateTime" "+%d %b %Y %H:%M:%S" )
          endDateTime=$( date -d "$endDateTime" "+%d %b %Y %H:%M:%S" )
          errorTrace=$( sed -n "/$startDateTime/,/$endDateTime/p" $file | grep -aP "(ERROR|^\tat |Exception|^Caused by: |\t... \d+ more)" )
          if [[ "${#errorTrace}" -gt 0 ]]; then
             if [ $errorFound == "false" ]; then
	        errorFound="true"
             fi
             printf "Within the specified time range ERROR details in log file %s is:\n" "$fName.$fExt"
             printf "%s\n" "$divider1$divider1$divider1"
             printf "%s\n\n" "$errorTrace"
          fi
       fi
    done

    if [ "$fileFound" == "false" -o "$errorFound" == "false" ]; then
       printf "No Records Found"
    fi

    printf "\n\n%s\n" "$divider"
fi
