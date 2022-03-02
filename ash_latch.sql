@plusenv
column event format a25 trunc
column program format a10
column module format a20 trunc
column object_name format a30
column ms format 999
column sql_text format a60
column lock_type format a4 
column pct format 99.9

WITH ash_query AS (
SELECT 	 event
	,program
        ,h.module
	,h.action
	,object_name
        ,SUM(time_waited)/1000 ms
	,COUNT( * ) waits
	,sql_text
	,RANK() OVER (ORDER BY SUM(time_waited) DESC) AS time_rank
	,ROUND(SUM(time_waited) * 100 / SUM(SUM(time_waited)) OVER (), 2)             pct
FROM  	 v$active_session_history h 
	,dba_objects o
	,v$sql s
WHERE 	 h.event LIKE '%latch%' 
or 	 h.event like '%mutex%'
and	 h.current_obj# = o.object_id 
and	 h.sql_id 	= s.sql_id
GROUP BY event
	,program
	,h.module
	,h.action
        ,object_name
	,sql_text
)
SELECT event,module, object_name, ms,pct,
         sql_text
FROM ash_query
WHERE time_rank <= 10
ORDER BY time_rank; 
