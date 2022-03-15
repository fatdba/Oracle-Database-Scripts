set pages 80
set lin 120
set echo off
set feed off
column PCT format 999.99
column tbspce format A30
col container for a30
select substr(f.tablespace_name,1,30) tbspce,
     round(f.tsbytes/(1024*1024),0) "ALLOCATED(MB)",
     round(nvl(s.segbytes,0)/(1024*1024),0) "USED(MB)",
     round((nvl(s.segbytes,0)/f.tsbytes)*100,2) PCT,
     lower(vc.name) as container
from
   (select con_id,tablespace_name,sum(bytes) tsbytes from cdb_data_files group by con_id,tablespace_name) f,
   (select con_id,tablespace_name,sum(bytes) segbytes from cdb_segments group by con_id,tablespace_name) s,
   v$containers vc
where f.con_id=s.con_id(+)
  and f.tablespace_name=s.tablespace_name(+)
  and f.con_id=vc.con_id
order by container, tbspce;
