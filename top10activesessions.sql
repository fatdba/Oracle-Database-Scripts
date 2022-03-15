col osuser format a10 trunc
col LastCallET format 99,999
col sid format 9999
col spid formar 999999
col username format a10 trunc
col uprogram format a25 trunc
col machine format a10 trunc
set linesize 132
set verify off
select * from (
select to_char(s.logon_time, ‘mm/dd hh:mi:ssAM’) loggedon,
s.sid, s.status,
floor(last_call_et/60) “LastCallET”,
s.username, s.osuser,
p.spid, s.module || ‘ – ‘ || s.program uprogram,
s.machine, s.sql_hash_value
from v$session s, v$process p
where p.addr = s.paddr
and s.type = ‘USER’
and module is not null
and s.status = ‘ACTIVE’
order by 4 desc)
where rownum < 11;
