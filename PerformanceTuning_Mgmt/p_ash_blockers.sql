
col sid		format 99999
col cnt		format 99
col objid	format 99999999
col event	format a32
col module	format a25 	trunc
col machine	format a35	trunc
col program	format a35	trunc

break on stime on pdt on bsid skip 1 

select 	 to_char(sample_time,'MM/DD HH24:MI')	stime
	,to_char(new_time(sample_time,'GMT','PDT'),'MM/DD HH24:MI') PDT
	,BLOCKING_SESSION			bsid
	,count(*)
	,SQL_ID					
	,CURRENT_OBJ#				objid
	,event					event
	,module
from 	 DBA_HIST_ACTIVE_SESS_HISTORY
where 	 to_char(new_time(sample_time,'GMT','PDT'),'MM/DD HH24:MI') between '07/25 02:50:00' 
									and '07/25 03:10:00'
and	 BLOCKING_SESSION is not null
and	 event not like 'log file %'
group by to_char(sample_time,'MM/DD HH24:MI')
	,to_char(new_time(sample_time,'GMT','PDT'),'MM/DD HH24:MI')
	,BLOCKING_SESSION
	,SQL_ID
	,CURRENT_OBJ#
	,event
	,module
order by to_char(sample_time,'MM/DD HH24:MI')
	,BLOCKING_SESSION
	,event
	,SQL_ID
;


