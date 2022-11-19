REM srdc_DGPrimary_diag.sql - collect primary database information in dataguard environment
define SRDCNAME='DG_PRIM_DIAG'
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

set heading on;
set echo off
set feedback off
column timecol new_value timestamp
column spool_extension new_value suffix
column output new_value dbname
set linesize 2000
set pagesize 50000
set numformat 999999999999999
set trim on
set trims on
set markup html on
set markup html entmap off
set feedback on

ALTER SESSION SET nls_date_format = 'DD-MON-YYYY HH24:MI:SS';
SELECT sysdate time FROM dual;
select decode(count(cell_path),0,'Non-Exadata','Exadata') "System" from v$cell;															   

set echo on

-- In the following output the DATABASE_ROLE should be PRIMARY as that is what this script is intended to be run on.
-- PLATFORM_ID should match the PLATFORM_ID of the standby(s) or conform to the supported options in
-- Note: 413484.1 Data Guard Support for Heterogeneous Primary and Physical Standbys in Same Data Guard Configuration
-- Note: 1085687.1 Data Guard Support for Heterogeneous Primary and Logical Standbys in Same Data Guard Configuration
-- OPEN_MODE should be READ WRITE.
-- LOG_MODE should be ARCHIVELOG.
-- FLASHBACK can be YES (recommended) or NO.
-- If PROTECTION_LEVEL is different from PROTECTION_MODE then for some reason the mode listed in PROTECTION_MODE experienced a need to downgrade.
-- Once the error condition has been corrected the PROTECTION_LEVEL should match the PROTECTION_MODE after the next log switch;

SELECT database_role role, name, db_unique_name, checkpoint_change#, current_scn, resetlogs_change#,  
platform_id, open_mode, log_mode, flashback_on, protection_mode, protection_level FROM v$database;
SELECT dbid, name, cdb from v$database;

-- Check is using Enterprise or Standard Edition

SELECT BANNER from v$version where BANNER like '%Oracle%';

-- FORCE_LOGGING is not mandatory but is recommended.
-- REMOTE_ARCHIVE should be ENABLE.
-- SUPPLEMENTAL_LOG_DATA_PK and SUPPLEMENTAL_LOG_DATA_UI must be enabled if the standby associated with this primary is a logical standby.
-- During normal operations it is acceptable for SWITCHOVER_STATUS to be SESSIONS ACTIVE or TO STANDBY.
-- DG_BROKER can be ENABLED (recommended) or DISABLED.;

column force_logging format a13 tru
column remote_archive format a14 tru
column supplemental_log_data_pk format a24 tru
column supplemental_log_data_ui format a24 tru
column dataguard_broker format a16 tru

SELECT force_logging, remote_archive, supplemental_log_data_pk, supplemental_log_data_ui, switchover_status, standby_became_primary_scn, dataguard_broker FROM v$database;

-- The following query gives us information about catpatch. From this we can tell if the catalog version doesn''t match the image version it was started with.

column version format a10 tru

SELECT version, modified, status FROM dba_registry WHERE comp_id = 'CATPROC';

-- Check how many threads are enabled and started for this database. If the number of instances below does not match then not all instances are up.

SELECT thread#, instance, status FROM v$thread;

-- The number of instances returned below is the number currently running.  If it does not match the number returned in Threads above then not all instances are up.
-- VERSION should match the version from CATPROC above.
-- ARCHIVER can be (STOPPED | STARTED | FAILED). FAILED means that the archiver failed to archive a log last time, but will try again within 5 minutes.
-- LOG_SWITCH_WAIT the ARCHIVE LOG/CLEAR LOG/CHECKPOINT event log switching is waiting for.
-- Note that if ALTER SYSTEM SWITCH LOGFILE is hung, but there is room in the current online redo log, then the value is NULL.

column host_name format a32 wrap
SELECT thread#, instance_name, host_name, version, archiver, log_switch_wait, startup_time FROM gv$instance ORDER BY thread#;

