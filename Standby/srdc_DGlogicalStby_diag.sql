REM srdc_DGPhyStby_diag.sql - collect primary database information in dataguard environment
define SRDCNAME='DG_LOGICSTBY_DIAG'
set markup html on spool on

set TERMOUT off;

COLUMN SRDCSPOOLNAME NOPRINT NEW_VALUE SRDCSPOOLNAME 
select 'SRDC_'||upper('&&SRDCNAME')||'_'||upper(instance_name)||'_'||
      to_char(sysdate,'YYYYMMDD_HH24MISS') SRDCSPOOLNAME from v$instance;

REM 
spool &&SRDCSPOOLNAME..htm
Set heading on;

select '+----------------------------------------------------+' from dual 
union all 
select '| Script version:  '||'04-Nov-2021' from dual
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

set echo off
set feedback off
column timecol new_value timestamp
column spool_extension new_value suffix
SELECT TO_CHAR(sysdate,'yyyymmdd_hh24mi') timecol, '.html' spool_extension FROM dual;
column output new_value dbname
SELECT value || '_' output FROM v$parameter WHERE name = 'db_unique_name';
set linesize 2000
set pagesize 50000
set numformat 999999999999999
set trim on
set trims on
set markup html on
set markup html entmap off
set feedback on

ALTER SESSION SET nls_date_format = 'DD-MON-YYYY HH24:MI:SS';
select sysdate from dual;
select decode(count(cell_path),0,'Non-Exadata','Exadata') "System" from v$cell;	

set echo on

-- In the following output the DATABASE_ROLE should be LOGICAL STANDBY as that is what this script is intended to be run on.
-- PLATFORM_ID should match the PLATFORM_ID of the standby(s) or conform to the supported options in
-- Note: 413484.1 Data Guard Support for Heterogeneous Primary and Physical Standbys in Same Data Guard Configuration
-- Note: 1085687.1 Data Guard Support for Heterogeneous Primary and Logical Standbys in Same Data Guard Configuration
-- OPEN_MODE should be READ WRITE.
-- LOG_MODE should be ARCHIVELOG.
-- FLASHBACK can be YES (recommended) or NO.
-- If PROTECTION_LEVEL is different from PROTECTION_MODE then for some reason the mode listed in PROTECTION_MODE experienced a need to downgrade.
-- Once the error condition has been corrected the PROTECTION_LEVEL should match the PROTECTION_MODE after the next log switch;

SELECT database_role role, name, dbid, db_unique_name, platform_id, open_mode, log_mode, flashback_on, protection_mode, protection_level FROM v$database;
Select dbid, name, cdb container from v$database;
 
-- FORCE_LOGGING is not mandatory but is recommended.
-- REMOTE_ARCHIVE should be ENABLE.
-- SUPPLEMENTAL_LOG_DATA_PK and SUPPLEMENTAL_LOG_DATA_UI must be enabled if this is a logical standby.
-- During normal operations it is acceptable for SWITCHOVER_STATUS to be NOT ALLOWED.
-- DG_BROKER can be ENABLED (recommended) or DISABLED.

column force_logging format a13 tru
column remote_archive format a14 tru
column supplemental_log_data_pk format a24 tru
column supplemental_log_data_ui format a24 tru
column dataguard_broker format a16 tru

SELECT force_logging, remote_archive, supplemental_log_data_pk, supplemental_log_data_ui, switchover_status, dataguard_broker  FROM v$database;  

-- The following query gives us information about catpatch. From this we can tell if the catalog version doesn''t match the image version it was started with.

column version format a10 tru

SELECT version, modified, status FROM dba_registry WHERE comp_id = 'CATPROC';

-- password informaton

Select username, sysdba,sysoper,sysasm, u.account_status "ACCOUNT_STATUS", u.authentication_type "AUTHENTICATION_TYPE" 
from V$PWFILE_USERS U join DBA_USERS using (username);

-- Check how many threads are enabled and started for this database. If the number of instances below does not match then not all instances are up.

SELECT thread#, instance, status FROM v$thread;

