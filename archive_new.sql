set linesize 200 pagesize 1000
column day format a3
column total format 9999
column h00 format 999
column h01 format 999
column h02 format 999
column h03 format 999
column h04 format 999
column h04 format 999
column h05 format 999
column h06 format 999
column h07 format 999
column h08 format 999
column h09 format 999
column h10 format 999
column h11 format 999
column h12 format 999
column h13 format 999
column h14 format 999
column h15 format 999
column h16 format 999
column h17 format 999
column h18 format 999
column h19 format 999
column h20 format 999
column h21 format 999
column h22 format 999
column h23 format 999
column h24 format 999
break on report
compute max of "total" on report
compute max of "h00" on report
compute max of "h01" on report
compute max of "h02" on report
compute max of "h03" on report
compute max of "h04" on report
compute max of "h05" on report
compute max of "h06" on report
compute max of "h07" on report
compute max of "h08" on report
compute max of "h09" on report
compute max of "h10" on report
compute max of "h11" on report
compute max of "h12" on report
compute max of "h13" on report
compute max of "h14" on report
compute max of "h15" on report
compute max of "h16" on report
compute max of "h17" on report
compute max of "h18" on report
compute max of "h19" on report
compute max of "h20" on report
compute max of "h21" on report
compute max of "h22" on report
compute max of "h23" on report
compute sum of NUM on report
compute sum of GB on report
compute sum of MB on report
compute sum of KB on report

REM Script to Report the Redo Log Switch History

alter session set nls_date_format='DD MON YYYY';
select thread#, trunc(completion_time) as "date", to_char(completion_time,'Dy') as "Day", count(1) as "total",
sum(decode(to_char(completion_time,'HH24'),'00',1,0)) as "h00",
sum(decode(to_char(completion_time,'HH24'),'01',1,0)) as "h01",
sum(decode(to_char(completion_time,'HH24'),'02',1,0)) as "h02",
sum(decode(to_char(completion_time,'HH24'),'03',1,0)) as "h03",
sum(decode(to_char(completion_time,'HH24'),'04',1,0)) as "h04",
sum(decode(to_char(completion_time,'HH24'),'05',1,0)) as "h05",
sum(decode(to_char(completion_time,'HH24'),'06',1,0)) as "h06",
sum(decode(to_char(completion_time,'HH24'),'07',1,0)) as "h07",
sum(decode(to_char(completion_time,'HH24'),'08',1,0)) as "h08",
sum(decode(to_char(completion_time,'HH24'),'09',1,0)) as "h09",
sum(decode(to_char(completion_time,'HH24'),'10',1,0)) as "h10",
sum(decode(to_char(completion_time,'HH24'),'11',1,0)) as "h11",
sum(decode(to_char(completion_time,'HH24'),'12',1,0)) as "h12",
sum(decode(to_char(completion_time,'HH24'),'13',1,0)) as "h13",
sum(decode(to_char(completion_time,'HH24'),'14',1,0)) as "h14",
sum(decode(to_char(completion_time,'HH24'),'15',1,0)) as "h15",
sum(decode(to_char(completion_time,'HH24'),'16',1,0)) as "h16",
sum(decode(to_char(completion_time,'HH24'),'17',1,0)) as "h17",
sum(decode(to_char(completion_time,'HH24'),'18',1,0)) as "h18",
sum(decode(to_char(completion_time,'HH24'),'19',1,0)) as "h19",
sum(decode(to_char(completion_time,'HH24'),'20',1,0)) as "h20",
sum(decode(to_char(completion_time,'HH24'),'21',1,0)) as "h21",
sum(decode(to_char(completion_time,'HH24'),'22',1,0)) as "h22",
sum(decode(to_char(completion_time,'HH24'),'23',1,0)) as "h23"
from
v$archived_log
where first_time > trunc(sysdate-10)
and dest_id = (select dest_id from V$ARCHIVE_DEST_STATUS where status='VALID' and type='LOCAL')
group by thread#, trunc(completion_time), to_char(completion_time, 'Dy') order by 2,1;

REM Script to calculate the archive log size generated per day for each Instances.

select THREAD#, trunc(completion_time) as "DATE"
, count(1) num
, trunc(sum(blocks*block_size)/1024/1024/1024) as GB
, trunc(sum(blocks*block_size)/1024/1024) as MB
, sum(blocks*block_size)/1024 as KB
from v$archived_log
where first_time > trunc(sysdate-10)
and dest_id = (select dest_id from V$ARCHIVE_DEST_STATUS where status='VALID' and type='LOCAL')
group by thread#, trunc(completion_time)
order by 2,1
;
