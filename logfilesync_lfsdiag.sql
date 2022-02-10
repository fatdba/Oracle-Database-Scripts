-- NAME: LFSDIAG.SQL
-- Oracle prodived script
-- ------------------------------------------------------------------------
-- AUTHOR: - Oracle Support Services
-- ------------------------------------------------------------------------
-- PURPOSE:
-- This script is intended to provide a user friendly guide to troubleshoot
-- log file sync waits. The script will look at important parameters involved
-- in log file sync waits, log file sync wait histogram data, and the script
-- will look at the worst average log file sync times in the active session
-- history data and AWR data and dump information to help determine why those
-- times were the highest. The script will create a file called
-- lfsdiag_<timestamp>.out in your local directory.
-- value for optimizer_features_enable may be modified as needed (4/19/18)
set echo off
set feedback off
column timecol new_value timestamp
column spool_extension new_value suffix
select to_char(sysdate,'Mondd_hh24mi') timecol,
'.out' spool_extension from sys.dual;
column output new_value dbname
select value || '_' output
from v$parameter where name = 'db_name';
spool lfsdiag_&&dbname&&timestamp&&suffix
set trim on
set trims on
set lines 140
set pages 100
set verify off
alter session set optimizer_features_enable = '10.2.0.4';

PROMPT LFSDIAG DATA FOR &&dbname&&timestamp
PROMPT Note: All timings are in milliseconds (1000 milliseconds = 1 second)

PROMPT
PROMPT IMPORTANT PARAMETERS RELATING TO LOG FILE SYNC WAITS:
column name format a40 wra
column value format a40 wra
select inst_id, name, value from gv$parameter
where ((value is not null and name like '%log_archive%') or
name like '%commit%' or name like '%event=%' or name like '%lgwr%')
and name not in (select name from gv$parameter where (name like '%log_archive_dest_state%'
and value = 'enable') or name = 'log_archive_format')
order by 1,2,3;

PROMPT
PROMPT V$LOG OUTPUT
PROMPT
PROMPT APPROACH: Review redolog size and members
select inst_id, group#, thread#, sequence#, bytes, status, first_change#
from gv$log
order by first_change#;

PROMPT
PROMPT ASH THRESHOLD...
PROMPT
PROMPT This will be the threshold in milliseconds for average log file sync
PROMPT times. This will be used for the next queries to look for the worst
PROMPT 'log file sync' minutes. Any minutes that have an average log file
PROMPT sync time greater than the threshold will be analyzed further.
column threshold_in_ms new_value threshold format 999999999.999
select min(threshold_in_ms) threshold_in_ms
from (select inst_id, to_char(sample_time,'Mondd_hh24mi') minute,
avg(time_waited)/1000 threshold_in_ms
from gv$active_session_history
where event = 'log file sync'
group by inst_id,to_char(sample_time,'Mondd_hh24mi')
order by 3 desc)
where rownum <= 10;

PROMPT
PROMPT ASH WORST MINUTES FOR LOG FILE SYNC WAITS:
PROMPT
PROMPT APPROACH: These are the minutes where the avg log file sync time
PROMPT was the highest (in milliseconds).
PROMPT
PROMPT Note that TOTAL_WAIT_TIME and AVG_TIME_WAITED do not accurately
PROMPT show total time or average time spent waiting in the database
PROMPT as ASH does not sample all waits. This is simply to look for
PROMPT potential problem timeframes.
column minute format a12 tru
column event format a30 tru
column program format a40 tru
column total_wait_time format 999999999999.999
column avg_time_waited format 999999999999.999
select to_char(sample_time,'Mondd_hh24mi') minute, inst_id, event,
sum(time_waited)/1000 TOTAL_WAIT_TIME , count(*) WAITS,
avg(time_waited)/1000 AVG_TIME_WAITED
from gv$active_session_history
where event = 'log file sync'
group by to_char(sample_time,'Mondd_hh24mi'), inst_id, event
having avg(time_waited)/1000 > &&threshold
order by 1,2;

PROMPT
PROMPT ASH LFS BACKGROUND PROCESS WAITS DURING WORST MINUTES:
PROMPT
PROMPT APPROACH: What is LGWR doing when 'log file sync' waits
PROMPT are happening? LMS info may be relevent for broadcast
PROMPT on commit and LNS data may be relevant for dataguard.
PROMPT
PROMPT Note that TOTAL_WAIT_TIME and AVG_TIME_WAITED do not accurately
PROMPT show total time or average time spent waiting in the database
PROMPT as ASH does not sample all waits. This is simply to look for
PROMPT potential problem timeframes.
PROMPT
PROMPT If more details are needed see the ASH DETAILS FOR WORST
PROMPT MINUTES section at the bottom of the report.
column inst format 999
column minute format a12 tru
column event format a30 tru
column program format a40 wra
select to_char(sample_time,'Mondd_hh24mi') minute, inst_id inst, program, event,
sum(time_waited)/1000 TOTAL_WAIT_TIME , count(*) WAITS,
avg(time_waited)/1000 AVG_TIME_WAITED
from gv$active_session_history
where to_char(sample_time,'Mondd_hh24mi') in (select to_char(sample_time,'Mondd_hh24mi')
from gv$active_session_history
where event = 'log file sync'
group by to_char(sample_time,'Mondd_hh24mi'), inst_id
having avg(time_waited)/1000 > &&threshold)
and (program like '%LG%' or program like '%LMS%' or
program like '%LNS%' or event = 'log file sync')
group by to_char(sample_time,'Mondd_hh24mi'), inst_id, program, event
having sum(time_waited)/1000 > 0
order by 1,2,3,5 desc, 4;

