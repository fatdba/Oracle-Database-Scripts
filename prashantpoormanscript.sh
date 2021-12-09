#!/bin/ksh
sqlplus /nolog << EOF
CONNECT username/Password@connection_string
set linesize 400
set pagesize 400
col ACTION for a22
col USERNAME for a9
col SQL_ID for a16
col EVENT for a20
col OSUSER for a10
col PROCESS for a8
col MACHINE for a15
col OSUSER for a8
col PROGRAM for a15
col module for a20
select x.inst_id,x.sid
,x.serial#
,x.username
,x.sql_id
,plan_hash_value as PHV
,sqlarea.DISK_READS
,sqlarea.BUFFER_GETS
,sqlarea.ROWS_PROCESSED
,x.event
,x.osuser
,x.status
,x.BLOCKING_SESSION_STATUS
,x.BLOCKING_INSTANCE
,x.BLOCKING_SESSION
,x.process
,x.machine
,x.program
,x.module
,x.action
,TO_CHAR(x.LOGON_TIME, 'MM-DD-YYYY HH24:MI:SS') logontime
,x.LAST_CALL_ET
,x.SECONDS_IN_WAIT
,x.state
,sql_text,
ltrim(to_char(floor(x.LAST_CALL_ET/3600), '09')) || ':'
 || ltrim(to_char(floor(mod(x.LAST_CALL_ET, 3600)/60), '09')) || ':'
 || ltrim(to_char(mod(x.LAST_CALL_ET, 60), '09'))    RUNNING_SINCE
from   gv\$sqlarea sqlarea
,gv\$session x
where  x.sql_hash_value = sqlarea.hash_value
and    x.sql_address    = sqlarea.address
and    sql_text not like '%select x.inst_id,x.sid ,x.serial# ,x.username ,x.sql_id ,plan_hash_value%'
and    x.status='ACTIVE'
and x.USERNAME is not null
and x.SQL_ADDRESS    = sqlarea.ADDRESS
and x.SQL_HASH_VALUE = sqlarea.HASH_VALUE
order by RUNNING_SINCE desc;
 
SPOOL OFF
EXIT;
EOF
