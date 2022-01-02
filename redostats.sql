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
PROMPT----- Script: redostats.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Version: V1.0 (Date: 04-01-2019)
PROMPT-----
PROMPT-----
PROMPT-----

col metric_unit format a25
col metric_name format a30

alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS';

set linesize 200 trimspool on
set pagesize 100

select 
	end_time
	, inst_id
	, con_id
	, metric_name
	, metric_unit
	, value
from GV$SYSMETRIC_HISTORY
where metric_name like 'Redo%'
order by end_time, inst_id, con_id,  metric_name


select * from V$SYSMETRIC_HISTORY where metric_name = 'Redo Generated Per Sec' order by end_time

/
