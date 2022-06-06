REM -----------------------------------------------------
REM $Id: ses-wait-by-sid.sql,v 1.2 2003/03/21 23:26:07 hien Exp $
REM #DESC       : Get wait events for that sid after setting sid by set-sid.sql 
REM Usage       : No parameters
REM Description : Get wait events for that sid after setting sid by set-sid.sql
REM -----------------------------------------------------

set lines 130
col username format a10
col schemaname format a10
col osuser format a8
col machine format a10
col event format a30
col status format a6
col prms format a20 wrap
break on machine skip 1 on osuser on process

select s.MACHINE, s.OSUSER, s.PROCESS, s.sid, s.USERNAME, 
	decode(s.STATUS,'INACTIVE',NULL,s.STATUS) status,
	w.event, w.wait_time, w.p1||'-'||w.p2||'-'||w.p3 prms
from v$session s,
	v$session_wait w
where	s.sid = w.sid
and     s.sid = nvl(&vsid,s.sid)
order by s.machine, s.osuser, s.process;
