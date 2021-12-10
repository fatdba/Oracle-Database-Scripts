-- Not my script but this is good when you want to see archivelog generation per hour
-- Really good one
set linesize 140
set feedback off
set timing off
set pagesize 1000
col ARCHIVED format a8
col ins    format 99  heading "DB"
col member format a80
col status format a12
col archive_date format a20
col member format a60
col type   format a10
col group#  format 99999999
col min_archive_interval format a20
col max_archive_interval format a20
col h00 heading "H00" format  a3 
col h01 heading "H01" format  a3 
col h02 heading "H02" format  a3 
col h03 heading "H03" format  a3 
col h04 heading "H04" format  a3 
col h05 heading "H05" format  a3 
col h06 heading "H06" format  a3 
col h07 heading "H07" format  a3 
col h08 heading "H08" format  a3 
col h09 heading "H09" format  a3 
col h10 heading "H10" format  a3 
col h11 heading "H11" format  a3 
col h12 heading "H12" format  a3 
col h13 heading "H13" format  a3 
col h14 heading "H14" format  a3 
col h15 heading "H15" format  a3 
col h16 heading "H16" format  a3 
col h17 heading "H17" format  a3 
col h18 heading "H18" format  a3 
col h19 heading "H19" format  a3 
col h20 heading "H20" format  a3 
col h21 heading "H21" format  a3 
col h22 heading "H22" format  a3 
col h23 heading "H23" format  a3 
col total format a6
col date format a10

select * from v$logfile order by group#;
select * from v$log order by SEQUENCE#;

select max( sequence#) last_sequence, max(completion_time) completion_time, max(block_size) block_size from v$archived_log ;

SELECT instance ins,
       log_date "DATE" ,
       lpad(to_char(NVL( COUNT( * ) , 0 )),6,' ') Total,
       lpad(to_char(NVL( SUM( decode( log_hour , '00' , 1 ) ) , 0 )),3,' ') h00 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '01' , 1 ) ) , 0 )),3,' ') h01 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '02' , 1 ) ) , 0 )),3,' ') h02 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '03' , 1 ) ) , 0 )),3,' ') h03 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '04' , 1 ) ) , 0 )),3,' ') h04 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '05' , 1 ) ) , 0 )),3,' ') h05 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '06' , 1 ) ) , 0 )),3,' ') h06 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '07' , 1 ) ) , 0 )),3,' ') h07 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '08' , 1 ) ) , 0 )),3,' ') h08 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '09' , 1 ) ) , 0 )),3,' ') h09 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '10' , 1 ) ) , 0 )),3,' ') h10 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '11' , 1 ) ) , 0 )),3,' ') h11 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '12' , 1 ) ) , 0 )),3,' ') h12 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '13' , 1 ) ) , 0 )),3,' ') h13 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '14' , 1 ) ) , 0 )),3,' ') h14 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '15' , 1 ) ) , 0 )),3,' ') h15 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '16' , 1 ) ) , 0 )),3,' ') h16 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '17' , 1 ) ) , 0 )),3,' ') h17 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '18' , 1 ) ) , 0 )),3,' ') h18 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '19' , 1 ) ) , 0 )),3,' ') h19 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '20' , 1 ) ) , 0 )),3,' ') h20 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '21' , 1 ) ) , 0 )),3,' ') h21 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '22' , 1 ) ) , 0 )),3,' ') h22 ,
       lpad(to_char(NVL( SUM( decode( log_hour , '23' , 1 ) ) , 0 )),3,' ') h23  
FROM   (
        SELECT thread# INSTANCE ,
               TO_CHAR( first_time , 'YYYY-MM-DD' ) log_date ,
               TO_CHAR( first_time , 'hh24' ) log_hour 
        FROM   v$log_history 
       ) 
GROUP  BY 
       instance,log_date
ORDER  BY 
       log_date ; 
       
select trunc(min(completion_time - first_time))||'  Day  '||
       to_char(trunc(sysdate,'dd') + min(completion_time - first_time),'hh24:mm:ss')||chr(10) min_archive_interval, 
       trunc(max(completion_time - first_time))||'  Day  '||
       to_char(trunc(sysdate,'dd') + max(completion_time - first_time),'hh24:mm:ss')||chr(10) max_archive_interval
from gv$archived_log 
where sequence# <> ( select max(sequence#) from gv$archived_log ) ;

set feedback on
set timing on
