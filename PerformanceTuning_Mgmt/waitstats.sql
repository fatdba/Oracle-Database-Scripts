@plusenv
col pct		format 999.9
select 	 class
	,count
	,time 
	,100 * ratio_to_report(time) over () pct
from 	 v$waitstat 
order by time
/
