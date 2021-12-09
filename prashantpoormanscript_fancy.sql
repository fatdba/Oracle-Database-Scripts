--------------------------------------------------------------------------------------------------------------------
-- File name:   prashantpoormanscript1.sql
-- Version:     V1.1 (12-08-2021) Fancy Version
-- Purpose:     This script can be used on any Oracle DB to know what all running and for how long and waiting
--              Also provides details on SQL and SESSION level. 
-- Author:      Prashant Dixit The Fatdba www.fatdba.com
--------------------------------------------------------------------------------------------------------------------
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
col BLOCKING_INSTANCE for a20
select
'InstID .............................................: '||x.inst_id,
'SID ................................................: '||x.sid,
'Serial .............................................: '||x.serial#,
'Username ...........................................: '||x.username,
'SQLID ..............................................: '||x.sql_id,
'PHV ................................................: '||plan_hash_value,
'DISK_READS .........................................: '||sqlarea.DISK_READS,
'BUFFER_GETS ........................................: '||sqlarea.BUFFER_GETS,
'ROWS_PROCESSED ..... ...............................: '||sqlarea.ROWS_PROCESSED,
'Event  .............................................: '||x.event,
'OSUser .............................................: '||x.osuser,
'Status .............................................: '||x.status,
'BLOCKING_SESSION_STATUS ............................: '||x.BLOCKING_SESSION_STATUS,
'BLOCKING_INSTANCE ..................................: '||x.BLOCKING_INSTANCE,
'BLOCKING_SESSION ...................................: '||x.BLOCKING_SESSION,
'PROCESS ............................................: '||x.process,
'MACHINE ............................................: '||x.machine,
'PROGRAM ............................................: '||x.program,
'MODULE .............................................: '||x.module,
'ACTION .............................................: '||x.action,
'LOGONTIME ..........................................: '||TO_CHAR(x.LOGON_TIME, 'MM-DD-YYYY HH24:MI:SS') logontime,
'LAST_CALL_ET .......................................: '||x.LAST_CALL_ET,
'SECONDS_IN_WAIT ....................................: '||x.SECONDS_IN_WAIT,
'STATE ..............................................: '||x.state,
'RUNNING_SINCE ......................................: '||ltrim(to_char(floor(x.LAST_CALL_ET/3600), '09')) || ':' || ltrim(to_char(floor(mod(x.LAST_CALL_ET, 3600)/60), '09')) || ':' || ltrim(to_char(mod(x.LAST_CALL_ET, 60), '09')) RUNNING_SINCE,
'SQLTEXT ............................................: '||sql_text
from   gv$sqlarea sqlarea
,gv$session x
where  x.sql_hash_value = sqlarea.hash_value
and    x.sql_address    = sqlarea.address
and    sql_text not like '%select x.inst_id,x.sid ,x.serial# ,x.username ,x.sql_id ,plan_hash_value%'
and    x.status='ACTIVE'
and    sql_text not like '%select :"SYS_B_00"||x.inst_id, :"SYS_B_01"||x.sid, :"SYS_B_02"||x.serial#,%'
and x.USERNAME is not null
and x.SQL_ADDRESS    = sqlarea.ADDRESS
and x.SQL_HASH_VALUE = sqlarea.HASH_VALUE
order by RUNNING_SINCE desc;
