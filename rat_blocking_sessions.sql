--------------------------------------
--              Query 1             --
--------------------------------------

connect sys/<password> as sysdba
set linesize 500 pagesize 200

col inst_id format 99999
col sid format 99999
col spid format a6
col blocking_session_status format a6 heading 'BS'
col blocking_instance format 99 heading 'BI'
col blocking_session format 99999 heading 'BLKSID'
col session_type format a11
col event format a31
col file_name format a21
col file_id format 9999999999999999999
col call_counter format 9999999
col wait_for_scn format 99999999999999 heading 'WAITING FOR'
col wfscn format 99999999999999 heading 'WFSCN'
col commit_wait_scn format 99999999999999 heading 'CWSCN'
col post_commit_scn format 99999999999999 heading 'PCSCN'
col clock format 99999999999999999999 heading 'CLOCK'
col next_ticker format 999999999999999999999 heading 'NEXT TICKER'

select wrt.inst_id, wrt.sid, wrt.serial#, wrt.spid,
s.BLOCKING_SESSION_STATUS, s.BLOCKING_INSTANCE,
s.blocking_session,
wrt.session_type, wrt.event,
wrt.file_name, wrt.file_id, wrt.call_counter,
wrt.wait_for_scn,
greatest(wrt.dependent_scn, wrt.statement_scn) as wfscn,
wrt.commit_wait_scn, wrt.post_commit_scn,
wrt.clock, wrt.next_ticker
from gv$workload_replay_thread wrt, gv$session s
where wrt.sid = s.sid
and wrt.serial# = s.serial#
order by inst_id, sid
;







