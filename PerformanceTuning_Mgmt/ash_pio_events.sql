undef last_x_mins

@plusenv
col event 	format a30 trunc
col wait	format 999,999
col tot		format 9,999,999	head 'ToT'
col pct		format 999.9		head 'Pct'
col wtcls	format a10		head 'Wait Class'
col twaited	format 99,999,999	head 'Time|Waited|ms'
col avg_wait	format 999.9		head 'Avg|Wait|ms'

break on wtcls skip 1
select 	 en.wait_class			wtcls
	,ash.event			event
	,sum(ash.time_waited)/count(*)/1000  avg_wait
	,sum(ash.time_waited)/1000	twaited
     	,count(*)			tot
	,100*ratio_to_report (count(*)) over (partition by en.wait_class) pct
from 	 v$active_session_history 	ash
        ,v$event_name 			en
where 	 ash.event#		= en.event# (+)
and	 en.wait_class		in ('User I/O', 'System I/O')
and 	 sample_time 		>= sysdate - &&last_x_mins/1440
and	 ash.time_waited	> 0
group by en.wait_class
	,ash.event
order by en.wait_class
	,ash.event
;
