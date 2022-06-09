-- This is not written by me and is a Oracle provided script but its great to use
-- NAME: CELLPERFDIAG.SQL
-- ------------------------------------------------------------------------
-- AUTHOR: Michael Polaski - Oracle Support Services
-- ------------------------------------------------------------------------
-- PURPOSE:
-- This script is intended to provide a user friendly guide to troubleshoot
-- cell performance specifically to identify which cell(s) may be problematic.
-- The script will create a file called cellperfdiag_<timestamp>.out in your
-- local directory.

set echo off
set feedback off
column timecol new_value timestamp
column spool_extension new_value suffix
select to_char(sysdate,'Mondd_hh24mi') timecol,
'.out' spool_extension from sys.dual;
column output new_value dbname
select value || '_' output
from v$parameter where name = 'db_name';
spool cellperfdiag_&&dbname&&timestamp&&suffix
set trim on
set trims on
set lines 160
set long 10000
set pages 60
set verify off
alter session set optimizer_features_enable = '10.2.0.4';

-- Additional formatting
column avg_wait_time format 99999999999.9
column cell_name format a30 wra
column cell_path format a30 wra
column disk_name format a30 wra
column event format a40 wra
column inst_id format 999
column minute format a12 tru
column sample_time format a25 tru
column total_wait_time format 99999999999.9

PROMPT CELLPERFDIAG DATA FOR &&dbname&&timestamp

PROMPT
PROMPT IMPORTANT PARAMETERS RELATING TO CELL PERFORMANCE:
PROMPT
column name format a40 wra
column value format a40 wra
select inst_id, name, value from gv$parameter
where (name like 'cell%' or name like '_kcfis%' or name like '%fplib%')
and value is not null
order by 1, 2, 3;

PROMPT
PROMPT TOP 20 CURRENT CELL WAITS
PROMPT
PROMPT This is to look at current cell waits, may not return any data.
select * from (
select c.cell_path, sw.inst_id, sw.event, sw.p1 cellhash#, sw.p2 diskhash#, sw.p3 bytes, sw.state, sw.seconds_in_wait
from v$cell c, gv$session_wait sw
where sw.p1text = 'cellhash#' and c.cell_hashval = sw.p1
order by 8 desc)
where rownum < 21;

PROMPT
PROMPT ASH CELL PERFORMANCE SUMMARY
PROMPT
PROMPT This query will look at the average cell wait times for each cell in ASH
select c.cell_path, sum(a.time_waited) TOTAL_WAIT_TIME, avg(a.time_waited) AVG_WAIT_TIME
from v$cell c, gv$active_session_history a
where a.p1text = 'cellhash#' and c.cell_hashval = a.p1
group by c.cell_path
order by 3 desc, 2 desc;

PROMPT
PROMPT 20 WORST CELL PERFORMANCE MINUTES IN ASH:
PROMPT
PROMPT APPROACH: These are the minutes where the avg cell perf time
PROMPT was the highest.  See which cell had the longest waits and
PROMPT during what minute.
select * from (
select to_char(a.sample_time,'Mondd_hh24mi') minute, c.cell_path,
sum(a.time_waited) TOTAL_WAIT_TIME, avg(a.time_waited) AVG_WAIT_TIME
from v$cell c, gv$active_session_history a
where a.p1text = 'cellhash#' and c.cell_hashval = a.p1
group by to_char(sample_time,'Mondd_hh24mi'), c.cell_path
order by 4 desc, 3 desc)
where rownum < 21;

PROMPT
PROMPT 50 LONGEST CELL WAITS IN ASH ORDERED BY WAIT TIME
PROMPT
PROMPT APPROACH: These are the top 50 individual cell waits in ASH
PROMPT in wait time order.  
select * from (
select a.sample_time, c.cell_path, a.inst_id, a.event, a.p1 cellhash#, a.p2 diskhash#, a.p3 bytes, a.time_waited
from v$cell c, gv$active_session_history a
where a.p1text = 'cellhash#' and c.cell_hashval = a.p1
order by time_waited desc)
where rownum < 51;

PROMPT
PROMPT 100 LONGEST CELL WAITS IN ASH ORDERED BY SAMPLE TIME
PROMPT
PROMPT APPROACH: These are the top 50 individual cell waits in ASH
PROMPT in sample time order.  
select * from (
select * from (
select a.sample_time, c.cell_path, a.inst_id, a.event, a.p1 cellhash#, a.p2 diskhash#, a.p3 bytes, a.time_waited
from v$cell c, gv$active_session_history a
where a.p1text = 'cellhash#' and c.cell_hashval = a.p1
order by time_waited desc)
where rownum < 101)
order by 1;

PROMPT
PROMPT ASH HISTORY CELL PERFORMANCE SUMMARY
PROMPT
PROMPT This query will look at the average cell wait times for each cell in ASH
select c.cell_path, sum(a.time_waited) TOTAL_WAIT_TIME, avg(a.time_waited) AVG_WAIT_TIME
from v$cell c, DBA_HIST_ACTIVE_SESS_HISTORY a
where a.p1text = 'cellhash#' and c.cell_hashval = a.p1
group by c.cell_path
order by 3 desc, 2 desc;

