undef sid
undef last_x_min

set lines 200 echo off
col sess	format a10
col stime	format a08
col sta  	format a04	head 'Sta'
col event	format a24 trunc
col seq#	format 99999
col wtime	format 9999999
col twaited	format 99999999
col p1p2p3	format a18	head '        P1:P2:P3'
col wclass	format a11 			trunc
col sqlid_cn	format a16	head 'SqlId:ChildNo'
col blk		format a01	head 'X'
col oc		format 999
col cn		format 99
col flags	format a12	head 'CPH S PRXJBZ'
col mod		format a20	head 'Module'	trunc
col sqlstart	format a05	head 'SQL|Start'
col sqlxid	format 99999999 head 'SqlExecId'
col sidser	format a15  		head 'Sid,Serial<Blk'
col dur		format 999999		head 'Dur|ms'
col cpu		format 9999		head 'CPU|ms'
col dbtime	format 999999		head 'DB Time|ms'

break on sidser skip 1 on mod on sqlid_cn on sqlxid on sqlstart
select 	 lpad(session_id,4,' ')||','||lpad(session_serial#,5,' ')||decode(substr(blocking_session_status,1,1),'V','<',' ')||lpad(blocking_session,4,' ')	sidser
	,to_char(sample_time, 'HH24:MI:SS') 	stime
	,module					mod
	,sql_id||decode(sql_child_number,-1,'   ',':'||lpad(sql_child_number,2,' '))	sqlid_cn
	,sql_exec_id				sqlxid
	,to_char(sql_exec_start,'MI:SS')	sqlstart
	,in_connection_mgmt||in_parse||in_hard_parse||' '||in_sql_execution||' '||in_plsql_execution||in_plsql_rpc||in_java_execution||in_bind||in_cursor_close 	flags
	,decode(session_state,'WAITING','Wait','ON CPU','cpu',' ? ')		sta
	,seq#					seq#
	,event					event
	,lpad(least(p1,9999999),7,' ')||':'||lpad(least(p2,999999),6,' ')||':'||lpad(least(p3,9),3,' ') p1p2p3
	,wait_class				wclass
	,tm_delta_time/1000			dur
	,tm_delta_cpu_time/1000			cpu
	,tm_delta_db_time/1000			dbtime
from	 v$active_session_history
where	 session_id = &&sid
and	 sample_time between sysdate-70/1440 and sysdate-30/1440
order by sample_time
;
