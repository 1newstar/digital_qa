#!/bin/ksh
#*****************************************************************************
#
#Author:     Arnab Kumar Ray
#Purpose:    This script execute list of sql queries (passing as parameter).
#Date:       04/10/2019
#
#To run the sheel script, following parameters need to pass
# $1   - Oracle SID
# $2   - Oracle Home Path
# $3   - Application name
#
#*****************************************************************************

executeSQLQuery() {
$ORACLE_HOME/bin/sqlplus -s /nolog <<EOF
connect / as sysdba
SET HEADING ON
#SET LINESIZE 32767
SET UNDERLINE ON
SET SERVEROUTPUT ON
SET FEEDBACK ON
set trimspool on
set headsep on

$1;

exit
EOF
}

clear
if [[ $# -ne 3 ]]; then
   echo "Insufficient argument passed"
elif [ ! -d "$2" ]; then
   echo "Value of parameter oracle_home not found"
elif [ ! -d "$2/db_1/bin" ]; then
   echo "Directory \"$2/db_1/bin\" not found"
elif [ ! -x "$2/db_1/bin/sqlplus" ]; then
   echo "Executable \"$2/db_1/bin/sqlplus\" not found"
elif [ ! -x "$2/db_1/bin/tnsping" ]; then
   echo "Executable \"$2/db_1/bin/tnsping\" not found"
else
   orghere=$(cd $(dirname $(ls -l $0 | awk '{print $NF;}')) && pwd)
   propFile="$orghere/../config/sqlQueries.properties"

   if [ -f "$propFile" ]; then
      divider="================================================================"
      printf "%s\n" "$divider"
      printf "%s\n" "SQL Query Executor"
      dividerUnderline="----------------------------------------------------------------"
      printf "%s\n\n" "$dividerUnderline"

      export ORACLE_SID=$1
      export ORACLE_HOME=$2/db_1
      export PATH=$PATH:${ORACLE_HOME}/bin

      divider1="~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
      var=(sqlQueries)
      count=0
      while IFS='=' read -r key value; do
        if [[ $key == $3.* ]]; then
            #echo "$key => $value"
            sqlQueries["$count"]="$value"
            count=$((count + 1))
        fi
      done < "$propFile"

      #echo "${#sqlQueries[@]}"
      for sqlQuery in "${sqlQueries[@]}"; do
         #echo $i
         printf "%s\n" "$sqlQuery"
         printf "%s\n" "$divider1"
	 executeSQLQuery "$sqlQuery"
      done

      printf "\n\n%s\n" "$divider"

    else
      echo "$propFile file not found."
    fi
fi
