--
-- Author: Prashant 'The FatDBA' Dixit
--

clear breaks
set linesi 190
col segment_name format a30
col partition_name format a30
col start format 999999.9999
col end format 999999.9999
col name format a60
set head on
set feedback off
set pagesi 200
accept file_id prompt "Enter file_id :"
accept rows prompt "No of objects at EOF to print [20] :"
prompt
prompt =====================================================================================
prompt "File name and size :"
prompt =====================================================================================
prompt
with t as ( select file_id,sum(blocks*8192)/(1024*1024) t_used,max(block_id+blocks-1) t_max_block from dba_extents where file_id=&file_id group by file_id)
(
select name,bytes/(1024*1024) total_size,t_used used_size,bytes/(1024*1024)-t_used free_size,ceil(t_max_block*8192/(1024*1024)) resizable_to, bytes/(1024*1024)-ceil(t_max_block*8192/(1024*1024)) reclaimable_size from v$datafile d,t where d.file#=&file_id and t.file_id=d.file#
);
prompt
prompt ==================================================================================================================
prompt "Last 20 objects at the end of datafile :"
prompt ==================================================================================================================
prompt
select * from (select owner,SEGMENT_NAME,PARTITION_NAME,SEGMENT_TYPE,round((BLOCK_ID*8192)/(1024*1024)) start_size,round((BLOCK_ID+blocks-1)*8192/(1024*1024)) end_size from dba_extents where file_id=&file_id order by block_id desc) where rownum<=nvl('&rows',20) order by 5;
undef file_id
prompt 
