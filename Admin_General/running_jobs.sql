REM ------------------------------------------------------------------------------------------------
REM $Id: jobs-running.sql,v 1.1 2002/03/13 23:57:08 hien Exp $
REM #DESC      : Show running jobs
REM Usage      : 
REM Description: List all dbms_jobs that are currently running
REM ------------------------------------------------------------------------------------------------

@plusenv

set linesi 190
col job 	format 9999999
col sid 	format 99999
col b 		format a1
col fa 		format 99
col min 	format 99999
col last_date 	format a15
col this_date 	format a15
col next_date 	format a15
col interval 	format a24
col owner 	format a08
col what 	format a35 word_wrapped

SELECT	 /*+ RULE */
	 j.job 
	,jr.sid
	,to_char(j.last_date,'YYMMDD HH24:MI:SS') last_date
	,to_char(j.this_date,'YYMMDD HH24:MI:SS') this_date
	,to_char(j.next_date,'YYMMDD HH24:MI:SS') next_date
	,j.broken b
	,j.failures fa
	,j.interval
	,round((j.next_date - sysdate)*24*60) min
	,j.schema_user owner
	,j.what
FROM	 dba_jobs_running jr
        ,dba_jobs	  j
WHERE	 j.job 		= jr.job 
AND	 jr.sid		is not null
ORDER BY 
	 j.failures
	,j.broken
	,j.last_date 
;
