#!/bin/bash
#***********************************************************************************
#
#Auther:     Anirban Nandi
#Purpose:    This script will check db2 table level SELECT query
#
#Date:       19-11-2019
#
#To run the sheel script, following parameters need to pass
# $1   - db2 database name
# $2   - db2 username
# $3   - db2 password
# $4   - Application name
#
#***********************************************************************************

#
# This method executes the sql queries after login into specific database.
#
executeSQLQuery() {
   result=$(db2 <<EOF
	connect to $2 user $3 using $4;
	$1;
	db2 connect reset;
   EOF);
   printf "%s" "$result"
}

if [[ $# -ne 4 ]]; then
    echo "Insufficient argument passed"
else
    orghere=$(cd $(dirname $(ls -l $0 | awk '{print $NF;}')) && pwd)
    propFile="$orghere/../config/sqlQueries.properties"

    if [ -f "$propFile" ]; then
       hostName=$(hostname --fqdn)
       divider="================================================================"
       printf "%s\n" "$divider"
       printf "%s\n" "DB2 Table level SELECT Query - `hostname`"
       dividerUnderline="----------------------------------------------------------------"
       printf "%s\n\n" "$dividerUnderline"

       divider1="~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	
       var=(sqlQueries)
       count=0
       while IFS='=' read -r key value; do
	 if [[ $key == $4.* ]]; then
	     sqlQueries["$count"]="$value"
	     count=$((count + 1))
	 fi
       done < "$propFile"

       for sqlQuery in "${sqlQueries[@]}"; do
	   printf "%s\n" "$sqlQuery"
	   printf "%s\n" "$divider"
	   executeSQLQuery "$sqlQuery" $1 $2 $3
	   printf "\n"
       done

       printf "\n\n%s\n" "$divider"

    else
       echo "Properties file $propFile not found."
    fi
fi

