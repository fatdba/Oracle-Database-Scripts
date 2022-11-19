REM srdc_DGPhyStby_diag.sql - collect primary database information in dataguard environment
define SRDCNAME='DG_PHYSTBY_DIAG'
set markup html on spool on

set TERMOUT off;

COLUMN SRDCSPOOLNAME NOPRINT NEW_VALUE SRDCSPOOLNAME 
select 'SRDC_'||upper('&&SRDCNAME')||'_'||upper(value)||'_'||
      to_char(sysdate,'YYYYMMDD_HH24MISS') SRDCSPOOLNAME from v$parameter where lower(name)='instance_name';

REM 
spool &&SRDCSPOOLNAME..htm
Set heading off;

select '+----------------------------------------------------+' from dual 
union all 
select '| Script version:  '||'25-Aug-2021' from dual
union all
select '| Diagnostic-Name: '||'&&SRDCNAME' from dual 
union all 
select '| Timestamp: '|| to_char(systimestamp,'YYYY-MM-DD HH24:MI:SS TZH:TZM') from dual 
union all 
select '| Machine: '||host_name from v$instance 
union all 
select '| Version: '||version from v$instance 
union all 
select '| DBName: '||name from v$database 
union all 
select '| Instance: '||instance_name from v$instance 
union all 
select '+----------------------------------------------------+' from dual
/
 
Set heading on;
set linesize 2000
set pagesize 50000
set numformat 999999999999999
set trim on
set trims on
set markup html on
set markup html entmap off
set feedback on
set echo on
ALTER SESSION SET nls_date_format = 'DD-MON-YYYY HH24:MI:SS';
select sysdate from dual;

-- EXADATA
select decode(count(cell_path),0,'Non-Exadata','Exadata') "System" from v$cell;								

-- MIRA
select decode (count(distinct inst_id),0,'NO_MRP',1,'SIRA','MIRA') "APPLYMODE" from gv$process where upper(pname) like 'PR%';
							   
-- The following select will give us the generic information about how this standby is setup.
-- The DATABASE_ROLE should be STANDBY as that is what this script is intended to be run on.
-- PLATFORM_ID should match the PLATFORM_ID of the primary or conform to the supported options in
-- Note: 413484.1 Data Guard Support for Heterogeneous Primary and Physical Standbys in Same Data Guard Configuration.
-- FLASHBACK can be YES (recommended) or NO.
-- If PROTECTION_LEVEL is different from PROTECTION_MODE then for some reason the mode listed in PROTECTION_MODE experienced a need to downgrade.
-- Once the error condition has been corrected the PROTECTION_LEVEL should match the PROTECTION_MODE after the next log switch.

SELECT database_role role, name, db_unique_name, checkpoint_change#, current_scn, resetlogs_change#,  
platform_id, open_mode, log_mode, flashback_on, protection_mode, protection_level FROM v$database;
Select dbid, name, cdb container from v$database;

-- FORCE_LOGGING is not mandatory but is recommended.
-- REMOTE_ARCHIVE should be ENABLE.
-- SUPPLEMENTAL_LOG_DATA_PK and SUPPLEMENTAL_LOG_DATA_UI must be enabled if this standby is associated with a primary that has a logical standby.
-- During normal operations it is acceptable for SWITCHOVER_STATUS to be NOT ALLOWED.
-- DATAGUARD_BROKER can be ENABLED (recommended) or DISABLED.
 
column force_logging format a13 tru
column supplemental_log_data_pk format a24 tru
column supplemental_log_data_ui format a24 tru

SELECT force_logging, remote_archive, supplemental_log_data_pk, supplemental_log_data_ui, switchover_status, standby_became_primary_scn, dataguard_broker FROM v$database;

