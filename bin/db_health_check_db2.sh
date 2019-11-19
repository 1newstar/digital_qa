#!/bin/bash
#***********************************************************************************
#
#Auther:     Anirban Nandi
#Purpose:    This script will check db2 database connectivity, connection pool
#            count, long running queries and deadlock details
#Date:       15-11-2019
#
#To run the sheel script, following parameters need to pass
# $1   - db2 name of the db2 instance
# $2   - db2 username
# $3   - db2 password
#
#***********************************************************************************

#
# This method checks the db2 connection
#
databaseConnectionCheck() {
   result=`db2 connect to $1 user $2 using $3`
   if [ -z "$result" ]; then
       printf "%s" "Unable to connect database $1 by user $2"
   else
       printf "%s" "Successfully connected database $1 by user $2"
       #Connect Reset breaks a connection to a database , but does not terminate the back-end process
       #If an application is connected to a database, or a process is in the middle of a unit of work, TERMINATE causes the database connection to be lost
       #https://technowizardz.wordpress.com/2012/07/11/connect-disconnect-from-db2-instance/
       result=`db2 connect reset`
       printf "%s" "$result"
   fi
}

#
# This method monitor database connection pool
#
connectionPoolCount() {
   result=$(db2 <<EOF
	db2 list application | grep -i "WWPRT3" | wc -l
   EOF);
   printf "%s" "$result"
}

#
# This method prints the long running queries in database.
#
longRunningQueries() {
   result=$(db2 <<EOF
	connect to $1 user $2 using $3
	SELECT ELAPSED_TIME_MIN,SUBSTR(AUTHID,1,10) AS AUTH_ID,AGENT_ID,
	       APPL_STATUS,SUBSTR(STMT_TEXT,1,200) AS SQL_TEXT
	FROM SYSIBMADM.LONG_RUNNING_SQL
	WHERE ELAPSED_TIME_MIN > 0
	ORDER BY ELAPSED_TIME_MIN DESC
	WITH UR;
	db2 connect reset;
   EOF);
   printf "%s" "$result"
}

#
# This method prints the database deadlock details.
#
deadlockDetails() {
   result=$(db2 <<EOF
	db2 list applications show detail | grep -i lock
   EOF);
   printf "%s" "$result"
}

if [[ $# -ne 3 ]]; then
    echo "Insufficient argument passed"
else
    hostName=$(hostname --fqdn)
    divider="================================================================"
    printf "%s\n" "$divider"
    printf "%s\n" "DB2 SERVER HEALTH CHECK - $hostName"
    dividerUnderline="----------------------------------------------------------------"
    printf "%s\n\n" "$dividerUnderline"

    divider1="~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

    printf "%s\n" "Database connection check"
    printf "%s\n" "$divider1"
    databaseConnectionCheck $1 $2 $3;

    printf "\n%s\n" "Connection pool count"
    printf "%s\n" "$divider1"
    connectionPoolCount

    printf "\n%s\n" "Long running queries"
    printf "%s\n" "$divider1"
    longRunningQueries $1 $2 $3;

    printf "\n%s\n" "Database deadlock details"
    printf "%s\n" "$divider1"
    deadlockDetails

    printf "\n\n%s\n" "$divider"
fi