PROMPT
PROMPT HISTOGRAM DATA FOR LFS AND OTHER RELATED WAITS:
PROMPT
PROMPT APPROACH: Look at the wait distribution for log file sync waits
PROMPT by looking at "wait_time_milli". Look at the high wait times then
PROMPT see if you can correlate those with other related wait events.
column event format a40 wra
select inst_id, event, wait_time_milli, wait_count
from gv$event_histogram
where event in ('log file sync','gcs log flush sync',
'log file parallel write','wait for scn ack',
'log file switch completion','gc cr grant 2-way',
'gc buffer busy','gc current block 2-way') or
event like '%LGWR%' or event like '%LNS%'
order by 2 desc,1,3;

PROMPT
PROMPT ORDERED BY WAIT_TIME_MILLI
select inst_id, event, wait_time_milli, wait_count
from gv$event_histogram
where event in ('log file sync','gcs log flush sync',
'log file parallel write','wait for scn ack',
'log file switch completion','gc cr grant 2-way',
'gc buffer busy','gc current block 2-way')
or event like '%LGWR%' or event like '%LNS%'
order by 3,1,2 desc;

PROMPT
PROMPT REDO WRITE STATS
PROMPT
PROMPT "redo write time" in centiseconds (100 per second)
PROMPT 11.1: "redo write broadcast ack time" in centiseconds (100 per second)
PROMPT 11.2: "redo write broadcast ack time" in microseconds (1000 per millisecond)
column value format 99999999999999999999
column milliseconds format 99999999999999.999
select v.version, ss.inst_id, ss.name, ss.value,
decode(substr(version,1,4),
'11.1',decode (name,'redo write time',value*10,
'redo write broadcast ack time',value*10),
'11.2',decode (name,'redo write time',value*10,
'redo write broadcast ack time',value/1000),
decode (name,'redo write time',value*10)) milliseconds
from gv$sysstat ss, v$instance v
where name like 'redo write%' and value > 0
order by 1,2,3;

PROMPT
PROMPT AWR WORST AVG LOG FILE SYNC SNAPS:
PROMPT
PROMPT APPROACH: These are the AWR snaps where the average 'log file sync'
PROMPT times were the highest.
column begin format a12 tru
column end format a12 tru
column name format a13 tru
select dhs.snap_id, dhs.instance_number inst, to_char(dhs.begin_interval_time,'Mondd_hh24mi') BEGIN,
to_char(dhs.end_interval_time,'Mondd_hh24mi') END,
en.name, se.time_waited_micro/1000 total_wait_time, se.total_waits,
se.time_waited_micro/1000 / se.total_waits avg_time_waited
from dba_hist_snapshot dhs, wrh$_system_event se, v$event_name en
where (dhs.snap_id = se.snap_id and dhs.instance_number = se.instance_number)
and se.event_id = en.event_id and en.name = 'log file sync' and
dhs.snap_id in (select snap_id from (
select se.snap_id, se.time_waited_micro/1000 / se.total_waits avg_time_waited
from wrh$_system_event se, v$event_name en
where se.event_id = en.event_id and en.name = 'log file sync'
order by avg_time_waited desc)
where rownum < 4)
order by 1,2;

PROMPT
PROMPT AWR REDO WRITE STATS
PROMPT
PROMPT "redo write time" in centiseconds (100 per second)
PROMPT 11.1: "redo write broadcast ack time" in centiseconds (100 per second)
PROMPT 11.2: "redo write broadcast ack time" in microseconds (1000 per millisecond)
column stat_name format a30 tru
select v.version, ss.snap_id, ss.instance_number inst, sn.stat_name, ss.value,
decode(substr(version,1,4),
'11.1',decode (stat_name,'redo write time',value*10,
'redo write broadcast ack time',value*10),
'11.2',decode (stat_name,'redo write time',value*10,
'redo write broadcast ack time',value/1000),
decode (stat_name,'redo write time',value*10)) milliseconds
from wrh$_sysstat ss, wrh$_stat_name sn, v$instance v
where ss.stat_id = sn.stat_id
and sn.stat_name like 'redo write%' and ss.value > 0
and ss.snap_id in (select snap_id from (
select se.snap_id, se.time_waited_micro/1000 / se.total_waits avg_time_waited
from wrh$_system_event se, v$event_name en
where se.event_id = en.event_id and en.name = 'log file sync'
order by avg_time_waited desc)
where rownum < 4)
order by 1,2,3;

