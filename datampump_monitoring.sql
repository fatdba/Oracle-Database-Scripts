SET lines 1000
COL owner_name FORMAT a10;
COL job_name FORMAT a20
COL state FORMAT a11
COL operation LIKE state
COL job_mode LIKE state
select * from dba_datapump_jobs where state='EXECUTING';


-- sql 2
SELECT SID, SERIAL#, opname, SOFAR, TOTALWORK,
ROUND(SOFAR/TOTALWORK*100,2) COMPLETE
FROM V$SESSION_LONGOPS
WHERE TOTALWORK != 0 AND SOFAR != TOTALWORK
order by 1;

-- sql 3
select sid, serial#, sofar, totalwork,
dp.owner_name, dp.state, dp.job_mode
from gv$session_longops sl, gv$datapump_job dp
where sl.opname = dp.job_name and sofar != totalwork;



-- Check current job details 

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

