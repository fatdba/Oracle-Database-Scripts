-- NAME: RACDIAG.SQL
-- SYS OR INTERNAL USER, CATPARR.SQL ALREADY RUN, PARALLEL QUERY OPTION ON
-- ------------------------------------------------------------------------
-- AUTHOR:
-- Michael Polaski - Oracle Support Services
-- Copyright 2002, Oracle Corporation
-- ------------------------------------------------------------------------
-- PURPOSE:
-- This script is intended to provide a user friendly guide to troubleshoot
-- RAC hung sessions or slow performance scenerios. The script includes
-- information to gather a variety of important debug information to determine
-- the cause of a RAC session level hang. The script will create a file
-- called racdiag_.out in your local directory while dumping hang analyze
-- dumps in the user_dump_dest(s) and background_dump_dest(s) on all nodes.
--
-- ------------------------------------------------------------------------
-- DISCLAIMER:
-- This script is provided for educational purposes only. It is NOT
-- supported by Oracle World Wide Technical Support.
-- The script has been tested and appears to work as intended.
-- You should always run new scripts on a test instance initially.
-- ------------------------------------------------------------------------
-- Script output is as follows:

set echo off
set feedback off
column timecol new_value timestamp
column spool_extension new_value suffix
select to_char(sysdate,'Mondd_hhmi') timecol,
'.out' spool_extension from sys.dual;
column output new_value dbname
select value || '_' output
from v$parameter where name = 'db_name';
spool racdiag_&&dbname&&timestamp&&suffix
set lines 200
set pagesize 35
set trim on
set trims on
alter session set nls_date_format = 'MON-DD-YYYY HH24:MI:SS';
alter session set timed_statistics = true;
set feedback on
select to_char(sysdate) time from dual;

set numwidth 5
column host_name format a20 tru
select inst_id, instance_name, host_name, version, status, startup_time
from gv$instance
order by inst_id;

set echo on

