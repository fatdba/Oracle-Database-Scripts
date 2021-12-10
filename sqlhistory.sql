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
PROMPT----- Script: sqlhistory.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Performance Management and Issue Identification
PROMPT----- Version: V1.2 (Date: 04-02-2020)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~set linesize 400 pagesize 400
col END_INTERVAL_TIME for a29
col MODULE for a19
col SCHEMA for a10

select s.end_interval_time, h.instance_number as Inst_num, h.plan_hash_value as PHV, h.module, h.parsing_schema_name as SCHEMA, h.executions_delta,
h.rows_processed_delta, h.elapsed_time_delta from dba_hist_sqlstat h, dba_hist_snapshot s
WHERE  h.dbid = '&DBID' AND h.sql_id = '&SQLID' AND h.snap_id = s.snap_id AND h.dbid = s.dbid AND h.instance_number = s.instance_number
ORDER BY s.end_interval_time, h.instance_number;
