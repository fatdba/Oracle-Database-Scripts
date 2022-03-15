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
PROMPT----- Script: sga-details.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Version: V1.0 (Date: 04-02-2014)
PROMPT-----
PROMPT-----
PROMPT-----

col value format 999,999,999,999
col bytes format 999,999,999,999
break on report
compute sum of value on report
compute sum of bytes on report

select * 
from v$sgastat
order by upper(name)
/

select pool, sum(bytes) bytes
from v$sgastat
group by pool
order by pool
/

select * from v$sga
order by name
/