-- WAIT CHAINS
-- 11.x+ Only (This will not work in < v11
-- See Note 1428210.1 for instructions on interpreting.
set pages 1000
set lines 120
set heading off
column w_proc format a50 tru
column instance format a20 tru
column inst format a28 tru
column wait_event format a50 tru
column p1 format a16 tru
column p2 format a16 tru
column p3 format a15 tru
column Seconds format a50 tru
column sincelw format a50 tru
column blocker_proc format a50 tru
column waiters format a50 tru
column chain_signature format a100 wra
column blocker_chain format a100 wra
SELECT *
FROM (SELECT 'Current Process: '||osid W_PROC, 'SID '||i.instance_name INSTANCE,
'INST #: '||instance INST,'Blocking Process: '||decode(blocker_osid,null,'<none>',blocker_osid)||
' from Instance '||blocker_instance BLOCKER_PROC,'Number of waiters: '||num_waiters waiters,
'Wait Event: ' ||wait_event_text wait_event, 'P1: '||p1 p1, 'P2: '||p2 p2, 'P3: '||p3 p3,
'Seconds in Wait: '||in_wait_secs Seconds, 'Seconds Since Last Wait: '||time_since_last_wait_secs sincelw,
'Wait Chain: '||chain_id ||': '||chain_signature chain_signature,'Blocking Wait Chain: '||decode(blocker_chain_id,null,
'<none>',blocker_chain_id) blocker_chain
FROM v$wait_chains wc,
v$instance i
WHERE wc.instance = i.instance_number (+)
AND ( num_waiters > 0
OR ( blocker_osid IS NOT NULL
AND in_wait_secs > 10 ) )
ORDER BY chain_id,
num_waiters DESC)
WHERE ROWNUM < 101;

-- Taking Hang Analyze dumps
-- This may take a little while...
oradebug setmypid
oradebug unlimit
oradebug -g all hanganalyze 3
-- This part may take the longest, you can monitor bdump or udump to see if
-- the file is being generated.
oradebug -g all dump systemstate 258

-- WAITING SESSIONS:
-- The entries that are shown at the top are the sessions that have
-- waited the longest amount of time that are waiting for non-idle wait
-- events (event column). You can research and find out what the wait
-- event indicates (along with its parameters) by checking the Oracle
-- Server Reference Manual or look for any known issues or documentation
-- by searching Metalink for the event name in the search bar. Example
-- (include single quotes): [ 'buffer busy due to global cache' ].
-- Metalink and/or the Server Reference Manual should return some useful
-- information on each type of wait event. The inst_id column shows the
-- instance where the session resides and the SID is the unique identifier
-- for the session (gv$session). The p1, p2, and p3 columns will show
-- event specific information that may be important to debug the problem.
-- To find out what the p1, p2, and p3 indicates see the next section.
-- Items with wait_time of anything other than 0 indicate we do not know
-- how long these sessions have been waiting.
--
set numwidth 15
set heading on
column state format a7 tru
column event format a25 tru
column last_sql format a40 tru
select sw.inst_id, sw.sid, sw.state, sw.event, sw.seconds_in_wait seconds,
sw.p1, sw.p2, sw.p3, sa.sql_text last_sql
from gv$session_wait sw, gv$session s, gv$sqlarea sa
where sw.event not in
('rdbms ipc message','smon timer','pmon timer',
'SQL*Net message from client','lock manager wait for remote message',
'ges remote message', 'gcs remote message', 'gcs for action', 'client message',
'pipe get', 'null event', 'PX Idle Wait', 'single-task message',
'PX Deq: Execution Msg', 'KXFQ: kxfqdeq - normal deqeue',
'listen endpoint status','slave wait','wakeup time manager')
and sw.seconds_in_wait > 0
and (sw.inst_id = s.inst_id and sw.sid = s.sid)
and (s.inst_id = sa.inst_id and s.sql_address = sa.address)
order by seconds desc;

-- EVENT PARAMETER LOOKUP:
-- This section will give a description of the parameter names of the
-- events seen in the last section. p1test is the parameter value for
-- p1 in the WAITING SESSIONS section while p2text is the parameter
-- value for p3 and p3 text is the parameter value for p3. The
-- parameter values in the first section can be helpful for debugging
-- the wait event.
--
column event format a30 tru
column p1text format a25 tru
column p2text format a25 tru
column p3text format a25 tru
select distinct event, p1text, p2text, p3text
from gv$session_wait sw
where sw.event not in ('rdbms ipc message','smon timer','pmon timer',
'SQL*Net message from client','lock manager wait for remote message',
'ges remote message', 'gcs remote message', 'gcs for action', 'client message',
'pipe get', 'null event', 'PX Idle Wait', 'single-task message',
'PX Deq: Execution Msg', 'KXFQ: kxfqdeq - normal deqeue',
'listen endpoint status','slave wait','wakeup time manager')
and seconds_in_wait > 0
order by event;

-- GES LOCK BLOCKERS:
-- This section will show us any sessions that are holding locks that
-- are blocking other users. The inst_id will show us the instance that
-- the session resides on while the sid will be a unique identifier for
-- the session. The grant_level will show us how the GES lock is granted to
-- the user. The request_level will show us what status we are trying to
-- obtain.  The lockstate column will show us what status the lock is in.
-- The last column shows how long this session has been waiting.
--
set numwidth 5
column state format a16 tru;
column event format a30 tru;
select dl.inst_id, s.sid, p.spid, dl.resource_name1,
decode(substr(dl.grant_level,1,8),'KJUSERNL','Null','KJUSERCR','Row-S (SS)',
'KJUSERCW','Row-X (SX)','KJUSERPR','Share','KJUSERPW','S/Row-X (SSX)',
'KJUSEREX','Exclusive',request_level) as grant_level,
decode(substr(dl.request_level,1,8),'KJUSERNL','Null','KJUSERCR','Row-S (SS)',
'KJUSERCW','Row-X (SX)','KJUSERPR','Share','KJUSERPW','S/Row-X (SSX)',
'KJUSEREX','Exclusive',request_level) as request_level,
decode(substr(dl.state,1,8),'KJUSERGR','Granted','KJUSEROP','Opening',
'KJUSERCA','Canceling','KJUSERCV','Converting') as state,
s.sid, sw.event, sw.seconds_in_wait sec
from gv$ges_enqueue dl, gv$process p, gv$session s, gv$session_wait sw
where blocker = 1
and (dl.inst_id = p.inst_id and dl.pid = p.spid)
and (p.inst_id = s.inst_id and p.addr = s.paddr)
and (s.inst_id = sw.inst_id and s.sid = sw.sid)
order by sw.seconds_in_wait desc;

-- GES LOCK WAITERS:
-- This section will show us any sessions that are waiting for locks that
-- are blocked by other users. The inst_id will show us the instance that
-- the session resides on while the sid will be a unique identifier for
-- the session. The grant_level will show us how the GES lock is granted to
-- the user. The request_level will show us what status we are trying to
-- obtain.  The lockstate column will show us what status the lock is in.
-- The last column shows how long this session has been waiting.
--
set numwidth 5
column state format a16 tru;
column event format a30 tru;
select dl.inst_id, s.sid, p.spid, dl.resource_name1,
decode(substr(dl.grant_level,1,8),'KJUSERNL','Null','KJUSERCR','Row-S (SS)',
'KJUSERCW','Row-X (SX)','KJUSERPR','Share','KJUSERPW','S/Row-X (SSX)',
'KJUSEREX','Exclusive',request_level) as grant_level,
decode(substr(dl.request_level,1,8),'KJUSERNL','Null','KJUSERCR','Row-S (SS)',
'KJUSERCW','Row-X (SX)','KJUSERPR','Share','KJUSERPW','S/Row-X (SSX)',
'KJUSEREX','Exclusive',request_level) as request_level,
decode(substr(dl.state,1,8),'KJUSERGR','Granted','KJUSEROP','Opening',
'KJUSERCA','Cancelling','KJUSERCV','Converting') as state,
s.sid, sw.event, sw.seconds_in_wait sec
from gv$ges_enqueue dl, gv$process p, gv$session s, gv$session_wait sw
where blocked = 1
and (dl.inst_id = p.inst_id and dl.pid = p.spid)
and (p.inst_id = s.inst_id and p.addr = s.paddr)
and (s.inst_id = sw.inst_id and s.sid = sw.sid)
order by sw.seconds_in_wait desc;

-- LOCAL ENQUEUES:
-- This section will show us if there are any local enqueues. The inst_id will
-- show us the instance that the session resides on while the sid will be a
-- unique identifier for. The addr column will show the lock address. The type
-- will show the lock type. The id1 and id2 columns will show specific
-- parameters for the lock type.
--
set numwidth 12
column event format a12 tru
select l.inst_id, l.sid, l.addr, l.type, l.id1, l.id2,
decode(l.block,0,'blocked',1,'blocking',2,'global') block,
sw.event, sw.seconds_in_wait sec
from gv$lock l, gv$session_wait sw
where (l.sid = sw.sid and l.inst_id = sw.inst_id)
and l.block in (0,1)
order by l.type, l.inst_id, l.sid;

-- LATCH HOLDERS:
-- If there is latch contention or 'latch free' wait events in the WAITING
-- SESSIONS section we will need to find out which proceseses are holding
-- latches. The inst_id will show us the instance that the session resides
-- on while the sid will be a unique identifier for. The username column
-- will show the session's username. The os_user column will show the os
-- user that the user logged in as. The name column will show us the type
-- of latch being waited on. You can search Metalink for the latch name in
-- the search bar. Example (include single quotes):
-- [ 'library cache' latch ]. Metalink should return some useful information
-- on the type of latch.
--
set numwidth 5
select distinct lh.inst_id, s.sid, s.username, p.username os_user, lh.name
from gv$latchholder lh, gv$session s, gv$process p
where (lh.sid = s.sid and lh.inst_id = s.inst_id)
and (s.inst_id = p.inst_id and s.paddr = p.addr)
order by lh.inst_id, s.sid;

-- LATCH STATS:
-- This view will show us latches with less than optimal hit ratios
-- The inst_id will show us the instance for the particular latch. The
-- latch_name column will show us the type of latch. You can search Metalink
-- for the latch name in the search bar. Example (include single quotes):
-- [ 'library cache' latch ]. Metalink should return some useful information
-- on the type of latch. The hit_ratio shows the percentage of time we
-- successfully acquired the latch.
--
column latch_name format a30 tru
select inst_id, name latch_name,
round((gets-misses)/decode(gets,0,1,gets),3) hit_ratio,
round(sleeps/decode(misses,0,1,misses),3) "SLEEPS/MISS"
from gv$latch
where round((gets-misses)/decode(gets,0,1,gets),3) < .99
and gets != 0
order by round((gets-misses)/decode(gets,0,1,gets),3);

-- No Wait Latches:
--
select inst_id, name latch_name,
round((immediate_gets/(immediate_gets+immediate_misses)), 3) hit_ratio,
round(sleeps/decode(immediate_misses,0,1,immediate_misses),3) "SLEEPS/MISS"
from gv$latch
where round((immediate_gets/(immediate_gets+immediate_misses)), 3) < .99
and immediate_gets + immediate_misses > 0
order by round((immediate_gets/(immediate_gets+immediate_misses)), 3);

-- GLOBAL CACHE CR PERFORMANCE
-- This shows the average latency of a consistent block request.
-- AVG CR BLOCK RECEIVE TIME should typically be about 15 milliseconds
-- depending on your system configuration and volume, is the average
-- latency of a consistent-read request round-trip from the requesting
-- instance to the holding instance and back to the requesting instance. If
-- your CPU has limited idle time and your system typically processes
-- long-running queries, then the latency may be higher. However, it is
-- possible to have an average latency of less than one millisecond with
-- User-mode IPC. Latency can be influenced by a high value for the
-- DB_MULTI_BLOCK_READ_COUNT parameter. This is because a requesting process
-- can issue more than one request for a block depending on the setting of
-- this parameter. Correspondingly, the requesting process may wait longer.
-- Also check interconnect badwidth, OS tcp settings, and OS udp settings if
-- AVG CR BLOCK RECEIVE TIME is high.
--
set numwidth 20
column "AVG CR BLOCK RECEIVE TIME (ms)" format 9999999.9
select b1.inst_id, b2.value "GCS CR BLOCKS RECEIVED",
b1.value "GCS CR BLOCK RECEIVE TIME",
((b1.value / b2.value) * 10) "AVG CR BLOCK RECEIVE TIME (ms)"
from gv$sysstat b1, gv$sysstat b2
where b1.name = 'global cache cr block receive time' and
b2.name = 'global cache cr blocks received' and b1.inst_id = b2.inst_id
or b1.name = 'gc cr block receive time' and
b2.name = 'gc cr blocks received' and b1.inst_id = b2.inst_id ;

-- GLOBAL CACHE LOCK PERFORMANCE
-- This shows the average global enqueue get time.
-- Typically AVG GLOBAL LOCK GET TIME should be 20-30 milliseconds. the
-- elapsed time for a get includes the allocation and initialization of a
-- new global enqueue. If the average global enqueue get (global cache
-- get time) or average global enqueue conversion times are excessive,
-- then your system may be experiencing timeouts. See the 'WAITING SESSIONS',
-- 'GES LOCK BLOCKERS', GES LOCK WAITERS', and 'TOP 10 WAIT EVENTS ON SYSTEM'
-- sections if the AVG GLOBAL LOCK GET TIME is high.
--
set numwidth 20
column "AVG GLOBAL LOCK GET TIME (ms)" format 9999999.9
select b1.inst_id, (b1.value + b2.value) "GLOBAL LOCK GETS",
b3.value "GLOBAL LOCK GET TIME",
(b3.value / (b1.value + b2.value) * 10) "AVG GLOBAL LOCK GET TIME (ms)"
from gv$sysstat b1, gv$sysstat b2, gv$sysstat b3
where b1.name = 'global lock sync gets' and
b2.name = 'global lock async gets' and b3.name = 'global lock get time'
and b1.inst_id = b2.inst_id and b2.inst_id = b3.inst_id
or b1.name = 'global enqueue gets sync' and
b2.name = 'global enqueue gets async' and b3.name = 'global enqueue get time'
and b1.inst_id = b2.inst_id and b2.inst_id = b3.inst_id;

-- RESOURCE USAGE
-- This section will show how much of our resources we have used.
--
set numwidth 8
select inst_id, resource_name, current_utilization, max_utilization,
initial_allocation
from gv$resource_limit
where max_utilization > 0
order by inst_id, resource_name;

-- DLM TRAFFIC INFORMATION
-- This section shows how many tickets are available in the DLM. If the
-- TCKT_WAIT columns says "YES" then we have run out of DLM tickets which
-- could cause a DLM hang. Make sure that you also have enough TCKT_AVAIL.
--
set numwidth 10
select * from gv$dlm_traffic_controller
order by TCKT_AVAIL;

-- DLM MISC
--
set numwidth 10
select * from gv$dlm_misc;

-- LOCK CONVERSION DETAIL:
-- This view shows the types of lock conversion being done on each instance.
--
select * from gv$lock_activity;

-- INITIALIZATION PARAMETERS:
-- Non-default init parameters for each node.
--
set numwidth 5
column name format a30 tru
column value format a50 wra
column description format a60 tru
select inst_id, name, value, description
from gv$parameter
where isdefault = 'FALSE'
order by inst_id, name;

-- TOP 10 WAIT EVENTS ON SYSTEM
-- This view will provide a summary of the top wait events in the db.
--
set numwidth 10
column event format a25 tru
select inst_id, event, time_waited, total_waits, total_timeouts
from (select inst_id, event, time_waited, total_waits, total_timeouts
from gv$system_event where event not in ('rdbms ipc message','smon timer',
'pmon timer', 'SQL*Net message from client','lock manager wait for remote message',
'ges remote message', 'gcs remote message', 'gcs for action', 'client message',
'pipe get', 'null event', 'PX Idle Wait', 'single-task message',
'PX Deq: Execution Msg', 'KXFQ: kxfqdeq - normal deqeue',
'listen endpoint status','slave wait','wakeup time manager')
order by time_waited desc)
where rownum < 11
order by time_waited desc;

-- SESSION/PROCESS REFERENCE:
-- This section is very important for most of the above sections to find out
-- which user/os_user/process is identified to which session/process.
--
set numwidth 7
column event format a30 tru
column program format a25 tru
column username format a15 tru
select p.inst_id, s.sid, s.serial#, p.pid, p.spid, p.program, s.username,
p.username os_user, sw.event, sw.seconds_in_wait sec
from gv$process p, gv$session s, gv$session_wait sw
where (p.inst_id = s.inst_id and p.addr = s.paddr)
and (s.inst_id = sw.inst_id and s.sid = sw.sid)
order by p.inst_id, s.sid;

-- SYSTEM STATISTICS:
-- All System Stats with values of > 0. These can be referenced in the
-- Server Reference Manual
--
set numwidth 5
column name format a60 tru
column value format 9999999999999999999999999
select inst_id, name, value
from gv$sysstat
where value > 0
order by inst_id, name;

-- CURRENT SQL FOR WAITING SESSIONS:
-- Current SQL for any session in the WAITING SESSIONS list
--
set numwidth 5
column sql format a80 wra
select sw.inst_id, sw.sid, sw.seconds_in_wait sec, sa.sql_text sql
from gv$session_wait sw, gv$session s, gv$sqlarea sa
where sw.sid = s.sid (+)
and sw.inst_id = s.inst_id (+)
and s.sql_address = sa.address
and sw.event not in ('rdbms ipc message','smon timer','pmon timer',
'SQL*Net message from client','lock manager wait for remote message',
'ges remote message', 'gcs remote message', 'gcs for action', 'client message',
'pipe get', 'null event', 'PX Idle Wait', 'single-task message',
'PX Deq: Execution Msg', 'KXFQ: kxfqdeq - normal deqeue',
'listen endpoint status','slave wait','wakeup time manager')
and sw.seconds_in_wait > 0
order by sw.seconds_in_wait desc;

-- WAIT CHAINS
-- 11.x+ Only (This will not work in < v11
-- See Note 1428210.1 for instructions on interpreting.
set pages 1000
set lines 120
set heading off
column w_proc format a50 tru
column instance format a20 tru
column inst format a28 tru
column wait_event format a50 tru
column p1 format a16 tru
column p2 format a16 tru
column p3 format a15 tru
column seconds format a50 tru
column sincelw format a50 tru
column blocker_proc format a50 tru
column waiters format a50 tru
column chain_signature format a100 wra
column blocker_chain format a100 wra
SELECT *
FROM (SELECT 'Current Process: '||osid W_PROC, 'SID '||i.instance_name INSTANCE,
'INST #: '||instance INST,'Blocking Process: '||decode(blocker_osid,null,'<none>',blocker_osid)||
' from Instance '||blocker_instance BLOCKER_PROC,'Number of waiters: '||num_waiters waiters,
'Wait Event: ' ||wait_event_text wait_event, 'P1: '||p1 p1, 'P2: '||p2 p2, 'P3: '||p3 p3,
'Seconds in Wait: '||in_wait_secs Seconds, 'Seconds Since Last Wait: '||time_since_last_wait_secs sincelw,
'Wait Chain: '||chain_id ||': '||chain_signature chain_signature,'Blocking Wait Chain: '||decode(blocker_chain_id,null,
'<none>',blocker_chain_id) blocker_chain
FROM v$wait_chains wc,
v$instance i
WHERE wc.instance = i.instance_number (+)
AND ( num_waiters > 0
OR ( blocker_osid IS NOT NULL
AND in_wait_secs > 10 ) )
ORDER BY chain_id,
num_waiters DESC)
WHERE ROWNUM < 101;

-- Taking Hang Analyze dumps
-- This may take a little while...
oradebug setmypid
oradebug unlimit
oradebug -g all hanganalyze 3
-- This part may take the longest, you can monitor bdump or udump to see
-- if the file is being generated.
oradebug -g all dump systemstate 258

set echo off

select to_char(sysdate) time from dual;

spool off

-- ---------------------------------------------------------------------------
Prompt;
Prompt racdiag output files have been written to:;
Prompt;
host pwd
Prompt alert log and trace files are located in:;
column host_name format a12 tru
column name format a20 tru
column value format a60 tru
select distinct i.host_name, p.name, p.value
from gv$instance i, gv$parameter p
where p.inst_id = i.inst_id (+)
and p.name like '%_dump_dest'
and p.name != 'core_dump_dest';
