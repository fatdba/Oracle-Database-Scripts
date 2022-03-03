undef wait_event
undef last_x_days

@plusenv
col tcnt	format 99999	head 'Event|Cnt'
col event 	format a32 	head 'Event'		trunc
col pctcnt	format 999.9	head 'Pct%'
col sqlid_c	format a17	head 'SqlId:Child'
col obj		format a08	head 'ObjId'
col obj_name	format a65	head 'Object : SubObject'	trunc

break on event

select	 event
	,sqlid_c
	,obj_name
	,tcnt
from
(
select	 decode(ash.sql_id,null,'['||ash.module||']',(ash.sql_id||':'||ash.sql_child_number))			sqlid_c
	,ash.event						event
	,decode(ash.session_state,'ON CPU',null,decode(o.object_name,null,to_char(ash.current_obj#),o.owner||'.'||o.object_name||decode(o.subobject_name,null,' ',' : '||subobject_name))) obj_name
     	,sum(decode(ash.session_state,'ON CPU',1,1))     	tcnt
from 	 v$active_session_history 	ash
	,dba_objects			o
where 	 ash.event		= '&&wait_event'
and	 ash.session_state	= 'WAITING'
and	 ash.is_sqlid_current	= 'Y'
and 	 sample_time 		>= sysdate - &&last_x_days
and	 ash.current_obj#	> 0
and	 ash.current_obj#	= o.object_id (+)
group by decode(ash.sql_id,null,'['||ash.module||']',(ash.sql_id||':'||ash.sql_child_number))
	,ash.event
	,decode(ash.session_state,'ON CPU',null,decode(o.object_name,null,to_char(ash.current_obj#),o.owner||'.'||o.object_name||decode(o.subobject_name,null,' ',' : '||subobject_name)))
)
where	 rownum 	<= 10
order by tcnt desc
;
