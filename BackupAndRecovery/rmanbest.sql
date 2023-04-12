REM -------------------------------
REM Script to monitor rman backup/restore operations
REM To run from sqlplus:   @monitor '<dd-mon-rr hh24:mi:ss>'
REM Example:  
--SQL>spool monitor.out
--SQL>@rmanbest '12-Apr-23 19:03:00'
REM where <date> is the start time of your rman backup or restore job
REM Run monitor script periodically to confirm rman is progessing
REM -------------------------------

alter session set nls_date_format='dd-mon-rr hh24:mi:ss';
set lines 1500
set pages 100
col CLI_INFO format a10
col spid format a5
col ch format a20
col seconds format 999999.99
col filename format a65
col bfc  format 9
col "% Complete" format 999.99
col event format a40
set numwidth 10

select sysdate from dual;

REM gv$session_longops (channel level)

prompt
prompt Channel progress - gv$session_longops:
prompt
select s.inst_id, o.sid, CLIENT_INFO ch, context, sofar, totalwork,
                    round(sofar/totalwork*100,2) "% Complete"
     FROM gv$session_longops o, gv$session s
     WHERE opname LIKE 'RMAN%'
     AND opname NOT LIKE '%aggregate%'
     AND o.sid=s.sid
     AND totalwork != 0
     AND sofar <> totalwork;

REM Check wait events (RMAN sessions) - this is for CURRENT waits only
REM use the following for 11G+
prompt
prompt Session progess - CURRENT wait events and time in wait so far:
prompt
select inst_id, sid, CLIENT_INFO ch, seq#, event, state, wait_time_micro/1000000 seconds
from gv$session where program like '%rman%' and
wait_time = 0 and
not action is null;

REM use the following for 10G
--select  inst_id, sid, CLIENT_INFO ch, seq#, event, state, seconds_in_wait secs
--from gv$session where program like '%rman%' and
--wait_time = 0 and
--not action is null;

REM gv$backup_async_io
prompt
prompt Disk (file and backuppiece) progress - includes tape backuppiece
prompt if backup_tape_io_slaves=TRUE:
prompt
select s.inst_id, a.sid, CLIENT_INFO Ch, a.STATUS,
open_time, round(BYTES/1024/1024,2) "SOFAR Mb" , round(total_bytes/1024/1024,2)
TotMb, io_count,
round(BYTES/TOTAL_BYTES*100,2) "% Complete" , a.type, filename
from gv$backup_async_io a,  gv$session s
where not a.STATUS in ('UNKNOWN')
and a.sid=s.sid and open_time > to_date('&1', 'dd-mon-rr hh24:mi:ss') order by 2,7;

REM gv$backup_sync_io
prompt
prompt Tape backuppiece progress (only if backup_tape_io_slaves=FALSE):
prompt
select s.inst_id, a.sid, CLIENT_INFO Ch, filename, a.type, a.status, buffer_size bsz, buffer_count bfc,
open_time open, io_count
from gv$backup_sync_io a, gv$session s
where
a.sid=s.sid and
open_time > to_date('&1', 'dd-mon-rr hh24:mi:ss') ;
REM -------------------------------
