--
-- top sqlids in terms of workarea duration in the last 2 days
--
@plusenv
col seconds 	format 999,999
col operation 	format a20
col "O/1/M" 	format a11
col sql_text 	format a60
col last_exec	format a15
col ltsizem	format 99,999	head 'Last|TempMB'
col mtsizem	format 99,999	head 'Max|TempMB'
col sqlidc	format a16
col latime	format a11		head 'Last Active'
col minago	format 999,999	head 'MinsAgo'
col rnk		format 99

break on sqlidc skip 1
WITH sql_workarea AS
(
        SELECT 	 sql_id || '-' || child_number 			sqlidc
	 	,to_char(last_active_time,'MMDD HH24MISS')  	latime
		,(sysdate - last_active_time)*24*60		minago
           	,operation_type 				operation 
           	,last_execution 				last_exec
           	,ROUND (active_time / 1000000, 2) 		seconds
           	,optimal_executions || '/' || onepass_executions || '/' || multipasses_executions 	o1m
		,last_tempseg_size/1024/1024 			ltsizem
		,max_tempseg_size/1024/1024 			mtsizem
	   	,substr(replace(sql_text,chr(13)),1,46) 	sql_text
           	,RANK () OVER (ORDER BY active_time DESC) 	rnk
        FROM 	 v$sql_workarea 
	JOIN 	 v$sql 
        USING 	(sql_id, child_number)  
	where	 last_active_time > sysdate - 2
)
SELECT   sqlidc
	,latime
	,minago
	,seconds
	,rnk
	,operation
	,last_exec
	,o1m "O/1/M"
	,ltsizem
	,mtsizem
	,sql_text
FROM 	 sql_workarea
WHERE 	 rnk <= 30
ORDER BY sqlidc
	,minago;