-- Check how many threads are enabled and started for this database. If the number of instances below does not match, then not all instances are up.
-- VERSION should match the version from the primary database.
-- ARCHIVER can be (STOPPED | STARTED | FAILED). FAILED means that the archiver failed to archive a log last time, but will try again within 5 minutes.
-- LOG_SWITCH_WAIT the ARCHIVE LOG/CLEAR LOG/CHECKPOINT event log switching is waiting for.
-- Note that if ALTER SYSTEM SWITCH LOGFILE is hung, but there is room in the current online redo log, then the value is NULL.

column host_name format a32 wrap
SELECT thread#, instance_name, host_name, version, status, archiver, log_switch_wait, startup_time FROM gv$instance ORDER BY thread#;

--  Password file Users

col USERNAME format a30
SELECT USERNAME,SYSDBA,SYSOPER,SYSASM FROM V$PWFILE_USERS;
select file_name, format, is_asm, con_id from v$passwordfile_info;

-- Check incarnation of the database, the standby and primary must have the same CURRENT incarnation:

select incarnation#, resetlogs_change#, resetlogs_time, prior_resetlogs_change#, prior_resetlogs_time, 
status, resetlogs_id, prior_incarnation#, flashback_database_allowed from gv$database_incarnation;

-- Check the number and size of online redo logs on each thread.

SELECT thread#, group#, sequence#, bytes, archived ,l.status, blocksize, member FROM v$log l join v$logfile f using (GROUP#) ORDER BY thread#, group#;

