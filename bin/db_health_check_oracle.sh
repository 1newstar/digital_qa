#!/bin/ksh
#*****************************************************************************
#
#Author:     Arnab Kumar Ray
#Purpose:    This script captures details of long running queries, persistent
#            blocking sessions, long running index rebuilding job, long running
#            archival job, CPU utilization and Disk space usage in database.
#Date:       20/09/2019
#
#To run the sheel script, following parameters need to pass
# $1   - Oracle SID
# $2   - Oracle Home Path
# $3   - Schema Name
# $4   - Number of records needs to select
# $5   - CPU usage threshold
#
#*****************************************************************************

#
# This method prints the top sql queries based on elapsed time.
#
topNSQLQueryElpTime() {
$ORACLE_HOME/bin/sqlplus -s /nolog <<EOF
connect / as sysdba

SELECT ROWNUM AS rank, a.sql_id,a.hash_value,a.plan_hash_value,execs,cput,elapsed_time FROM (
   SELECT * FROM (
     SELECT
        SQL_ID,
        HASH_VALUE,
        plan_hash_value,
        SUM(EXECUTIONS) execs,
        SUM(BUFFER_GETS) bgets,
        SUM(CPU_TIME) cput,
        round(sum(ELAPSED_TIME)/(SUM(EXECUTIONS)*1000000),2) elapsed_time
     FROM gv\$sql
     WHERE executions > 1000 and PARSING_SCHEMA_NAME in ('$1')
     GROUP BY SQL_ID,HASH_VALUE,plan_hash_value
     -- ORDER BY HASH_VALUE
  ) ORDER BY elapsed_time  DESC
) a WHERE ROWNUM <= $2;

exit
EOF
}

#
# This method prints the top sql queries based on disk io.
#
topNSQLQueryDiskIO() {
$ORACLE_HOME/bin/sqlplus -s /nolog <<EOF
connect / as sysdba

SELECT rownum rank,round(Disk_Reads) DiskReads, Executions, SQL_ID
FROM (
   SELECT Disk_Reads, Executions, SQL_ID, LTRIM(SQL_Text) SQL_Text, SQL_FullText, Operation, Options, Row_Number() OVER (Partition By sql_text ORDER BY Disk_Reads * Executions DESC) KeepHighSQL
   FROM (
      SELECT Avg(Disk_Reads) OVER (Partition By sql_text) Disk_Reads, Max(Executions) OVER (Partition By sql_text) Executions, t.SQL_ID, sql_text, sql_fulltext, p.operation,p.options
      FROM gv\$sql t, gv\$sql_plan p
      WHERE t.hash_value=p.hash_value AND p.operation='TABLE ACCESS'
      AND p.options='FULL' AND p.object_owner NOT IN ('SYS','SYSTEM')
      AND t.Executions > 1
      )
    ORDER BY DISK_READS * EXECUTIONS DESC
    )
WHERE KeepHighSQL = 1
AND rownum <= $1;

exit
EOF
}

#
# This method prints the long running transactions in database.
#
longRunningTransactions() {
$ORACLE_HOME/bin/sqlplus -s /nolog <<EOF
connect / as sysdba

select s.inst_id,
   t.start_time,
   t.status txn_status,
   s.status sess_status,
   s.sid,
   s.serial#,
   s.program,
   s.process,
   s.username,
   s.logon_time,
   s.machine,
   s.sql_id,(select sql_text from gv\$sql q where q.sql_id=s.sql_id and rownum<2) SQL_TEXT
from gv\$session s,gv\$transaction t
where s.saddr=t.ses_addr and t.start_date<sysdate-4/1440
order by t.start_time;

exit
EOF
}

#
# This method prints the blocking sessions in database.
#
blockingSessions() {
$ORACLE_HOME/bin/sqlplus -s /nolog <<EOF
connect / as sysdba

--set PAGESIZE 1000
--set LINESIZE 120 trimspool on
--SET verify off head on

col blocker_status HEADING 'BLOCKER|STATUS'
col blocking_sqlid HEADING 'BLOCKER|SQL_ID'
col blocking_sqlid_prev HEADING 'BLOCKER|SQL_ID|PREV'
col Blocker_sql_service HEADING 'BLOCKER|SQL|SERVICE'
col Waiting_sql_service HEADING 'WAITING|SQL|SERVICE'


select  distinct
to_char(systimestamp,'DD-MON-YYYY HH24:MI:SSxFF TZH:TZM')  TimeStamp
,sys_context('userenv', 'db_name') DB_NAME
,(select INSTANCE_NAME from gv\$instance where INST_ID = sb.inst_id) blocking_Instance
,(select INSTANCE_NAME from gv\$instance where INST_ID = sw.inst_id) Waiting_Instance
,sb.SERVICE_NAME Blocker_sql_service
,sw.SERVICE_NAME Waiting_sql_service
,sb.event,
   '''' || sb.sid || ',' || sb.serial# || ',@' || sb.inst_id || '''' blocking_session
,  '''' || sw.sid || ',' || sw.serial# || ',@' || sw.inst_id || '''' waiting_session
,  sb.status blocker_status
,  TRUNC(waiting.ctime/60) min_waiting
,  waiting.request
,  sqlb.sql_id blocking_sqlid
,  oldq.sql_id blocking_sqlid_prev
,  sqlb.sql_text blocking_sql
,  oldq.sql_text blocking_sql_prev
from (select *
      from gv\$lock
      where block != 0
      and type = 'TX') blocker
,    gv\$lock            waiting,
gv\$session sb,gv\$session sw,gv\$sql sqlb, gv\$sql oldq
where waiting.type='TX'
and waiting.block = 0
and waiting.id1 = blocker.id1
and sb.inst_id = blocker.inst_id and sb.sid = blocker.sid
and  sw.inst_id = waiting.inst_id and sw.sid = waiting.sid
and sqlb.inst_id (+) = sb.inst_id and sqlb.address (+)= sb.sql_address
and oldq.inst_id (+) = sb.inst_id and oldq.address (+)= sb.PREV_SQL_ADDR
and waiting.ctime > 240;

exit
EOF
}

