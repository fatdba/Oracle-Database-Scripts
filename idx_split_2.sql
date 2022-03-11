@plusenv
col module	format a30 	trunc
col sid		format 99999
col state	format a07
col objid	format 999999999
col event	format a20	trunc

with	 ash as
(
select 	 distinct
	 session_id	
	,session_type
	,event
	,session_state
	,sql_id
	,current_obj#	
	,module 
	,machine
from 	 v$active_session_history 
where 	 sample_time 	>= sysdate - 1/(24*60*60)
and 	 session_type 	= 'FOREGROUND'
)
select * from
(
select 	 /*+ ordered */
	 ash.session_id		sid
	,decode(ash.event,null,'<'||ash.session_state||'>',ash.event)	event
	,ash.sql_id
	,ses.prev_sql_id
	,ash.current_obj#	objid
	,decode(ash.module,null,'<'||ash.machine||'>',ash.module)	module
	,decode(sn.name,'leaf node splits',		'LeafSplit'
	               ,'branch node splits',		'BranchSplit'
		       ,'leaf node 90-10 splits',	'Leaf90Split' 
		       ,'root node splits',		'RootSplit'
		       ,sn.name)	split_type
	,ss.value 			svalue
from 	 ash
	,v$session	ses
	,v$sesstat 	ss
	,v$statname 	sn 
where	 ash.session_id	= ss.sid
and	 ash.session_id	= ses.sid
and 	 ss.statistic#	= sn.statistic# 
and 	 sn.name 	like '%node%splits%' 
and 	 ss.value 	> 0
)
pivot
(
	max(svalue) for split_type in ('LeafSplit','Leaf90Split','BranchSplit','RootSplit')
)
order by sql_id
;
