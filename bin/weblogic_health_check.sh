#!/bin/bash
#*****************************************************************************
#
#Author:     Arnab Kumar Ray
#Purpose:    This script captures WebLogic server's statistics. Internally it
#            calls the weblogic_health.py python script to gather statistical
#            information.
#Date:       20/09/2019
#
#To run the sheel script, following parameters need to pass
# $1   - Weblogic server version
# $2   - Admin server path of WebLogic server
# $3   - Host name of WebLogic admin server console
# $4   - Port number of WebLogic admin server console
# $5   - User name to access WebLogic admin server console ui
# $6   - Password to access WebLogic admin server console ui
#
#*****************************************************************************

clear

if [[ $# -ne 6 ]]; then
    echo "Insufficient argument passed"
elif [ ! -d "$2" ]; then
    echo "Value of parameter admin_server_path not found"
elif [[ "$4" -le 0 ]]; then
    echo "Value of parameter admin_server_port should be greater than 0"
else
    divider="================================================================"
    printf "%s\n" "$divider"
    printf "%s\n" "WEBLOGIC SERVER HEALTH CHECK - $3"
    dividerUnderline="----------------------------------------------------------------"
    printf "%s\n\n" "$dividerUnderline"

    orghere=$(cd $(dirname $(ls -l $0 | awk '{print $NF;}')) && pwd)

    CONFIG_DIR=$orghere/../config
    export CONFIG_DIR

    LIB_DIR=$orghere/../lib
    export LIB_DIR

    WL_HOME=$2
    CLASSPATH=$WL_HOME/server/lib/weblogic.jar
    if [ "$1" = "10g" ]; then
        . $WL_HOME/common/bin/commEnv.sh
    elif [ "$1" = "12c" ]; then
        . $WL_HOME/server/bin/setWLSEnv.sh
        for i in $WL_HOME/../oracle_common/modules/*.jar; do
            CLASSPATH=$CLASSPATH:$i
        done
    else
	printf "%s\n\n" "Wrong WebLogic version $1"
	exit
    fi

    java -cp $CLASSPATH weblogic.WLST $LIB_DIR/weblogic_health.py $3 $4 $5 $6

    printf "\n\n%s\n" "$divider"
fi
