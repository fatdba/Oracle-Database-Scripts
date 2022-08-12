-- By Prashant 'The FatDBA' Dixit
set linesize 400 pagesize 400
select inst_id,process, status, thread#, sequence#, block#, blocks from gv$managed_standby where process='MRP0';
select a.thread#, (select max (sequence#) from v$archived_log where archived='YES' and thread#=a.thread#) archived,max(a.sequence#) applied, (select max(sequence#) from v$archived_log where archived='YES' and thread#=a.thread#)-max(a.sequence#)gap
from v$archived_log a where a.applied='YES' group by a.thread# order by thread#;
