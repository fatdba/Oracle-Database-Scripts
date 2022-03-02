@plusenv
undef for_the_last_x_min

col pct 	format 99.9	head '%'
col cnt		format 99999	head 'Ses|Cnt'
col oname	format a60	head 'Object - Subobject'
col event	format a38	head 'Wait Event / On CPU'	trunc
col objid	format 99999999 head 'Obj Id'

-- on cpu vs waiting --
with 	 state_total as
(select count(*) evtot from v$active_session_history
where sample_time > sysdate-&&for_the_last_x_min/1440
and session_state is not null
)
	,sess_state as
(
select count(*) cnt, session_state
from 	 v$active_session_history
where sample_time > sysdate-&&for_the_last_x_min/1440
group by session_state
)
select 	 cnt
	,(cnt/evtot)*100	pct
	,session_state
from 	 state_total
	,sess_state
order by pct
/

-- by wait event --
with 	 event_total as
(
select count(*) evtot from v$active_session_history
where sample_time > sysdate-&&for_the_last_x_min/1440
and event is not null
)
	,event_grp as
(
select   cnt, event
from
(
select count(*) cnt, event 
from 	 v$active_session_history
where sample_time > sysdate-&&for_the_last_x_min/1440
and event is not null
group by event
order by count(*) desc
)
where rownum <=15
)
select 	 cnt
	,(cnt/evtot)*100	pct
	,event
from 	 event_total
	,event_grp
order by pct
/

-- on cpu : break down by sqlid --
with 	 cpu_total as
(select count(*) cputot from v$active_session_history
where sample_time > sysdate-&&for_the_last_x_min/1440
and session_state = 'ON CPU'
)
	,sqlid_cpu as
(
select 	 cnt, sql_id, current_obj#
from
(
select count(*) cnt, sql_id, current_obj# 
from 	 v$active_session_history
where sample_time > sysdate-&&for_the_last_x_min/1440
and session_state = 'ON CPU'
group by sql_id, current_obj#
order by count(*) desc
)
where rownum <=15
)
select 	 cnt
	,(cnt/cputot)*100	pct
	,'ON CPU'		event
	,sql_id
	,current_obj#		objid
	,o.object_name||decode(subobject_name,null,' ',' - ')||subobject_name oname
from 	 cpu_total
	,sqlid_cpu g
	,dba_objects o
where	 g.current_obj# = o.object_id (+)
order by pct
/

-- by wait event + sqlid + obj --
with 	 event_total as
(select count(*) evtot from v$active_session_history
where sample_time > sysdate-&&for_the_last_x_min/1440
and event is not null
and current_obj# >= 0
)
	,event_grp as
(
select 	 cnt, event, sql_id, current_obj#
from
(
select count(*) cnt, event, sql_id, current_obj# 
from 	 v$active_session_history
where sample_time > sysdate-&&for_the_last_x_min/1440
and event is not null
and current_obj# >= 0
group by event, sql_id, current_obj#
order by count(*) desc
)
where rownum <=15
)
select 	 cnt
	,(cnt/evtot)*100	pct
	,event
	,sql_id
	,current_obj#		objid
	,o.object_name||decode(subobject_name,null,' ',' - ')||subobject_name oname
from 	 event_total
	,event_grp g
	,dba_objects o
where	 g.current_obj# = o.object_id (+)
order by pct
/
