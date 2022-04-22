define SRDCNAME='LogSW'
SET MARKUP HTML ON SPOOL ON
COLUMN SRDCSPOOLNAME NOPRINT NEW_VALUE SRDCSPOOLNAME
select 'SRDC_'||upper('&&SRDCNAME')||'_'||upper(instance_name)||'_'|| to_char(sysdate,'YYYYMMDD_HH24MISS') SRDCSPOOLNAME from v$instance;
spool &&SRDCSPOOLNAME..html
set echo on
set pagesize 15;
/* Database identification */
ALTER SESSION SET nls_date_format = 'DD.MM.YYYY HH24:MI:SS';
SELECT NAME, PLATFORM_NAME, DATABASE_ROLE FROM v$database;
SELECT (SELECT startup_time FROM v$instance) startup_time,
(SELECT SYSDATE FROM DUAL) captured_time
FROM DUAL;
SELECT * FROM v$version;
select * from v$instance_recovery;
select OPTIMAL_LOGFILE_SIZE from v$instance_recovery;
SELECT name, VALUE
FROM v$parameter
WHERE name IN
('log_buffer',
'log_checkpoint_interval',
'log_checkpoint_timeout',
'fast_start_mttr_target',
'archive_lag_target')
ORDER BY 1;
select name,LOG_MODE from v$database;
select name from v$controlfile;
SELECT lg.group#, lg.thread#, lg.sequence#, lg.bytes/1024/1024 mb,lg.status, lg.archived, lf.MEMBER FROM v$logfile lf, v$log lg WHERE lg.group# = lf.group# ORDER BY 1, 2;
Select * from DBA_FEATURE_USAGE_STATISTICS ;
select to_char(COMPLETION_TIME,'DD/MON/YYYY') Day,
trunc(sum(blocks*block_size)/1048576/1024,2) "Size(GB)",count(sequence#) "Total Archives"
from
(select distinct sequence#,thread#,COMPLETION_TIME,blocks,block_size from v$archived_log)
group by to_char(COMPLETION_TIME,'DD/MON/YYYY')
order by to_date(to_char(COMPLETION_TIME,'DD/MON/YYYY'),'DD/MON/YYYY');
select * from V$LOG_HISTORY where FIRST_TIME>sysdate-14 order by RECID desc;
SELECT A.*, ROUND (A.Count# * B.AVG# / 1024 / 1024 / 1024) Daily_Avg_GB
FROM ( SELECT TO_CHAR (First_Time, 'YYYY-MM-DD') DAY,
COUNT (1) Count#,
MIN (RECID) Min#,
MAX (RECID) Max#
FROM v$log_history
GROUP BY TO_CHAR (First_Time, 'YYYY-MM-DD')
ORDER BY 1 DESC) A,
(SELECT AVG (BYTES) AVG#,
COUNT (1) Count#,
MAX (BYTES) Max_Bytes,
MIN (BYTES) Min_Bytes
FROM v$log) B;
select to_char(FIRST_TIME,'DY, DD-MON-YYYY') day,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'00',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'00',1,0))) d_0,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'01',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'01',1,0))) d_1,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'02',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'02',1,0))) d_2,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'03',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'03',1,0))) d_3,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'04',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'04',1,0))) d_4,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'05',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'05',1,0))) d_5,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'06',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'06',1,0))) d_6,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'07',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'07',1,0))) d_7,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'08',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'08',1,0))) d_8,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'09',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'09',1,0))) d_9,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'10',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'10',1,0))) d10,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'11',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'11',1,0))) d11,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'12',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'12',1,0))) d12,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'13',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'13',1,0))) d13,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'14',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'14',1,0))) d14,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'15',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'15',1,0))) d15,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'16',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'16',1,0))) d16,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'17',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'17',1,0))) d17,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'18',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'18',1,0))) d18,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'19',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'19',1,0))) d19,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'20',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'20',1,0))) d20,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'21',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'21',1,0))) d21,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'22',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'22',1,0))) d22,
decode(sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'23',1,0)),0,'-',sum(decode(substr(to_char(FIRST_TIME,'HH24'),1,2),'23',1,0))) d23,
count(trunc(FIRST_TIME)) "Total"
from v$log_history
group by to_char(FIRST_TIME,'DY, DD-MON-YYYY')
order by to_date(substr(to_char(FIRST_TIME,'DY, DD-MON-YYYY'),5,15) );
spool off
set markup html off spool off