--  Password file Users

col USERNAME format a30
SELECT USERNAME,SYSDBA,SYSOPER,SYSASM,U.ACCOUNT_STATUS "ACCOUNT_STATUS",U.AUTHENTICATION_TYPE "AUTHENTICATION_TYPE" FROM V$PWFILE_USERS JOIN DBA_USERS U USING (USERNAME);

select file_name, format, is_asm, con_id from v$passwordfile_info;

-- Check incarnation of the database, the standby and primary must have the same CURRENT incarnation:

select incarnation#, resetlogs_change#, resetlogs_time, prior_resetlogs_change#, prior_resetlogs_time,
status, resetlogs_id, prior_incarnation#, flashback_database_allowed from gv$database_incarnation;

-- Number of log switches in less than 20min in last 24hours

 SELECT a.LOG_SWITCHES_UNDER_20_MINS "LOG_SWITCHES_UNDER_20_MINS", b.LOG_SWITCHES_OVER_20_MINS "LOG_SWITCHES_OVER_20_MINS" from
(select count(*) "LOG_SWITCHES_UNDER_20_MINS" from v$archived_log join v$archive_dest using (dest_id) where target='PRIMARY' AND destination IS NOT NULL and first_time > (sysdate -1) and (next_time-first_time) < 1/72) a ,
(select count(*) "LOG_SWITCHES_OVER_20_MINS" from v$archived_log join v$archive_dest using (dest_id) where target='PRIMARY' AND destination IS NOT NULL and first_time > (sysdate -1) and (next_time-first_time) > 1/72) b;


-- Details of time slot where number of log switches are more than 4 per hour in last 7 days

select Day||':00-59' "Day",LOG_SWITCHES_UNDER_20_MINS from (
with agg as(
select  to_char(First_time,'MON DD,YYYY HH24') Day,count(*) "LOG_SWITCHES_UNDER_20_MINS",dense_rank() over (partition by to_char(First_time,'MON DD,YYYY HH24') order by 2 desc) as rank 
from v$archived_log join v$archive_dest using (dest_id) where target='PRIMARY' AND destination IS NOT NULL
and (next_time-first_time) <= 1/72 and First_time > (sysdate-7)
group by to_char(First_time,'MON DD,YYYY HH24')
)
select Day,LOG_SWITCHES_UNDER_20_MINS from agg order by 1 desc )
where  LOG_SWITCHES_UNDER_20_MINS >4;


-- History: log switches details of last 7days

SELECT Day,LOG_SWITCHES_UNDER_20_MINS,LOG_SWITCHES_OVER_20_MINS from (
select  to_char(First_time,'MON DD,YYYY') Day,count(*) "LOG_SWITCHES_UNDER_20_MINS" from v$archived_log join v$archive_dest using (dest_id) where target='PRIMARY' AND destination IS NOT NULL
and (next_time-first_time) <= 1/72 and First_time > (sysdate-7) group by to_char(First_time,'MON DD,YYYY')) a 
join (select to_char(First_time,'MON DD,YYYY') Day,count(*) "LOG_SWITCHES_OVER_20_MINS" from v$archived_log join v$archive_dest using (dest_id) where target='PRIMARY' AND destination IS NOT NULL
and (next_time-first_time) > 1/72 and First_time > (sysdate-7) group by to_char(First_time,'MON DD,YYYY')) b using (Day)
order by Day desc;



-- Check the max redo generation speed of the day
-- and average speed of top 30 redo speed and recommendation of ORL size to ensure switch happening on every 20min

select time "Day" ,round(max(value/1024),2) "Max_Redo_KB/s",round(avg(value)/1024,2) "Avg_Redo(top30_mins)_KB/s",round(avg(value)*60*20/1024,0) "Recommended_ORL_size_KB"
from (
with agg as (
select to_char(BEGIN_TIME,'DD/MON/YYYY') time,value, dense_rank() over (partition by to_char(BEGIN_TIME,'DD/MON/YYYY') order by value desc) as rank
from dba_hist_sysmetric_history where metric_name = 'Redo Generated Per Sec' and to_char(BEGIN_TIME,'DD/MON/YYYY') > sysdate -7)
select time,value from agg where agg.rank <31
) group by time order by 1 desc;


