#!/bin/bash
clear

if [[ $# -ne 2 ]];then
    echo "Insufficient argument passed"
elif [ ! -d "$2" ] ; then
    echo "Directory $2 does not exists"
else
    divider="================================================================"
    printf "%s\n" "$divider"
    printf "%s\n" "APPLICATION LOG CHECK - $1"
    dividerUnderline="----------------------------------------------------------------"
    printf "%s\n\n" "$dividerUnderline"

    fromDateTime=$( date --date="-$1min" "+%Y-%m-%d %H:%M:%S" )
    toDateTime=$( date "+%Y-%m-%d %H:%M:%S" )
    printf "Extraction of ERROR from log file(s) within time range %s and %s\n" "$fromDateTime" "$toDateTime"
    printf "%s\n\n" "$divider$divider$divider"

    for file in $( find $2 -mmin -$1 -type f -size +0c -iname '*log*' | sort )
    do
       fileName=$( basename "$file" )
       fName="${fileName%.*}"
       fExt="${fileName##*.}"
       #printf "\nPrcoessing file %s\n" "$fName.$fExt"
       #printf "%-40s\n" "$divider"

       date_time_list=$( awk -v d1="$fromDateTime" -v d2="$toDateTime" '$0>=d1 && $0<=d2 || $0~d2' $file | awk '/^[0-9.]+/ {print $1 " " $2}')
       IFS=$'\n' read -rd '' -a date_time_arr <<<"$date_time_list"

       #echo "Array Length ${#date_time_arr[@]}"
       #for key in "${!date_time_arr[@]}";
       #do
       #   echo "$key ${date_time_arr[$key]}"
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
          errorTrace=$( sed -n "/$startDateTime/,/$endDateTime/p" $file | grep -aP "(ERROR|^\tat |Exception|^Caused by: |\t... \d+ more)" )
          if [[ "${#errorTrace}" -gt 0 ]]; then
             printf "Within the specified time range ERROR details in log file %s is:\n" "$fName.$fExt"
             printf "%s\n" "$divider$divider$divider"
             printf "%s\n\n" "$errorTrace"
          fi
       fi
    done
    printf "\n\n%s" "$divider"
fi
