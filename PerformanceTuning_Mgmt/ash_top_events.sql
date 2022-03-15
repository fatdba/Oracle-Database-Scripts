col event 	format a32 trunc
col sql_id	format a13
col cpu		format 999,999
col wait	format 999,999
col io		format 999,999
col tot		format 9,999,999	head '*TOT*'
col pctwait	format 999.9	head 'WAIT%'
col pctio	format 999.9	head 'IO%'
col pcttot	format 999.9	head 'TOT%'
select 	 event
	,sql_id
	,wait
	,100*ratio_to_report (wait) over () pctwait
	,io
	,100*ratio_to_report (io) over () pctio
	,tot
	,100*ratio_to_report (tot) over () pcttot
from
(
select 	 ash.event	event
	,ash.sql_id	sql_id
     	,sum(decode(ash.session_state,'WAITING',1,0)) - sum(decode(ash.session_state,'WAITING',decode(en.wait_class, 'User I/O',1,0),0))    wait
     	,sum(decode(ash.session_state,'WAITING', decode(en.wait_class, 'User I/O',1,0),0))    io
     	,sum(decode(ash.session_state,'ON CPU',1,1))     tot
from 	 v$active_session_history 	ash
        ,v$event_name 			en
where 	 event 			is not NULL  
and	 sql_id 		is not NULL
and	 ash.is_sqlid_current	= 'Y'
and	 ash.session_state 	= 'WAITING'
and 	 ash.event#		= en.event# (+)
and 	 sample_time 		>= sysdate - &&last_x_mins/1440
group by event, sql_id
order by sum(decode(ash.session_state,'WAITING',1,1)) desc
)
where rownum <=10
;