-- The number of instances returned below is the number currently running.  If it does not match the number returned in Threads above then not all instances are up.
-- VERSION should match the version from CATPROC above.
-- ARCHIVER can be (STOPPED | STARTED | FAILED). FAILED means that the archiver failed to archive a log last time, but will try again within 5 minutes.
-- LOG_SWITCH_WAIT the ARCHIVE LOG/CLEAR LOG/CHECKPOINT event log switching is waiting for.
-- Note that if ALTER SYSTEM SWITCH LOGFILE is hung, but there is room in the current online redo log, then the value is NULL.

column host_name format a32 wrap  
SELECT thread#, instance_name, host_name, version, archiver, log_switch_wait, startup_time FROM gv$instance ORDER BY thread#;

-- Check how often logs are switching. Log switches should not regularly be occuring in < 20 mins.
-- Excessive log switching is a performance overhead. Whilst rapid log switching is not in itself a Data Guard issue it can affect Data guard.
-- It may also indicate a problem with log shipping. Use redo log size = 4GB or redo log size >= peak redo rate x 20 minutes.

SELECT fs.log_switches_under_20_mins, ss.log_switches_over_20_mins FROM (SELECT  SUM(COUNT (ROUND((b.first_time - a.first_time) * 1440) )) "LOG_SWITCHES_UNDER_20_MINS"  FROM v$archived_log a, v$archived_log b WHERE a.sequence# + 1 = b.sequence# AND a.dest_id = 1 AND a.thread# = b.thread#  AND a.dest_id = b.dest_id AND a.dest_id = (SELECT MIN(dest_id) FROM gv$archive_dest WHERE target='PRIMARY' AND destination IS NOT NULL) AND ROUND((b.first_time - a.first_time) * 1440)  < 20 GROUP BY ROUND((b.first_time - a.first_time) * 1440))  fs, (SELECT  SUM(COUNT (ROUND((b.first_time - a.first_time) * 1440) )) "LOG_SWITCHES_OVER_20_MINS"  FROM v$archived_log a, v$archived_log b WHERE a.sequence# + 1 = b.sequence# AND a.dest_id = 1 AND a.thread# = b.thread#  AND a.dest_id = b.dest_id AND a.dest_id = (SELECT MIN(dest_id) FROM gv$archive_dest WHERE target='PRIMARY' AND destination IS NOT NULL) AND ROUND((b.first_time - a.first_time) * 1440)  > 19 GROUP BY ROUND((b.first_time - a.first_time) * 1440)) ss;

-- Check the number and size of online redo logs on each thread.

SELECT thread#, group#, sequence#, bytes, archived ,status FROM v$log ORDER BY thread#, group#;

-- The following query is run to see if standby redo logs have been created in preparation for switchover.
-- The standby redo logs should be the same size as the online redo logs.<br>There should be (( # of online logs per thread + 1) * # of threads) standby redo logs.
-- A value of 0 for the thread# means the log has never been allocated.

SELECT thread#, group#, sequence#, bytes, archived, status FROM v$standby_log ORDER BY thread#, group#;

-- This query produces a list of defined archive destinations. It shows if they are enabled, what process is servicing that destination,
-- if the destination is local or remote.

column destination format a35 wrap
column process format a7
column ID format 99
column mid format 99

SELECT thread#, dest_id, destination, target, schedule, process FROM gv$archive_dest gvad, gv$instance gvi WHERE gvad.inst_id = gvi.inst_id AND destination is NOT NULL ORDER BY thread#, dest_id;

-- This select will give further detail on the destinations as to what options have been set.
-- Register indicates whether or not the archived redo log is registered in the remote destination control fileOptions.

set numwidth 8
column archiver format a8
column affirm format a6
column error format a55 wrap
column register format a8

SELECT thread#, dest_id, gvad.archiver, transmit_mode, affirm, async_blocks, net_timeout, max_failure, delay_mins, reopen_secs reopen, register, binding FROM gv$archive_dest gvad, gv$instance gvi WHERE gvad.inst_id = gvi.inst_id AND destination is NOT NULL ORDER BY thread#, dest_id;
 
-- The following select will show any errors that occured the last time an attempt to archive to the destination was attempted.
-- If ERROR is blank and status is VALID then the archive completed correctly.

SELECT thread#, dest_id, gvad.status, error, fail_sequence FROM gv$archive_dest gvad, gv$instance gvi WHERE gvad.inst_id = gvi.inst_id AND destination is NOT NULL ORDER BY thread#, dest_id;

-- The query below will determine if any error conditions have been reached by querying the v$dataguard_status view (view only available in 9.2.0 and above).

column message format a80

SELECT gvi.thread#, timestamp, message FROM gv$dataguard_status gvds, gv$instance gvi WHERE gvds.inst_id = gvi.inst_id AND severity in ('Error','Fatal') ORDER BY timestamp, thread#;

-- Query v$managed_standby to see the status of processes involved in the shipping redo on this system.
-- Does not include processes needed to apply redo.

SELECT inst_id, thread#, process, pid, status, client_process, client_pid, sequence#, block#, active_agents, known_agents FROM gv$managed_standby ORDER BY thread#, pid;

-- v$dataguard_process

SELECT instance, thread#, name, pid, ACTION, client_role, client_pid, sequence#, block#, 
dest_id from v$dataguard_process order by thread#, pid;

-- Verify that the last sequence# received and the last sequence# applied to the standby database.

SELECT r.thread#, rmax "Last Sequence Received" , appmax "Last Sequence APPLIED" FROM (SELECT thread#, MAX(sequence#) rmax FROM dba_logstdby_log  WHERE resetlogs_change# = (SELECT MAX(resetlogs_change#) FROM v$rfs_thread ) GROUP BY thread#) r,(SELECT thread#, MAX(sequence#) appmax FROM dba_logstdby_log WHERE resetlogs_change# = (SELECT MAX(resetlogs_change#) FROM v$rfs_thread) AND applied = 'YES' GROUP BY thread#)  a  WHERE r.thread# = a.thread#;

-- Check if there are any gaps in the logs being sent to the standby.  Detects multiple gaps across threads.

         SELECT a.thread#, a.sequence# + 1 "LOW_SEQUENCE#", b.sequence# -1 "HIGH_SEQUENCE#"
         FROM
         (SELECT thread#, rownum rnum, sequence# FROM dba_logstdby_log) a,
         (SELECT thread#, rownum rnum , sequence# FROM dba_logstdby_log) b
         where a.rnum +1 = b.rnum and a.sequence# +1 <> b.sequence# AND a.thread# = b.thread# and rownum < 21 ORDER BY a.thread#, low_sequence#; 
		 
-- Verify that log apply services on the standby are currently  running.
-- If the query against V$LOGSTDBY returns no rows then logical apply is not running.

column status format a50 wrap
column type format a11
set numwidth 15

SELECT type, status, high_scn FROM v$logstdby;

-- The DBA_LOGSTDBY_PROGRESS view describes the progress of SQL apply operations on the logical standby databases.
-- The APPLIED_SCN indicates that committed transactions at or below that SCN have been applied.
-- The NEWEST_SCN is the maximum SCN to which data could be applied if no more logs were received.
-- This is usually the MAX(NEXT_CHANGE#)-1 from DBA_LOGSTDBY_LOG.
-- The value of NEWEST_SCN and APPLIED_SCN are equal then all available changes have been applied.
-- If your APPLIED_SCN is below NEWEST_SCN and is increasing then SQL apply is currently processing changes.

set numwidth 15

SELECT
  (CASE
    WHEN newest_scn = applied_scn THEN 'Done'
    WHEN newest_scn <= applied_scn + 9 THEN 'Done?'
    WHEN newest_scn > (SELECT MAX(next_change#) FROM dba_logstdby_log)
    THEN 'Near done'
    WHEN (SELECT COUNT(*) FROM dba_logstdby_log
          WHERE (next_change#, thread#) NOT IN
                  (SELECT first_change#, thread# FROM dba_logstdby_log)) > 1
    THEN 'Gap'
    WHEN newest_scn > applied_scn THEN 'Not Done'
    ELSE '---' END) "Fin?",
    newest_scn, applied_scn, read_scn FROM dba_logstdby_progress;

-- Check the newest time, applied time and read time from dba_logstdby_progress.

SELECT newest_time, applied_time, read_time FROM dba_logstdby_progress;

-- Determine if apply is lagging behind and by how much.
-- Archives which are applied is not listed here

set numwidth 15
column trd format 99

SELECT thread#, sequence#, first_change#, next_change#, dict_begin beg, dict_end end, TO_CHAR(timestamp, 'hh:mi:ss') timestamp, (CASE WHEN l.next_change# < p.read_scn THEN 'YES' WHEN l.first_change# < p.applied_scn THEN 'CURRENT' ELSE 'NO' END) applied FROM dba_logstdby_log l, dba_logstdby_progress p where applied not in ('YES') ORDER BY thread#, first_change#;

-- Get a history on logical standby apply activity.

set numwidth 15

SELECT event_time time, commit_scn, current_scn, event, status FROM dba_logstdby_events ORDER BY event_time, commit_scn, current_scn;

-- Dump logical standby stats.'

column name format a40
column value format a20

SELECT * FROM v$logstdby_stats;

-- Dump logical standby parameters.

column name format a33 wrap
column value format a33 wrap
column type format 99

SELECT name, value, type FROM system.logstdby$parameters ORDER BY type, name;

-- Gather log miner session and dictionary information.

set numwidth 15

SELECT * FROM system.logmnr_session$;
SELECT * FROM system.logmnr_dictionary$;
SELECT * FROM system.logmnr_dictstate$;
SELECT * FROM v$logmnr_session;

-- Query the log miner dictionary for key tables necessary to process changes for logical standby.
-- Label security will move AUD$ from SYS to SYSTEM.
-- A synonym will remain in SYS but Logical Standby does not support this.

set numwidth 5
column name format a9 wrap
column owner format a6 wrap

SELECT o.logmnr_uid, o.obj#, o.objv#, u.name owner, o.name FROM system.logmnr_obj$ o, system.logmnr_user$ u WHERE o.logmnr_uid = u.logmnr_uid AND o.owner# = u.user# AND o.name IN ('JOB$', 'JOBSEQ', 'SEQ$', 'AUD$', 'FGA_LOG$', 'IND$', 'COL$', 'LOGSTDBY$PARAMETER') ORDER BY u.name;
 
-- Non-default init parameters. For a RAC DB Thread# = * means the value is the same for all threads (SID=*)
-- Threads with different values are shown with their individual thread# and values.

column num noprint
column name format a28

SELECT num, '*' "THREAD#", name, value FROM v$PARAMETER WHERE NUM IN (SELECT num FROM v$parameter WHERE (isdefault = 'FALSE' OR ismodified <> 'FALSE') AND name NOT LIKE 'nls%'
MINUS
SELECT num FROM gv$parameter gvp, gv$instance gvi WHERE num IN (SELECT DISTINCT gvpa.num FROM gv$parameter gvpa, gv$parameter gvpb WHERE gvpa.num = gvpb.num AND  gvpa.value <> gvpb.value AND (gvpa.isdefault = 'FALSE' OR gvpa.ismodified <> 'FALSE') AND gvpa.name NOT LIKE 'nls%') AND gvi.inst_id = gvp.inst_id  AND (gvp.isdefault = 'FALSE' OR gvp.ismodified <> 'FALSE') AND gvp.name NOT LIKE 'nls%')
UNION
SELECT num, TO_CHAR(thread#) "THREAD#", name, value FROM gv$parameter gvp, gv$instance gvi WHERE num IN (SELECT DISTINCT gvpa.num FROM gv$parameter gvpa, gv$parameter gvpb WHERE gvpa.num = gvpb.num AND gvpa.value <> gvpb.value AND (gvpa.isdefault = 'FALSE' OR gvpa.ismodified <> 'FALSE') AND gvp.name NOT LIKE 'nls%') AND gvi.inst_id = gvp.inst_id  AND (gvp.isdefault = 'FALSE' OR gvp.ismodified <> 'FALSE') AND gvp.name NOT LIKE 'nls%' ORDER BY 1, 2;

-- Flashback Database and Restore Point Details 

select scn,database_incarnation#,guarantee_flashback_database,storage_size,
time,restore_point_time,preserved,name from v$restore_point;

select * from v$restore_point;
select min(first_change#),min(first_time)  from v$flashback_database_logfile;
select oldest_flashback_scn, oldest_flashback_time, retention_target from v$flashback_database_log;

-- GV$ARCHIVE_DEST full details

select * from gv$archive_dest;

-- DBA_LOGSTDBY_UNSUPPORTED 

select * from dba_logstdby_unsupported;

-- Controlfile Details

show parameter control_file_record_keep;
select * from v$controlfile_record_section;

spool off
set markup html off entmap on
set echo on
exit
