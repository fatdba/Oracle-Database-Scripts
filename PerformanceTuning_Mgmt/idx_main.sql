set lin 190
col owner for a8
set pagesi 0
col segment_name for a30 head "INDEX_NAME"
col TABLESPACE_NAME for a20
col index_type for a10
col siz for 9999999
col column_name for a28
set verify off
column col_pos for 9999999
undef owner_name
undef tab_name
break on owner on segment_name on uniqueness on partitioned on index_type on status on tablespace_name on tot_size_mb 
set head on
select a.OWNER ,SEGMENT_NAME,b.uniqueness,b.partitioned,b.index_type,b.status,TABLESPACE_NAME,sum(BYTES/1024/1024) tot_size_mb,c.column_name ,c.column_position col_pos,b.last_analyzed,decode(VISIBILITY,'VISIBLE','V','INVISIBLE','I') v
  from dba_segments a, (select owner,index_name,index_type,status,last_analyzed,uniqueness,partitioned,VISIBILITY from dba_indexes where table_name=upper('&&tab_name') and table_owner=upper('&OWNER')) b,dba_ind_columns c 
   where segment_name = b.index_name and a.owner=b.owner and b.index_name=c.index_name and b.owner=c.index_owner group by a.OWNER ,SEGMENT_NAME,b.uniqueness,b.partitioned,b.index_type,b.status,TABLESPACE_NAME,c.column_name ,c.column_position,b.last_analyzed,VISIBILITY order by b.partitioned,a.segment_name,col_pos asc;

undef owner_name
undef tab_name