column  minutes  format a12

SELECT (CASE WHEN bucket = 1 THEN '<= ' || TO_CHAR(bucket * 5) WHEN (bucket >1 AND bucket < 9) THEN TO_CHAR(bucket * 5 - 4) || ' TO ' || TO_CHAR(bucket * 5) WHEN bucket > 8 THEN '>= ' || TO_CHAR(bucket * 5 - 4) END) "MINUTES", switches "LOG_SWITCHES" FROM (SELECT bucket , COUNT(b.bucket) SWITCHES FROM (SELECT WIDTH_BUCKET(ROUND((b.first_time - a.first_time) * 1440), 0, 40, 8) bucket FROM v$archived_log a, v$archived_log b WHERE a.sequence# + 1 = b.sequence# AND a.dest_id = b.dest_id  AND a.thread# = b.thread#  AND a.dest_id = (SELECT MIN(dest_id) FROM gv$archive_dest WHERE target = 'PRIMARY' AND destination IS NOT NULL)) b GROUP BY bucket ORDER BY bucket);

-- Check the number and size of online redo logs on each thread.

SELECT thread#, group#, sequence#, bytes, archived ,status, blocksize FROM v$log ORDER BY thread#, group#;

-- To get the online redo log file location 

SELECT thread#, group#, sequence#, bytes, archived ,l.status, blocksize, member FROM v$log l join v$logfile f using (GROUP#) ORDER BY thread#, group#;

-- The following query is run to see if standby redo logs have been created in preparation for switchover.
-- The standby redo logs should be the same size as the online redo logs.<br>There should be (( # of online logs per thread + 1) * # of threads) standby redo logs.
-- A value of 0 for the thread# means the log has never been allocated.

SELECT thread#, group#, sequence#, bytes, archived, status, blocksize FROM v$standby_log order by thread#, group#;

-- This query provides the number of standby redo logs, per instance

column count(*) new_value count
column CHECK_NAME format a40
select inst_id, dest_id, standby_logfile_count from gv$archive_dest_status where status <> 'INACTIVE' and db_unique_name <> 'NONE' order by dest_id, inst_id;

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

-- This shows if redo transport is configured

col name format a20
col value format a2000
column CHECK_NAME format a40
select name, inst_id, value from gv$parameter where name like 'log_archive_dest_%' and upper(value) like '%SERVICE%' order by inst_id;

-- The following select will show any errors that occured the last time an attempt to archive to the destination was attempted.
-- If ERROR is blank and status is VALID then the archive completed correctly.

SELECT thread#, dest_id, gvad.status, error, fail_sequence FROM gv$archive_dest gvad, gv$instance gvi WHERE gvad.inst_id = gvi.inst_id AND destination is NOT NULL ORDER BY thread#, dest_id;

-- The query below will determine if any error conditions have been reached by querying the v$dataguard_status view (view only available in 9.2.0 and above).

column message format a80

SELECT instance, thread#, name, pid, action, client_role, client_pid, sequence#, block#, dest_id
from v$dataguard_process order by thread#, pid;

SELECT gvi.thread#, timestamp, message FROM gv$dataguard_status gvds, gv$instance gvi WHERE gvds.inst_id = gvi.inst_id AND severity in ('Error','Fatal') ORDER BY timestamp, thread#;

-- Query v$managed_standby to see the status of processes involved in the shipping redo on this system.
-- Does not include processes needed to apply redo.

SELECT inst_id, thread#, process, pid, status, client_process, client_pid, sequence#, block#, active_agents, known_agents FROM gv$managed_standby ORDER BY thread#, pid;

-- The following query will determine the current sequence number and the last sequence archived.
-- If you are remotely archiving using the LGWR process then the archived sequence should be one higher than the current sequence.
-- If remotely archiving using the ARCH process then the archived sequence should be equal to the current sequence.
-- The applied sequence information is updated at log switch time.
-- The "Last Applied" value should be checked with the actual last log applied at the standby, only the standby is guaranteed to be correct.

SELECT cu.thread#, cu.dest_id, la.lastarchived "Last Archived", cu.currentsequence "Current Sequence", appl.lastapplied "Last Applied" FROM (select gvi.thread#, gvd.dest_id, MAX(gvd.log_sequence) currentsequence FROM gv$archive_dest gvd, gv$instance gvi WHERE gvd.status = 'VALID' AND gvi.inst_id = gvd.inst_id GROUP BY thread#, dest_id) cu, (SELECT thread#, dest_id, MAX(sequence#) lastarchived FROM gv$archived_log WHERE resetlogs_change# = (SELECT resetlogs_change# FROM v$database) AND archived = 'YES' GROUP BY thread#, dest_id) la, (SELECT thread#, dest_id, MAX(sequence#) lastapplied FROM gv$archived_log WHERE resetlogs_change# = (SELECT resetlogs_change# FROM v$database) AND applied = 'YES' GROUP BY thread#, dest_id) appl WHERE cu.thread# = la.thread# AND cu.thread# = appl.thread# AND cu.dest_id = la.dest_id AND cu.dest_id = appl.dest_id ORDER BY 1, 2;

-- The following select will attempt to gather as much information as possible from the standby.
-- Standby redo logs are not supported with Logical Standby until Version 10.1.
-- The ARCHIVED_SEQUENCE# from a logical standby is the sequence# created by the apply, not the sequence# sent from the primary.

set numwidth 8
column dest_id format 99
column Active format 99

SELECT dest_id, database_mode, recovery_mode, protection_mode, standby_logfile_count, standby_logfile_active FROM v$archive_dest_status WHERE destination IS NOT NULL;

-- Non-default init parameters. For a RAC DB Thread# = * means the value is the same for all threads (SID=*)
-- Threads with different values are shown with their individual thread# and values.

column num noprint

SELECT num, '*' "THREAD#", name, value FROM v$PARAMETER WHERE NUM IN (SELECT num FROM v$parameter WHERE (isdefault = 'FALSE' OR ismodified <> 'FALSE') AND name NOT LIKE 'nls%'
MINUS
SELECT num FROM gv$parameter gvp, gv$instance gvi WHERE num IN (SELECT DISTINCT gvpa.num FROM gv$parameter gvpa, gv$parameter gvpb WHERE gvpa.num = gvpb.num AND  gvpa.value <> gvpb.value AND (gvpa.isdefault = 'FALSE' OR gvpa.ismodified <> 'FALSE') AND gvpa.name NOT LIKE 'nls%') AND gvi.inst_id = gvp.inst_id  AND (gvp.isdefault = 'FALSE' OR gvp.ismodified <> 'FALSE') AND gvp.name NOT LIKE 'nls%')
UNION
SELECT num, TO_CHAR(thread#) "THREAD#", name, value FROM gv$parameter gvp, gv$instance gvi WHERE num IN (SELECT DISTINCT gvpa.num FROM gv$parameter gvpa, gv$parameter gvpb WHERE gvpa.num = gvpb.num AND gvpa.value <> gvpb.value AND (gvpa.isdefault = 'FALSE' OR gvpa.ismodified <> 'FALSE') AND gvp.name NOT LIKE 'nls%') AND gvi.inst_id = gvp.inst_id  AND (gvp.isdefault = 'FALSE' OR gvp.ismodified <> 'FALSE') AND gvp.name NOT LIKE 'nls%' ORDER BY 1, 2;

-- LAST APPLIED ARCHIVELOG FILES
--
select dest_id,thread#,sequence# "sequence#",first_time,first_change#,next_time,next_change# from v$archived_log
where (dest_id,thread#,sequence#) in
(select dest_id,thread#,max(sequence#) from v$archived_log where dest_id in
(select to_number(ltrim(name,'log_archive_dest_')) from v$parameter where lower(name) like 'log_archive_dest%' and upper(value) like '%SERVICE=%'
minus
select dest_id from v$archive_dest where VALID_ROLE  in ('STANDBY_ROLE')) and applied='YES' group by dest_id,thread#)
and activation# in (select activation# from v$database)
and 'PRIMARY' =(select database_role from v$database)
union
select dest_id,thread#,sequence# "sequence#",first_time,first_change#,next_time,next_change# from v$archived_log
where (dest_id,thread#,sequence#) in
(select dest_id,thread#,max(sequence#) from v$archived_log where dest_id in (select dest_id from v$archive_dest where destination is not null and upper(VALID_ROLE) in ('ALL_ROLES','STANDBY_ROLE') and dest_id <> 32) and applied='YES' group by dest_id,thread#)
and activation# in (select activation# from v$database)
and 'PHYSICAL STANDBY' =(select database_role from v$database)
;

-- ARCHIVELOG APPLY RANGE
--
select b.dest_id,a.thread#,a.sequence# "latest archivelog" ,b.sequence# "latest archive applied",a.sequence# - b.sequence# "# Not Applied" from
(select dest_id,thread#,max(sequence#) sequence# from v$archived_log
where dest_id in (select to_number(ltrim(name,'log_archive_dest_')) from v$parameter where lower(name) like 'log_archive_dest%' and upper(value) like '%SERVICE=%'
minus
select dest_id from v$archive_dest where VALID_ROLE  in ('STANDBY_ROLE'))
 and applied='YES' group by dest_id,thread#) b,
(select thread#,max(sequence#) sequence#  from v$archived_log where activation# in (select activation# from v$database) group by thread#) a
where a.thread#=b.thread#
and 'PRIMARY' =(select database_role from v$database)
union
select b.dest_id,a.thread#,a.sequence# "latest archivelog" ,b.sequence# "latest archive applied",a.sequence# - b.sequence# "# Not Applied" from
(select dest_id,thread#,max(sequence#) sequence# from v$archived_log where applied='YES' and  dest_id in ( select dest_id from v$archive_dest where destination is not null and upper(VALID_ROLE) in ('ALL_ROLES','STANDBY_ROLE') and dest_id <> 32 ) group by dest_id,thread#) b,
(select thread#,max(sequence#) sequence#  from v$archived_log where activation# in (select activation# from v$database) group by thread#) a
where a.thread#=b.thread#
and 'PHYSICAL STANDBY' =(select database_role from v$database);

-- DATABASE INFORMATION
--
select file#,tablespace_name tablespace,name datafile,checkpoint_change#,checkpoint_time, resetlogs_change#, resetlogs_time,bytes from v$datafile_header order by file#;

select status,checkpoint_change#,checkpoint_time, resetlogs_change#, resetlogs_time, count(*), fuzzy from v$datafile_header
group by status,checkpoint_change#,checkpoint_time, resetlogs_change#, resetlogs_time, fuzzy order by checkpoint_change# desc;

select min(fhrba_Seq), max(fhrba_Seq) from X$KCVFH;

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

-- Get statistics of Redo generation per hour of last 3 days in descending order

select Day||':00-59' "Day" ,round(max(value/1024),2) "Max_Redo_generation_KB/s",round(avg(value/1024),2) "Aveg_redo_in_hour_KB/s" from(
with agg as (
select to_char(BEGIN_TIME,'DD/MON/YYYY HH24') Day,value, dense_rank() over (partition by to_char(BEGIN_TIME,'DD/MON/YYYY HH24') order by value desc) as rank
from dba_hist_sysmetric_history where metric_name = 'Redo Generated Per Sec' and to_char(BEGIN_TIME,'DD/MON/YYYY') > sysdate -3 )
select Day,value from agg)
group by Day order by 1 desc;

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
set echo on
exit
