--
-- Show active sessions from latest ASH sample
--
@plusenv
set linesi 290
col hostcpu	format 999.9	head 'Host|Cpu%'
col module	format a15 	head 'Module'		trunc
col sidser	format a15  	head 'Sid,Serial<Blk'
col state	format a07
col objid	format 9999999
col event	format a23	head 'Event'		trunc
col pct		format 999.9	head 'Sid|Cpu%'
col cpu		format 99.999	head 'CPU|ms'
col lreads	format 9999999	head 'Logical|Reads'
col preads	format 999999	head 'Phys|Reads'
col lread_pct	format 99	head 'LR|%'
col pread_pct	format 99	head 'PR|%'
col hparse	format 99	head 'Hard|Parse'
col sparse	format 999	head 'Soft|Parse'
col pgak	format 999,999	head 'PGAk'
col sqlstart	format a05	head 'SQL|Start'
col temp_mb	format 99999	head 'Temp|MB'
col secs_ago	format 999	head 'Sec|Ago'
col opid	format 999	head 'Op|Id'
col oper	format a20	head 'Operation'	trunc
col oname	format a28	head 'Object'		trunc
col sqlidc	format a17	head 'SqlId:Child'
col p1p2p3	format a15	head '   P1:P2:P3'
col sqlop	format a03	head 'Cmd'		trunc
col is_current	format a01	head 'C'

break on hostcpu

with	 ash as
(
select 	 session_id	
	,is_sqlid_current
	,session_serial#
	,session_type
	,event
	,session_state
	,sql_id
	,sql_child_number
	,sql_opname
	,sql_plan_line_id
	,sql_plan_operation
	,sql_plan_options
	,current_obj#	
	,module 
	,machine
	,sql_exec_start
	,temp_space_allocated
	,p1
	,p2
	,p3
from 	 v$active_session_history 
where	 sample_id	= (select max(sample_id) from v$active_session_history)
)
select * from
(
select 	 /*+ ordered */
	 ccpu.hostcpu 								hostcpu
	,lpad(ses.sid,4,' ')||','||lpad(ses.serial#,5,' ')||decode(substr(ses.blocking_session_status,1,1),'V','<',' ')||lpad(ses.blocking_session,4,' ')	sidser
	,round(sm.cpu * 100 / sm.intsize_csec, 2) 				pct
	--,sm.logical_reads							lreads
	,sm.logical_read_pct							lread_pct
	--,sm.physical_reads							preads
	,sm.physical_read_pct							pread_pct
	,sm.pga_memory/1024							pgaK
	,least(999,(sysdate-ash.sql_exec_start)*24*60*60)			secs_ago
	,nvl(ash.module,'['||substr(ash.machine,1,instr(ash.machine,'amazon')-2)||']')	module
	,ash.sql_id||decode(ash.sql_id,null,'',':')||decode(ash.sql_child_number,-1,'',ash.sql_child_number) 	sqlidc
	--,ash.is_sqlid_current							is_current
	--,ash.sqlstart
	--,ses.prev_sql_id
	,ash.sql_opname								sqlop
	,decode(ses.state,'WAITING',o.owner||decode(o.object_name,null,null,'.')||o.object_name,null)		oname
	,decode(ash.event,null,'['||ash.session_state||']',ash.event)		event
	,decode(ash.event,null,'',lpad(least(ash.p1,9999),3,' ')||':'||lpad(least(ash.p2,9999999),7,' ')||':'||lpad(least(ash.p3,999),3,' '))	p1p2p3
	,ash.sql_plan_line_id							opid
	,ash.sql_plan_operation||' '||ash.sql_plan_options 			oper
	--,sm.cpu/1000		cpu
	--,sm.hard_parses		hparse
	--,sm.soft_parses		sparse
	--,ash.temp_mb		temp_mb
from 	 ash
	,v$session	ses
	,v$sessmetric   sm
	,dba_objects	o
	,(select avg(value) hostcpu from v$sysmetric where METRIC_NAME='Host CPU Utilization (%)') ccpu
where	 ash.session_id		= ses.sid
and	 ash.session_serial# 	= ses.serial#
and      ses.sid        	= sm.session_id
and      ses.serial#    	= sm.session_serial_num
and	 ash.session_id 	= sm.session_id
and	 ash.session_serial# 	= sm.session_serial_num
and	 ash.current_obj#(+)	= o.object_id
)
order by module
	,sqlidc
	,oname
	,event
;
