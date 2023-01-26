--
-- Find the orphaned Data Pump jobs :
-- 
--


SELECT owner_name, job_name, rtrim(operation) "OPERATION",
rtrim(job_mode) "JOB_MODE", state, attached_sessions
FROM dba_datapump_jobs
WHERE job_name NOT LIKE 'BIN$%' and state='NOT RUNNING'
ORDER BY 1,2;

-- Drop the tables

SELECT 'drop table ' || owner_name || '.' || job_name || ';'
FROM dba_datapump_jobs WHERE state='NOT RUNNING' and job_name NOT LIKE 'BIN$%'