#
# This method prints the Long running index rebuild jobs in database.
#
longRunningIndexRebuild() {
$ORACLE_HOME/bin/sqlplus -s /nolog <<EOF
connect / as sysdba

select sid,serial#,INST_ID,
round((LAST_CALL_ET/60),2) etime_mins,sql.sql_id,sql.sql_text,
status,sess.MODULE,event,blocking_session
from gv\$session sess, v\$sql sql
where sess.SQL_ADDRESS = sql.ADDRESS
and status='ACTIVE'
AND type<>'BACKGROUND'
and type='USER'
and sess.program like '%sql%'
and upper(sql.sql_text) like '%ALTER INDEX%'
and sql.sql_text not like 'select sid,serial#,INST_ID%'
order by (LAST_CALL_ET/1000000/60) desc;

exit
EOF
}

#
# This method prints the long running archival jobs in database.
#
longRunningArchival() {
$ORACLE_HOME/bin/sqlplus -s /nolog <<EOF
connect / as sysdba

SELECT USERNAME,inst_id,sid, serial#,sql_id, opname,start_time,
last_update_time, round(time_remaining/60,2) "REMAIN MINS",
round(elapsed_seconds/60,2) "ELAPSED MINS",
round((time_remaining+elapsed_seconds)/60,2)"TOTAL MINS", message TIME
FROM gv\$session_longops
WHERE sofar<>totalwork
AND time_remaining <> '0'
order by elapsed_seconds desc;

exit
EOF
}

#
# This method prints the hour wise CPU statistics for a specified CPU threshold.
#
cpuStatistics() {
$ORACLE_HOME/bin/sqlplus -s /nolog <<EOF
connect / as sysdba

set term off
spool $2
COL ecr_dbid NEW_V ecr_dbid;
SELECT 'get_dbid', TO_CHAR(dbid) ecr_dbid FROM v\$database;

COL ecr_min_snap_id NEW_V ecr_min_snap_id;
SELECT 'get_min_snap_id', TO_CHAR(MIN(snap_id)) ecr_min_snap_id FROM dba_hist_snapshot WHERE dbid = &&ecr_dbid.
and END_INTERVAL_TIME >= trunc(sysdate-1);
set term on

----------------------------------------------------
-- Main report
col timed for a15 head " "
col inst for 9999 head "Instance"
col host_name for a20 head "Hostname"
col OSCPUPCT for 990.00 head "CPU Average %"
col PEAK_OSCPUPCT for 990.00 head "Peak CPU %"
break on timed skip 1

WITH
cpuwl AS (
SELECT /*+ MATERIALIZE NO_MERGE */
       instance_number,
       snap_id,
       SUM(CASE WHEN stat_name = 'BUSY_TIME' THEN value ELSE 0 END) busy_time,
       SUM(CASE WHEN stat_name = 'NUM_CPUS' THEN value ELSE 0 END) cpu
  FROM dba_hist_osstat
 WHERE snap_id >= &&ecr_min_snap_id.
   AND dbid = &&ecr_dbid.
   AND stat_name IN ('BUSY_TIME','NUM_CPUS')
 GROUP BY
       instance_number,
       snap_id
)
select * from
(
SELECT /*+ MATERIALIZE NO_MERGE */
       to_char(s0.END_INTERVAL_TIME,'DD-Mon-YYYY HH24') timed,
       s0.instance_number inst,
       i.host_name,
       AVG ( (((h1.busy_time - h0.busy_time)/100) / (((CAST(s1.end_interval_time AS DATE) - CAST(s1.begin_interval_time AS DATE)) * 86400)*h1.cpu) )*100) as oscpupct,
       MAX ( (((h1.busy_time - h0.busy_time)/100) / (((CAST(s1.end_interval_time AS DATE) - CAST(s1.begin_interval_time AS DATE)) * 86400)*h1.cpu) )*100) as peak_oscpupct
  FROM cpuwl h0,
       cpuwl h1,
       dba_hist_snapshot s0,
       dba_hist_snapshot s1,
       gv\$instance i
 WHERE s0.snap_id >= &&ecr_min_snap_id.
   AND s0.dbid = &&ecr_dbid.
   AND s0.snap_id = h0.snap_id
   AND s0.instance_number = h0.instance_number
   AND h1.instance_number = h0.instance_number
   AND h1.snap_id = h0.snap_id + 1
   AND s1.snap_id >= &&ecr_min_snap_id.
   AND s1.dbid = &&ecr_dbid.
   AND s1.snap_id = h1.snap_id
   AND s1.instance_number = h1.instance_number
   AND s1.snap_id = s0.snap_id + 1
   AND s1.startup_time = s0.startup_time
   AND s0.instance_number = i.inst_id
 GROUP BY to_char(s0.END_INTERVAL_TIME,'DD-Mon-YYYY HH24'),i.host_name, s0.instance_number
 ORDER BY to_char(s0.END_INTERVAL_TIME,'DD-Mon-YYYY HH24'),s0.instance_number
) a
where a.oscpupct > $1 OR a.peak_oscpupct > $1;
spool off;

exit
EOF
}

