set lines 170
col statsti 		format a16
col tabname 		format a40	head 'Table Name'
col partition_name 	format a30
col subpart		format a30
select to_char(STATS_UPDATE_TIME,'YYYY/MM/DD HH24:MI') statstime, owner||'.'||table_name tabname, partition_name,subpartition_name subpart
  from dba_tab_stats_history 
  where 	stats_update_time	> sysdate - 1
  and		table_name	like '%table_name'
  order by STATS_UPDATE_TIME; 

select to_char(last_analyzed,'YYYY/MM/DD HH24:MI') lsat_ana, owner||'.'||index_name
from dba_indexes
where table_name like '&table_name'
and last_analyzed > sysdate -1
order by last_analyzed
;
