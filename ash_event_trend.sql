@plusenv
col event 	format a32 trunc
col sql_id	format a13
col wait	format 99999
col io		format 99999	head 'IO'
col tot_t0	format 99999	head '-15m|*Tot*'
col tot_t3	format 99999	head '-60m|Tot'
col tot_t2	format 99999	head '-45m|Tot'
col tot_t1	format 99999	head '-30m|Tot'
col rnk		format 99	head 'Rnk'
col delim	format a01	head '|'
col pctio	format 999	head 'IO%'
col pctwait	format 999	head 'WAI%'
col pcttot	format 999	head 'TOT%'

with      t3 as
(
select 	 event
	,sql_id
	,wait
	,100*ratio_to_report (wait) over () pctwait
	,io
	,100*ratio_to_report (io) over () pctio
	,tot
	,100*ratio_to_report (tot) over () pcttot
	,rownum	rnk
from
(
select 	 ash.event	event
	,ash.sql_id	sql_id
     	,sum(decode(ash.session_state,'WAITING',1,0)) - sum(decode(ash.session_state,'WAITING',decode(en.wait_class, 'User I/O',1,0),0))    wait
     	,sum(decode(ash.session_state,'WAITING', decode(en.wait_class, 'User I/O',1,0),0))    io
     	,sum(decode(ash.session_state,'ON CPU',1,1))     tot
from 	 v$active_session_history ash
        ,v$event_name en
where 	 event is not NULL  
and	 sql_id is not NULL
and	 ash.session_state = 'WAITING'
and 	 ash.event#=en.event# (+)
and 	 sample_time 	between sysdate-60/1440 and sysdate-46/1440
group by event, sql_id
order by sum(decode(ash.session_state,'WAITING',1,1)) desc
)
where rownum <=100
)
	,t2 as
(
select 	 event
	,sql_id
	,wait
	,100*ratio_to_report (wait) over () pctwait
	,io
	,100*ratio_to_report (io) over () pctio
	,tot
	,100*ratio_to_report (tot) over () pcttot
	,rownum	rnk
from
(
select 	 ash.event	event
	,ash.sql_id	sql_id
     	,sum(decode(ash.session_state,'WAITING',1,0)) - sum(decode(ash.session_state,'WAITING',decode(en.wait_class, 'User I/O',1,0),0))    wait
     	,sum(decode(ash.session_state,'WAITING', decode(en.wait_class, 'User I/O',1,0),0))    io
     	,sum(decode(ash.session_state,'ON CPU',1,1))     tot
from 	 v$active_session_history ash
        ,v$event_name en
where 	 event is not NULL  
and	 sql_id is not NULL
and	 ash.session_state = 'WAITING'
and 	 ash.event#=en.event# (+)
and 	 sample_time 	between sysdate-45/1440 and sysdate-31/1440
group by event, sql_id
order by sum(decode(ash.session_state,'WAITING',1,1)) desc
)
where rownum <=100
)
	,t1 as
(
select 	 event
	,sql_id
	,wait
	,100*ratio_to_report (wait) over () pctwait
	,io
	,100*ratio_to_report (io) over () pctio
	,tot
	,100*ratio_to_report (tot) over () pcttot
	,rownum	rnk
from
(
select 	 ash.event	event
	,ash.sql_id	sql_id
     	,sum(decode(ash.session_state,'WAITING',1,0)) - sum(decode(ash.session_state,'WAITING',decode(en.wait_class, 'User I/O',1,0),0))    wait
     	,sum(decode(ash.session_state,'WAITING', decode(en.wait_class, 'User I/O',1,0),0))    io
     	,sum(decode(ash.session_state,'ON CPU',1,1))     tot
from 	 v$active_session_history ash
        ,v$event_name en
where 	 event is not NULL  
and	 sql_id is not NULL
and	 ash.session_state = 'WAITING'
and 	 ash.event#=en.event# (+)
and 	 sample_time 	between sysdate-30/1440 and sysdate-16/1440
group by event, sql_id
order by sum(decode(ash.session_state,'WAITING',1,1)) desc
)
where rownum <=100
)
	,t0 as
(
select 	 event
	,sql_id
	,wait
	,100*ratio_to_report (wait) over () pctwait
	,io
	,100*ratio_to_report (io) over () pctio
	,tot
	,100*ratio_to_report (tot) over () pcttot
	,rownum	rnk
from
(
select 	 ash.event	event
	,ash.sql_id	sql_id
     	,sum(decode(ash.session_state,'WAITING',1,0)) - sum(decode(ash.session_state,'WAITING',decode(en.wait_class, 'User I/O',1,0),0))    wait
     	,sum(decode(ash.session_state,'WAITING', decode(en.wait_class, 'User I/O',1,0),0))    io
     	,sum(decode(ash.session_state,'ON CPU',1,1))     tot
from 	 v$active_session_history ash
        ,v$event_name en
where 	 event is not NULL  
and	 sql_id is not NULL
and	 ash.session_state = 'WAITING'
and 	 ash.event#=en.event# (+)
and 	 sample_time 	between sysdate-15/1440 and sysdate
group by event, sql_id
order by sum(decode(ash.session_state,'WAITING',1,1)) desc
)
where rownum <=20
)
select	 t3.wait	wait
	,t3.pctwait	pctwait
	,t3.io		io
	,t3.pctio	pctio
	,t3.tot		tot_t3
	,'|'		delim
	,t2.wait	wait
	,t2.pctwait	pctwait
	,t2.io		io
	,t2.pctio	pctio
	,t2.tot		tot_t2
	,'|'		delim
	,t1.wait	wait
	,t1.pctwait	pctwait
	,t1.io		io
	,t1.pctio	pctio
	,t1.tot		tot_t1
	,'|'		delim
	--,t0.rnk	rnk
	,t0.event	event
	,t0.sql_id	sql_id
	,'|'		delim
	,t0.wait	wait
	,t0.pctwait	pctwait
	,t0.io		io
	,t0.pctio	pctio
	,t0.tot		tot_t0
from	 t0
	,t3
	,t2
	,t1
where	 t0.event		= t3.event (+)
and	 t0.sql_id		= t3.sql_id (+)
and	 t0.event		= t2.event (+)
and	 t0.sql_id		= t2.sql_id (+)
and	 t0.event		= t1.event (+)
and	 t0.sql_id		= t1.sql_id (+)
order by t0.rnk
;
