
set lines 140
col fo_time	format a20
col fo_pdt	format a20
col fo_reason	format a80
col min_ago	format 9999
select 	 LAST_FAILOVER_TIME fo_time
	,to_char(new_time(to_date(LAST_FAILOVER_TIME,'MM/DD/YYYY HH24:MI:SS'),'GMT','PDT'), 'MM/DD/YYY HH24:MI:SS') fo_pdt
	,(sysdate - to_date(LAST_FAILOVER_TIME,'MM/DD/YYYY HH24:MI:SS'))*24*60	min_ago
	,LAST_FAILOVER_REASON fo_reason
from V$FS_FAILOVER_STATS;
