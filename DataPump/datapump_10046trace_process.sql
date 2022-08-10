-- DATAPUMP_10046_TRACING_START.SQL: (START)
-- Modify as per your need
-- Test script
SET ECHO OFF
SET FEEDBACK OFF
--
--    Start 10046 tracing at level 12 of Data Pump Master process (DM##) and
-- associated Data Pump Worker processes (DW##) assuming that ## is 00 through
-- FF, for a named user specified Data Pump job.
--
--    If possible, to reduce input errors, cut-and-paste the target job name
-- from the list of names of active Data Pump jobs.
--
--    Note that Setting SQLPROMPT to two dashes results in those lines being
-- trimmed completely from the spooled output when TRIMSPOOL ON is set.
--
SELECT JOB_NAME,OPERATION FROM DBA_DATAPUMP_JOBS WHERE STATE='EXECUTING' ORDER BY JOB_NAME;
PROMPT
PROMPT What is the name of the job that you want to start 10046 tracing for ?
ACCEPT TARGET_JOB_NAME
SET ECHO OFF
SET FEEDBACK OFF
SET HEADING OFF
SET LINESIZE 1024
SET PAGESIZE 0
SET SQLPROMPT '-- '
SET TERM OFF
SET TRIMSPOOL ON
SET VERIFY OFF
SPOOL TMP_DATAPUMP_10046_TRACING_START.SQL
SELECT 'execute sys.dbms_system.set_ev('||TRIM(SID)||','||TRIM(SERIAL#)||',10046,12,'''') /* Start tracing the '||TRIM(PROGRAM)||' program */;' FROM V$SESSION WHERE PROGRAM LIKE '%(DM__)%' AND UPPER(TRIM(ACTION))=UPPER(TRIM('&TARGET_JOB_NAME'));
SELECT 'execute sys.dbms_system.set_ev('||TRIM(SID)||','||TRIM(SERIAL#)||',10046,12,'''') /* Start tracing the '||TRIM(PROGRAM)||' program */;' FROM V$SESSION WHERE PROGRAM LIKE '%(DW__)%' AND UPPER(TRIM(ACTION))=UPPER(TRIM('&TARGET_JOB_NAME'));
SPOOL OFF
SET TRIMSPOOL OFF
SET SQLPROMPT 'SQL> '
SET PAGESIZE 14
SET LINESIZE 80
SET HEADING ON
SET FEEDBACK ON
SET ECHO ON
SET TERM ON
@TMP_DATAPUMP_10046_TRACING_START.SQL
--
--    If everything went as expected, there should be at least 2 calls to
-- 'execute sys.dbms_system.set_ev(...) ...' above this line.
--
-- DATAPUMP_10046_TRACING_START.SQL: (END)
