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
PROMPT----- Script: cpuusage.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Performance Management and Issue Identification
PROMPT----- Version: V1.1 (Date: 23-7-2018)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~set pages 1000
set lines 1000
col OSPID for a06
col SID for 99999
col SERIAL# for 999999
col SQL_ID for a14
col USERNAME for a15
col PROGRAM for a20
col MODULE for a18
col OSUSER for a10
col MACHINE for a25
select * from (
select ss.inst_id,p.spid "ospid",
(se.SID),ss.serial#,ss.SQL_ID,ss.username,ss.program,ss.module,ss.osuser,ss.MACHINE,ss.status,
se.VALUE/100 cpu_usage_seconds
from
gv$session ss,
gv$sesstat se,
gv$statname sn,
gv$process p
where
se.STATISTIC# = sn.STATISTIC#
and
NAME like '%CPU used by this session%'
and
se.SID = ss.SID
and ss.username !='SYS' and
ss.status='ACTIVE'
and ss.username is not null
and ss.paddr=p.addr and value > 0
order by se.VALUE desc)
where rownum <16;

