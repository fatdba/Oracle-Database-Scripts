For standalone db:

select sid Waiter, p1raw,
substr(rawtohex(p1),1,30) Handle,
substr(rawtohex(p2),1,30) Pin_addr
from v$session_wait where wait_time=0 and event like '%library cache%';

For RAC DB:

select a.sid Waiter,b.SERIAL#,a.event,a.p1raw,
substr(rawtohex(a.p1),1,30) Handle,
substr(rawtohex(a.p2),1,30) Pin_addr
from v$session_wait a,v$session b where a.sid=b.sid
and a.wait_time=0 and a.event like 'library cache%';

or

set lines 152
col sid for a9999999999999
col name for a40
select a.sid,b.name,a.value,b.class
from gv$sesstat a , gv$statname b
where a.statistic#=b.statistic#
and name like '%library cache%';