PROMPT
PROMPT 20 WORST CELL PERFORMANCE MINUTES IN ASH HISTORY:
PROMPT
PROMPT APPROACH: These are the minutes where the avg cell perf time
PROMPT was the highest.  See which cell had the longest waits and
PROMPT during what time minute.
select * from (
select to_char(a.sample_time,'Mondd_hh24mi') minute, c.cell_path,
sum(a.time_waited) TOTAL_WAIT_TIME, avg(a.time_waited) AVG_WAIT_TIME
from v$cell c, DBA_HIST_ACTIVE_SESS_HISTORY a
where a.p1text = 'cellhash#' and c.cell_hashval = a.p1
group by to_char(sample_time,'Mondd_hh24mi'), c.cell_path
order by 4 desc, 3 desc)
where rownum < 21;

PROMPT
PROMPT 50 LONGEST CELL WAITS IN ASH HISTORY ORDERED BY WAIT TIME
PROMPT
PROMPT APPROACH: These are the top 50 individual cell waits in ASH
PROMPT history in wait time order.  
select * from (
select a.sample_time, c.cell_path, a.instance_number inst_id, a.event, a.p1 cellhash#, a.p2 diskhash#, a.p3 bytes, a.time_waited
from v$cell c, DBA_HIST_ACTIVE_SESS_HISTORY a
where a.p1text = 'cellhash#' and c.cell_hashval = a.p1
order by time_waited desc)
where rownum < 51;

PROMPT
PROMPT 100 LONGEST CELL WAITS IN ASH HISTORY ORDERED BY SAMPLE TIME
PROMPT
PROMPT APPROACH: These are the top 100 individual cell waits in ASH
PROMPT history in sample time order.  
select * from (
select * from (
select a.sample_time, c.cell_path, a.instance_number inst_id, a.event, a.p1 cellhash#, a.p2 diskhash#, a.p3 bytes, a.time_waited
from v$cell c, DBA_HIST_ACTIVE_SESS_HISTORY a
where a.p1text = 'cellhash#' and c.cell_hashval = a.p1
order by time_waited desc)
where rownum < 101)
order by 1;

PROMPT
PROMPT AWR CELL DISK UTILIZATION
PROMPT
PROMPT APPROACH: This query only works in 12.1 and above.  This is looking
PROMPT in the AWR history tables to look at cell disk utilization for some
PROMPT of the worst periods.  Top 100 disk utils.
PROMPT DISK_UTILIZATION_SUM: Sum of the per-minute disk utilization metrics.
PROMPT IO_REQUESTS_SUM: Sum of the per-minute IOPs.
PROMPT IO_MB_SUM: Sum of the per-minute I/O metrics, in megabytes per second.
select * from (select * from (
select distinct dhs.snap_id, to_char(dhs.begin_interval_time,'Mondd_hh24mi') BEGIN,
to_char(dhs.end_interval_time,'Mondd_hh24mi') END,
cd.cell_name, cd.disk_name, DISK_UTILIZATION_SUM, IO_REQUESTS_SUM, IO_MB_SUM
from dba_hist_snapshot dhs, DBA_HIST_CELL_DISK_SUMMARY cds, v$cell_disk cd
where (cds.cell_hash = cd.cell_hash and cds.disk_id = cd.disk_id)
and dhs.snap_id = cds.snap_id and to_char(dhs.begin_interval_time,'Mondd_hh24') in
(select hour from (
select to_char(a.sample_time,'Mondd_hh24') hour, avg(a.time_waited) AVG_WAIT_TIME
from DBA_HIST_ACTIVE_SESS_HISTORY a
where event like 'cell%' or event like 'db file%' or event like 'log file%' or event like 'control file%'
group by to_char(a.sample_time,'Mondd_hh24')
order by 2 desc)
where rownum < 6)
order by DISK_UTILIZATION_SUM desc, IO_REQUESTS_SUM desc)
where rownum < 101)
order by 1,2,3,4,5;

SELECT ksqdngunid DB_ID_FOR_CURRENT_DB FROM X$KSQDN;

PROMPT
PROMPT CELL THREAD HISTORY - LAST FEW MINUTES
PROMPT
PROMPT This query only works in 12.1 and above.
select * from (
select count(*), sql_id, cell_name, job_type, database_id, instance_id
from v$cell_thread_history
where wait_state not in ('waiting_for_SKGXP_receive','waiting_for_connect','looking_for_job')
group by sql_id, cell_name, job_type, database_id, instance_id
order by 1 desc, 2, 3)
where rownum < 51;

PROMPT
PROMPT CELL CONFIG
PROMPT
select cellname, XMLTYPE.createXML(confval) confval
from v$cell_config
where conftype='CELL';

PROMPT
PROMPT IORM CONFIG
PROMPT
select cellname, XMLTYPE.createXML(confval) confval
from v$cell_config
where conftype='IORM';

select to_char(sysdate,'Mondd hh24:mi:ss') TIME from dual;

spool off

PROMPT
PROMPT OUTPUT FILE IS: cellperfdiag_&&dbname&&timestamp&&suffix
PROMPT

