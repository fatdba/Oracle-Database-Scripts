clear breaks
set linesi 200
col segment_name format a37 heading "segment_name"
col partition_name format a19
col segment_type format a10 trunc
col  free format 99999
col  total format 99999
col  used format 99999
col  to_resiz format 99999
col  gain format 99999
col owner format a10
col name format a56
set head on
set feedback off
set pagesi 200
with ae as
(
select  /*+ MATERIALIZE */ owner,segment_name,tablespace_name,segment_type,partition_name,file_id,blocks,block_id from dba_extents where tablespace_name=upper('&&tablespace_name')
),
a as
(
select d.file# file_id,d.name,d.bytes/(1024*1024) total,round(nvl(t_used,4)) used,round(bytes/(1024*1024)-nvl(t_used,4)) free,ceil(nvl(t_max_block_blocks*8192/(1024*1024),5)) to_resiz, bytes/(1024*1024)-ceil(nvl(t_max_block_blocks*8192/(1024*1024),5)) gain,nvl(t_max_block_id,0) t_max_block_id from v$datafile_header d,( select file_id,sum(blocks*8192)/(1024*1024) t_used,max(block_id) t_max_block_id ,max(block_id+blocks-1) t_max_block_blocks from ae group by file_id)  t where t.file_id(+)=d.file# and d.tablespace_name=upper('&tablespace_name') order by gain
)
select a.file_id||':'||a.name name,a.total,a.used,a.free,a.to_resiz,a.gain,owner||(case when segment_name is null then '' else '.' end)||segment_name segment_name,segment_type,partition_name from ae e,a where a.file_id=e.file_id(+) and e.block_id(+)=a.t_max_block_id ;
prompt
undef tablespace_name