PROMPT
PROMPT AWR LFS AND OTHER RELATED WAITS FOR WORST LFS AWRs:
PROMPT
PROMPT APPROACH: These are the AWR snaps where the average 'log file sync'
PROMPT times were the highest. Look at related waits at those times.
column name format a40 tru
select se.snap_id, se.instance_number inst, en.name,
se.total_waits, se.time_waited_micro/1000 total_wait_time,
se.time_waited_micro/1000 / se.total_waits avg_time_waited
from wrh$_system_event se, v$event_name en
where se.event_id = en.event_id and (en.name in
('log file sync','gcs log flush sync',
'log file parallel write','wait for scn ack',
'log file switch completion','gc cr grant 2-way',
'gc buffer busy','gc current block 2-way')
or en.name like '%LG%' or en.name like '%LNS%')
and se.snap_id in (select snap_id from (
select se.snap_id, se.time_waited_micro/1000 / se.total_waits avg_time_waited
from wrh$_system_event se, v$event_name en
where se.event_id = en.event_id and en.name = 'log file sync'
order by avg_time_waited desc)
where rownum < 4)
order by 1, 6 desc;

PROMPT
PROMPT AWR HISTOGRAM DATA FOR LFS AND OTHER RELATED WAITS FOR WORST LFS AWRs:
PROMPT Note: This query won't work on 10.2 - ORA-942
PROMPT
PROMPT APPROACH: Look at the wait distribution for log file sync waits
PROMPT by looking at "wait_time_milli". Look at the high wait times then
PROMPT see if you can correlate those with other related wait events.
select eh.snap_id, eh.instance_number inst, en.name, eh.wait_time_milli, eh.wait_count
from wrh$_event_histogram eh, v$event_name en
where eh.event_id = en.event_id and
(en.name in ('log file sync','gcs log flush sync',
'log file parallel write','wait for scn ack',
'log file switch completion','gc cr grant 2-way',
'gc buffer busy','gc current block 2-way')
or en.name like '%LG%' or en.name like '%LNS%')
and snap_id in (select snap_id from (
select se.snap_id, se.time_waited_micro/1000 / se.total_waits avg_time_waited
from wrh$_system_event se, v$event_name en
where se.event_id = en.event_id and en.name = 'log file sync'
order by avg_time_waited desc)
where rownum < 4)
order by 1,3 desc,2,4;

PROMPT
PROMPT ORDERED BY WAIT_TIME_MILLI
PROMPT Note: This query won't work on 10.2 - ORA-942
select eh.snap_id, eh.instance_number inst, en.name, eh.wait_time_milli, eh.wait_count
from wrh$_event_histogram eh, v$event_name en
where eh.event_id = en.event_id and
(en.name in ('log file sync','gcs log flush sync',
'log file parallel write','wait for scn ack',
'log file switch completion','gc cr grant 2-way',
'gc buffer busy','gc current block 2-way')
or en.name like '%LG%' or en.name like '%LNS%')
and snap_id in (select snap_id from (
select se.snap_id, se.time_waited_micro/1000 / se.total_waits avg_time_waited
from wrh$_system_event se, v$event_name en
where se.event_id = en.event_id and en.name = 'log file sync'
order by avg_time_waited desc)
where rownum < 4)
order by 1,4,2,3 desc;

PROMPT
PROMPT ASH DETAILS FOR WORST MINUTES:
PROMPT
PROMPT APPROACH: If you cannot determine the problem from the data
PROMPT above, you may need to look at the details of what each session
PROMPT is doing during each 'bad' snap. Most likely you will want to
PROMPT note the times of the high log file sync waits, look at what
PROMPT LGWR is doing at those times, and go from there...
column program format a45 wra
column sample_time format a25 tru
column event format a30 tru
column time_waited format 999999.999
column p1 format a40 tru
column p2 format a40 tru
column p3 format a40 tru
select sample_time, inst_id inst, session_id, program, event, time_waited/1000 TIME_WAITED,
p1text||': '||p1 p1,p2text||': '||p2 p2,p3text||': '||p3 p3
from gv$active_session_history
where to_char(sample_time,'Mondd_hh24mi') in (select
to_char(sample_time,'Mondd_hh24mi')
from gv$active_session_history
where event = 'log file sync'
group by to_char(sample_time,'Mondd_hh24mi'), inst_id
having avg(time_waited)/1000 > &&threshold)
and time_waited > 0.5
order by 1,2,3,4,5;

select to_char(sysdate,'Mondd hh24:mi:ss') TIME from dual;

spool off

PROMPT
PROMPT OUTPUT FILE IS: lfsdiag_&&dbname&&timestamp&&suffix
PROMPT
