undef sql_id
undef last_x_mins

@plusenv
col twait	format 99999	head 'Event|Cnt'
col event 	format a32 	head 'Event'		trunc
col pctwait	format 999.9	head 'Pct%'
col sqlid_c	format a17	head 'SqlId:Child'
col phash	format 9999999999 head 'Plan Hash'
col pobj	format a42	head 'Object'		trunc
col plid	format 9999 	noprint
col poper	format a75	head 'Operation'

break on sqlid_c on phash skip 1 on poper on pobj 
select 	 sqlid_c
	,phash
	,plid	
	,poper
	,pobj
	,twait
	,100*ratio_to_report (twait) over (partition by sqlid_c,phash) pctwait
	,event
from
(
select	 p.sql_id||':'||p.child_number				sqlid_c
	,p.plan_hash_value					phash
	,p.id							plid
	,lpad(' ',1*p.depth)||p.id||' '||p.operation||' '||p.options				poper
	,p.object_owner||decode(p.object_name,null,'','.')||p.object_name 			pobj
	,decode(ash.session_state,'ON CPU','ON CPU',ash.event)	event
     	,sum(decode(ash.session_state,'ON CPU',1,1))     	twait
from	 v$sql_plan			p
	,v$active_session_history 	ash
where 	 p.sql_id 			= '&&sql_id'
and	 p.sql_id 			= ash.sql_id (+)
and	 p.child_number			= ash.sql_child_number (+)
and	 p.id				= ash.sql_plan_line_id (+)	
and	 p.plan_hash_value		= ash.sql_plan_hash_value (+)
and 	 ash.sample_time 		>= sysdate - &&last_x_mins/1440
group by p.sql_id||':'||p.child_number
	,p.plan_hash_value				
	,p.id
	,lpad(' ',1*p.depth)||p.id||' '||p.operation||' '||p.options
	,p.object_owner||decode(p.object_name,null,'','.')||p.object_name
	,decode(ash.session_state,'ON CPU','ON CPU',ash.event)
)
order by sqlid_c
	,phash
	,plid
	,twait desc
;
