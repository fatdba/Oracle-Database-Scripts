PROMPT
PROMPT
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT------                 /)  (\
PROMPT------            .-._((,~~.))_.-,
PROMPT------             `-.   @@   ,-'
PROMPT------               / ,o--o. \
PROMPT------              ( ( .__. ) )
PROMPT------               ) `----' (
PROMPT------              /          \
PROMPT------             /            \
PROMPT------            /              \
PROMPT------    "The Silly Cow"
PROMPT----- Script: sessions_main.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Performance Management and Issue Identification
PROMPT----- Version: V1.2 (Date: 22-01-2016)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

set linesize 400 pagesize 400
select resource_name, current_utilization, max_utilization, limit_value
    from v$resource_limit
    where resource_name in ('sessions', 'processes');


select count(s.status) INACTIVE_SESSIONS
from gv$session s, v$process p
where
p.addr=s.paddr and
s.status='INACTIVE';


select count(s.status) "INACTIVE SESSIONS > 1HOUR "
from gv$session s, v$process p
where
p.addr=s.paddr and
s.last_call_et > 3600 and
s.status='INACTIVE';



select count(s.status) ACTIVE_SESSIONS
from gv$session s, v$process p
where
p.addr=s.paddr and
s.status='ACTIVE';


col program for a60
select s.program,count(s.program) Total_Sessions
from gv$session s, v$process p
where  p.addr=s.paddr and s.program like '%arserverd%'
group by s.program;


select s.program,count(s.program) Inactive_Sessions_from_1Hour
from gv$session s,v$process p
where     p.addr=s.paddr  AND
s.status='INACTIVE'
and s.last_call_et > (3600)
group by s.program
order by 2 desc;


set linesize 400 pagesize 400
col INST_ID for 99
col spid for a10
set linesize 150
col PROGRAM for a10
col action format a10
col logon_time format a16
col module format a13
col cli_process format a7
col cli_mach for a15
col status format a10
col username format a10
col last_call_et_Hrs for 9999.99
col sql_hash_value for 9999999999999col username for a10
set linesize 152
set pagesize 80
col "Last SQL" for a60
col elapsed_time for 999999999999
select p.spid, s.sid,s.last_call_et/3600 last_call_et_Hrs ,s.status,s.action,s.module,s.program,t.disk_reads,lpad(t.sql_text,30) "Last SQL"
from gv$session s, gv$sqlarea t,gv$process p
where s.sql_address =t.address and
s.sql_hash_value =t.hash_value and
p.addr=s.paddr and
s.status='INACTIVE'
and s.last_call_et > (3600)
order by last_call_et;
