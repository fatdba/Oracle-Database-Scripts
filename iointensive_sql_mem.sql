PROMPT
PROMPT
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT------                 /)  (\
PROMPT------            .-._((,~~.))_.-,
PROMPT------             `-.   @@   ,-'
PROMPT------               / ,o--o. \
PROMPT------              ( ( .__. ) )
PROMPT------               ) `----' (
PROMPT------              /          \
PROMPT------             /            \
PROMPT------            /              \
PROMPT------    "The Silly Cow"
PROMPT----- Script: iointensive_sql_mem.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Performance Management and Issue Identification
PROMPT----- Version: V1.2 (Date: 11-02-2014)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~set feed off;
set pagesize 10000;
set wrap off;
set linesize 200;
set heading on;
set tab on;
set scan on;
set verify off;
--
column sql_text format a40 heading 'SQL-Statement'
column executions format 999,999 heading 'Total|Runs'
column reads_per_run format 999,999,999.9 heading 'Read-Per-Run|[Number of]'
column disk_reads format 999,999,999 heading 'Disk-Reads|[Number of]'
column buffer_gets format 999,999,999 heading 'Buffer-Gets|[Number of]'
column hit_ratio format 99 heading 'Hit|Ratio [%]'

ttitle left 'I/O-intensive SQL-Statements in the memory (V$SQLAREA)' -
skip 2

SELECT sql_text, executions,
       round(disk_reads / executions, 2) reads_per_run,
       disk_reads, buffer_gets,
       round((buffer_gets - disk_reads) / buffer_gets, 2)*100 hit_ratio
FROM   v$sqlarea
WHERE  executions  > 0
AND    buffer_gets > 0
AND    (buffer_gets - disk_reads) / buffer_gets < 0.80
ORDER BY 3 desc;
