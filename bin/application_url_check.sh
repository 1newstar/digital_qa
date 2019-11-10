#!/bin/bash
#*****************************************************************************
#
#Author:     Arnab Kumar Ray
#Purpose:    This script checks whether the specified URL is accessible or not.
#            After finish execution of this script, will display the HTTP
#            response status value with with code.
#Date:       20/09/2019
#
#To run this shell script, following parameters need to pass
# $1   - Application url.
#
#*****************************************************************************

divider="================================================================"
printf "%s\n" "$divider"
printf "%s\n" "APPLICATION URL CHECK"
dividerUnderline="----------------------------------------------------------------"
printf "%s\n\n" "$dividerUnderline"

wget --no-check-certificate -t 3 -O /dev/null $1

printf "%s\n" "$divider"
