-- Querying DBA_DATAPUMP_JOBS view
select * from dba_datapump_jobs;

-- The STATE column of the above view would give you the status of the JOB to show whether EXPDP or IMPDP jobs are still running, 
or have terminated with either a success or failure status.

-- Querying V$SESSION_LONGOPS & V$SESSION views:-
SELECT b.username, a.sid, b.opname, b.target,
            round(b.SOFAR*100/b.TOTALWORK,0) || '%' as "%DONE", b.TIME_REMAINING,
            to_char(b.start_time,'YYYY/MM/DD HH24:MI:SS') start_time
     FROM v$session_longops b, v$session a
     WHERE a.sid = b.sid      ORDER BY 6;


-- Querying V$SESSION_LONGOPS & V$DATAPUMP_JOB views:-
SELECT sl.sid, sl.serial#, sl.sofar, sl.totalwork, dp.owner_name, dp.state, dp.job_mode
     FROM v$session_longops sl, v$datapump_job dp
     WHERE sl.opname = dp.job_name
     AND sl.sofar != sl.totalwork;


-- Querying all the related views with a single query:-
select x.job_name,b.state,b.job_mode,b.degree
, x.owner_name,z.sql_text, p.message
, p.totalwork, p.sofar
, round((p.sofar/p.totalwork)*100,2) done
, p.time_remaining
from dba_datapump_jobs b
left join dba_datapump_sessions x on (x.job_name = b.job_name)
left join v$session y on (y.saddr = x.saddr)
left join v$sql z on (y.sql_id = z.sql_id)
left join v$session_longops p ON (p.sql_id = y.sql_id)
WHERE y.module='Data Pump Worker'
AND p.time_remaining > 0;


-- Use the following procedure and replace the JOB_OWNER & JOB_NAME as per your env. which you fetch from import.log:-
-- And below is the procedure:-
SET SERVEROUTPUT ON
DECLARE
  ind NUMBER;              
  h1 NUMBER;               
  percent_done NUMBER;     
  job_state VARCHAR2(30);  
  js ku$_JobStatus;        
  ws ku$_WorkerStatusList; 
  sts ku$_Status;          
BEGIN
h1 := DBMS_DATAPUMP.attach('JOB_NAME', 'JOB_OWNER');
dbms_datapump.get_status(h1,
           dbms_datapump.ku$_status_job_error +
           dbms_datapump.ku$_status_job_status +
           dbms_datapump.ku$_status_wip, 0, job_state, sts);
js := sts.job_status;
ws := js.worker_status_list;
      dbms_output.put_line('*** Job percent done = ' ||
                           to_char(js.percent_done));
      dbms_output.put_line('restarts - '||js.restart_count);
ind := ws.first;
  while ind is not null loop
    dbms_output.put_line('rows completed - '||ws(ind).completed_rows);
    ind := ws.next(ind);
  end loop;
DBMS_DATAPUMP.detach(h1);
end;
/ 

-- Also for any errors you can check the alert log and query the DBA_RESUMABLE view.
select name, sql_text, error_msg from dba_resumable;
