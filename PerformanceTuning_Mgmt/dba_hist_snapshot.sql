col snap_id		format 99999
col ServerTime		format a18
col MyTime		format a18
select 	 snap_id
	,to_char(BEGIN_INTERVAL_TIME,'YYYY/MM/DD HH24:MI')			  ServerTime
	,to_char(new_time(BEGIN_INTERVAL_TIME+(5.5/24),'GMT','GMT'),'YYYY/MM/DD HH24:MI') MyTime
from 	 dba_hist_snapshot
order by 1
;
select 	 to_char(min(BEGIN_INTERVAL_TIME),'YYYY/MM/DD HH24:MI')	MinServer
	,to_char(new_time(min(BEGIN_INTERVAL_TIME),'GMT','PDT'),'YYYY/MM/DD HH24:MI') MinMyTime
	,to_char(max(BEGIN_INTERVAL_TIME),'YYYY/MM/DD HH24:MI') MaxServer
	,to_char(new_time(max(BEGIN_INTERVAL_TIME),'GMT','PDT'),'YYYY/MM/DD HH24:MI') MaxMyTime
from     dba_hist_snapshot
;