-- The following query is run to see if standby redo logs have been created.
-- The standby redo logs should be the same size as the online redo logs.
-- There should be (( # of online logs per thread + 1) * # of threads) standby redo logs.
-- A value of 0 for the thread# means the log has never been allocated.

select thread#, group#, sequence#, bytes, archived, s.status , blocksize, member FROM v$standby_log s join v$logfile using (GROUP#) order by thread#, group#;

-- This query produces a list of defined archive destinations.
-- It shows if they are enabled, what process is servicing that destination, if the destination is local or remote, and if remote what the current mount ID is.
-- For a physical standby we should have at least one remote destination that points the primary set.
 
column destination format a35 wrap
column process format a7
column ID format 99
column mid format 99
 
select thread#,dest_id,dest_name,destination,target,gvi.status instance_status,gvad.status archive_status,process, mountid,valid_now,valid_type,valid_role,db_unique_name,error 
from gv$archive_dest gvad join gv$instance gvi
using (inst_id) where gvad.status='VALID' and destination is NOT NULL order by thread#, dest_id;
 
-- If the protection mode of the standby is set to anything higher than max performance then we need to make sure the remote destination that points to the primary is set with the correct options else we will have issues during switchover.
 
set numwidth 8
column archiver format a8
column ID format 99
column error format a55 wrap

SELECT thread#, dest_id, gvad.archiver, transmit_mode, affirm, async_blocks, net_timeout, delay_mins, reopen_secs reopen, register, binding FROM gv$archive_dest gvad, gv$instance gvi WHERE gvad.inst_id = gvi.inst_id AND destination is NOT NULL ORDER BY thread#, dest_id;
 
-- The query below will determine if any error conditions have been reached by querying the v$dataguard_status view (view only available in 9.2.0 and above).
 
column message format a80
select inst_id, thread#, facility, severity, dest_id, error_code, timestamp,message 
from gv$dataguard_status join gv$instance using (inst_id) 
where severity not in ('Informational') and message not like 'No SRLs created%' order by TIMESTAMP desc;

 
-- Query gv$managed_standby to see the status of processes involved in the shipping redo on this system.
-- Does not include processes needed to apply redo.
 
SELECT thread#, process, pid, status, client_process, client_pid, sequence#, block#, active_agents, known_agents FROM gv$managed_standby ORDER BY thread#, process;

select inst_id,thread#,sequence#,status from gv$managed_standby where process='MRP0';

SELECT instance, thread#, name, pid, action, client_role, client_pid, sequence#, block#, dest_id
from v$dataguard_process order by thread#, pid;

-- query gv$recovery_progress
select to_char(start_time,'dd-mon-yyyy HH:MI:SS') start_time, type, item, units, sofar, total, to_char(timestamp,'dd-mon-yyyy HH:MI:SS') timestamp from gv$recovery_progress where item like '%Apply Rate';


-- Verify the last sequence# received and the last sequence# applied to standby database.

SELECT al.thrd "Thread", almax "Last Seq Received", lhmax "Last Seq Applied" FROM (select thread# thrd, MAX(sequence#) almax FROM v$archived_log WHERE resetlogs_change#=(SELECT resetlogs_change# FROM v$database) GROUP BY thread#) al, (SELECT thread# thrd, MAX(sequence#) lhmax FROM v$log_history WHERE resetlogs_change#=(SELECT resetlogs_change# FROM v$database) GROUP BY thread#) lh WHERE al.thrd = lh.thrd;

-- Check the transport lag and apply lag from the V$DATAGUARD_STATS view.  This is only relevant when LGWR log transport and real time apply are in use.

SELECT * FROM v$dataguard_stats WHERE name LIKE '%lag%';

-- Check how often and how far the apply lags.

SELECT name, time, unit, count, TO_DATE(last_time_updated, 'MM/DD/YYYY HH24:MI:SS') FROM v$standby_event_histogram ORDER BY unit DESC, time;

-- The V$ARCHIVE_GAP fixed view on a physical standby database only returns the next gap that is currently blocking redo apply from continuing.
-- After resolving the identified gap and starting redo apply, query the V$ARCHIVE_GAP fixed view again on the physical standby database to determine the next gap sequence, if there is one.

SELECT * FROM v$archive_gap;

-- Check RFS PERF STATE
	
select event, total_waits, total_timeouts, time_waited, average_wait*10 from v$system_event where event like '%RFS%' order by 5 desc;   
	  
-- Check datfile perf state
	
select event, total_waits, total_timeouts, time_waited, average_wait*10 from v$system_event where event like '%db file%' order by 5 desc;   
   
-- order by time_waited and exclude the idle events 
   
column event format a40 truncate
column name format a35 truncate
column opname format a35 truncate
column value format 99999999999999 
select event, total_waits, time_waited, average_wait*10 from v$system_event where time_waited > 100 and
event not like 'rdbms ipc %' and event not like '%timer%'and lower(event) not like '%idle%' and lower(event) not like 'sql%net%' and event not like 'ges%' order by time_waited;

-- Non-default init parameters.
-- For a RAC DB Thread# = * means the value is the same for all threads (SID=*)
-- Threads with different values are shown with their individual thread# and values.

column num noprint

SELECT num, '*' "THREAD#", name, value FROM v$PARAMETER WHERE NUM IN (SELECT num FROM v$parameter WHERE (isdefault = 'FALSE' OR ismodified <> 'FALSE') AND name NOT LIKE 'nls%'
MINUS
SELECT num FROM gv$parameter gvp, gv$instance gvi WHERE num IN (SELECT DISTINCT gvpa.num FROM gv$parameter gvpa, gv$parameter gvpb WHERE gvpa.num = gvpb.num AND  gvpa.value <> gvpb.value AND (gvpa.isdefault = 'FALSE' OR gvpa.ismodified <> 'FALSE') AND gvpa.name NOT LIKE 'nls%') AND gvi.inst_id = gvp.inst_id  AND (gvp.isdefault = 'FALSE' OR gvp.ismodified <> 'FALSE') AND gvp.name NOT LIKE 'nls%')
UNION
SELECT num, TO_CHAR(thread#) "THREAD#", name, value FROM gv$parameter gvp, gv$instance gvi WHERE num IN (SELECT DISTINCT gvpa.num 
FROM gv$parameter gvpa, gv$parameter gvpb 
WHERE gvpa.num = gvpb.num AND gvpa.value <> gvpb.value
 AND (gvpa.isdefault = 'FALSE' OR gvpa.ismodified <> 'FALSE')
 AND gvp.name NOT LIKE 'nls%') AND gvi.inst_id = gvp.inst_id
 AND (gvp.isdefault = 'FALSE' OR gvp.ismodified <> 'FALSE') 
 AND gvp.name NOT LIKE 'nls%' ORDER BY 1, 2;

-- STANDBY LAST RECEIVED and LAST APPLIED

SELECT al.thrd "Thread", almax "Last Seq Received", lhmax "Last Seq Applied" 
FROM (select thread# thrd, MAX(sequence#) almax FROM v$archived_log WHERE 
resetlogs_change#=(SELECT resetlogs_change# FROM v$database) GROUP BY thread#) al, 
(SELECT thread# thrd, MAX(sequence#) lhmax FROM v$log_history WHERE 
resetlogs_change#=(SELECT resetlogs_change# 
FROM v$database) GROUP BY thread#) lh WHERE al.thrd = lh.thrd
and 'PHYSICAL STANDBY' =(select database_role from v$database); 


-- DATABASE INFORMATION
-- Check the state of the datafiles
-- Note: datafiles must be ONLINE 
-- Standby datafiles should never be *online* fuzzy.

select file#,tablespace_name tablespace,name datafile,checkpoint_change#,checkpoint_time, resetlogs_change#, resetlogs_time,bytes from v$datafile_header order by file#;

select status,checkpoint_change#,checkpoint_time, resetlogs_change#, resetlogs_time, count(*), fuzzy from v$datafile_header
group by status,checkpoint_change#,checkpoint_time, resetlogs_change#, resetlogs_time, fuzzy order by checkpoint_change# desc;

select min(fhrba_Seq) "Min Sequence", max(fhrba_Seq) "Max Sequence",min(fhscn) "Min SCN",max(fhscn) "Max SCN" from X$KCVFH;

-- CONTAINER DATABASE INFORMATION
--
show pdbs;
select con_id,name,open_mode,restricted from v$containers;

select 'ROOT',file#,tablespace_name tablespace,name datafile,checkpoint_change#,checkpoint_time, 
resetlogs_change#, resetlogs_time,bytes, con_id from v$datafile_header h 
where h.con_id=1
union
select p.name, file#,tablespace_name tablespace,h.name datafile,checkpoint_change#,checkpoint_time, 
resetlogs_change#, resetlogs_time,bytes,h.con_id
from v$datafile_header h, v$pdbs p 
where  h.con_id=p.con_id 
order by con_id, file#;

select 'ROOT',status,checkpoint_change#,checkpoint_time, resetlogs_change#, resetlogs_time, count(*), fuzzy,h.con_id from v$datafile_header h
where h.con_id=1
group by status,checkpoint_change#,checkpoint_time, resetlogs_change#,
resetlogs_time, fuzzy,h.con_id
UNION
select p.name,status,checkpoint_change#,checkpoint_time, resetlogs_change#, resetlogs_time, count(*), fuzzy,h.con_id from v$datafile_header h, v$pdbs p
where  h.con_id=p.con_id
group by p.name, status,checkpoint_change#,checkpoint_time, resetlogs_change#,
resetlogs_time, fuzzy,h.con_id
order by con_id;

-- Flashback Database and Restore Point Details 

select scn,database_incarnation#,guarantee_flashback_database,storage_size,
time,restore_point_time,preserved,name from v$restore_point;

select * from v$restore_point;
select min(first_change#),min(first_time)  from v$flashback_database_logfile;
select oldest_flashback_scn, oldest_flashback_time, retention_target from v$flashback_database_log;

-- GV$ARCHIVE_DEST full details

select * from gv$archive_dest;

-- Controlfile Details

show parameter control_file_record_keep;
select * from v$controlfile_record_section;

spool off
set markup html off entmap on
exit
