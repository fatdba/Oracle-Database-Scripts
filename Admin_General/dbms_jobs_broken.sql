SELECT	 '=== '||to_char(sysdate,'MM/DD/YY HH24:MI:SS')||' ===' curr_date 
FROM	 dual
;
rem start rpt140	'Broken Jobs'
col job 	format 999999
col sid 	format 99999
col b 		format a1
col fa 		format 99
col min 	format 99999
col last_date 	format a15
col next_date 	format a15
col curr_date 	format a25
col interval 	format a24
col owner 	format a08
col what 	format a46 word_wrapped

SELECT	 /*+ RULE */
	 j.job 
	,jr.sid
	,to_char(j.last_date,'YYMMDD HH24:MI:SS') last_date
	,to_char(j.next_date,'YYMMDD HH24:MI:SS') next_date
	,j.broken b
	,j.failures fa
	,j.interval
	,round((j.next_date - sysdate)*24*60) min
	,j.schema_user owner
	,j.what
FROM	 dba_jobs_running jr
        ,dba_jobs	  j
WHERE	 j.job 		= jr.job (+)
AND	(j.broken 	= 'Y'
OR	 j.failures	> 0
	)
ORDER BY 
	 j.failures
	,j.broken
	,j.last_date 
;
ttitle off
