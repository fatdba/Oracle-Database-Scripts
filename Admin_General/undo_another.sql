set pages 1000
set lines 190
col name format a30 
col username format a20
col module format a12
col action format a20
col space_used format a30
select a.username username,a.sid,r.name,b.start_time,a.module module,a.action action, (b.used_ublk * 8192)/(1024*1024) space_used_MB
from v$session a, v$transaction b,v$rollname r
where  a.taddr=b.addr
and b.xidusn = r.usn
order by 7
/
