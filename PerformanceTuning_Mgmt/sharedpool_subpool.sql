select KSMCHIDX "SubPool", sum(ksmchsiz) Bytes  
       from x$ksmsp  
      group by ksmchidx;
      


--how many subpools 
select count(distinct kghluidx) num_subpools from x$kghlu  where kghlushrpool   = 1;

--_kghdsidx_count parameter can be used to force the number of subpools you want :
col NAME for a30
col value for a30
col default1 for a20
select a.ksppinm name, b.ksppstvl value, b.ksppstdf default1
from x$ksppi a, x$ksppcv b
where a.indx = b.indx
and a.ksppinm like '%_kghdsidx_count%'
order by name ;

--distribution of latches for shared pool
select child#, gets  from v$latch_children where name = 'shared pool' order by child#;
 
--Subpool 0 is the system created memory repository used for its new dynamic memory distribution algorithm.
--free memory in sub pools  
select  KSMDSIDX,KSMSSLEN,KSMSSNAM  from x$ksmss where  KSMSSNAM ='free memory';

	  
--Db_block_buffers_headers consumed  memory in shared pool - if using db_block_buffers
select name,bytes from v$sgastat where pool='shared pool' and name like '%db_block_buffers_headers%';