#
# This method prints the ASM Disk usage details in database.
#
diskUsage() {
$ORACLE_HOME/bin/sqlplus -s /nolog <<EOF
connect / as sysdba

set pages 400 lines 200
col path form a60
col failgroup form a22
col name form a27

PROMPT Checking for disks that are not part of any disk group

select a.name,b.name,b.mount_status || '.' || b.header_status || '.' || b.mode_status || '.' || b.state status,b.path
from v\$asm_diskgroup a, v\$asm_disk b
where a.group_number(+)=b.group_number
and b.mount_status!='CACHED'
order by 1,2;

PROMPT Checking for rebalance operations

col name form a15
select d.name, o.*
from   gv\$asm_operation o, gv\$asm_diskgroup d
where d.inst_id=o.inst_id and o.group_number=d.group_number
and o.state='RUN'
/

PROMPT ASM disk group summary

col group_number for 99 head "Grp No"
col group_name for a30 head "ASM Diskgroup Name"
col state for a11 head "Status"
col type for a6 head "Type"
col total_gb for 999,999,990 head "Size (GB)"
col used_gb for 999,999,990 head "Used (GB)"
col free_gb for 999,999,990 head "Free (GB)"
col pct_used for 990.00 head "Used %"

SELECT group_number
     , name group_name
     , state
     , type
     , total_mb/1024 total_gb
     , (total_mb-free_mb)/1024 used_gb
     , free_mb/1024 free_gb
     , case when round(100-(free_mb/total_mb*100),2) > 80 then
             to_char(round(100-(free_mb/total_mb*100),2)) || ' <--- Over 80%'
       else to_char(round(100-(free_mb/total_mb*100),2))
       end  pct_used
FROM v\$asm_diskgroup g
ORDER BY 1;

exit
EOF
}

if [[ $# -ne 5 ]]; then
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
    hostName=$(hostname --fqdn)
    cpuStatisticsFile="cpuStatistics$(date +%d%m%Y%H%M%S%N).txt"

    divider="================================================================"
    printf "%s\n" "$divider"
    printf "%s\n" "ORACLE SERVER HEALTH CHECK - $hostName"
    dividerUnderline="----------------------------------------------------------------"
    printf "%s\n\n" "$dividerUnderline"

    export ORACLE_SID=$1
    export ORACLE_HOME=$2/db_1
    #export TNS_ADMIN=${ORACLE_HOME}/network/admin
    export PATH=$PATH:${ORACLE_HOME}/bin
    #export ORAENV_ASK=NO

    divider1="~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

    printf "%s\n" "Top $5 sqls based on elapsed time"
    printf "%s" "$divider1"
    topNSQLQueryElpTime $3 $4;

    printf "\n%s\n" "Top $4 sqls based on disk io"
    printf "%s" "$divider1"
    topNSQLQueryDiskIO $4;

    printf "\n%s\n" "Long running transactions in database"
    printf "%s" "$divider1"
    longRunningTransactions;

    printf "\n%s\n" "Blocking sessions in database"
    printf "%s\n" "$divider1"
    blockingSessions;

    printf "\n%s\n" "Long running index rebuild jobs in database"
    printf "%s\n" "$divider1"
    longRunningIndexRebuild;

    printf "\n%s\n" "Long running archival jobs in database"
    printf "%s\n" "$divider1"
    longRunningArchival;

    printf "\n%s\n" "CPU statistics - hours where cpu>$5%"
    printf "%s\n" "$divider1"
    output=$(cpuStatistics $6 "$cpuStatisticsFile")
    sed -i "/old \|new /d" "$cpuStatisticsFile"
    cat "$cpuStatisticsFile"
    rm -f "$cpuStatisticsFile"

    export ORACLE_SID="+ASM"
    export ORACLE_HOME=$2/grid
    printf "\n%s\n" "Disk usage - asm details in database"
    printf "%s\n" "$divider1"
    diskUsage;

    printf "\n\n%s\n" "$divider"
fi
