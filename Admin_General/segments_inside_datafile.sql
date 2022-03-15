--
--  Show detailed information for all segments inside a given datafile
--
@plusenv
undef fname

accept   fname  prompt 'Enter Datafile Name: '

Prompt Database Segments in File &fname 
 
col stype format a15 heading 'Segment Type' 
col sname format a40 heading 'Segment Name' 
col pname format a30 heading 'Partition Name' 
col segsize  format 99,999.99  heading 'Size (Mbytes)'
 
select 
  segment_type			stype, 
  owner||'.'||segment_name	sname,
  partition_name		pname,
  sum(ext.bytes/1024/1024)      segsize 
from 
  dba_extents			ext, 
  dba_data_files		fil 
where 
  fil.file_name = '&fname' 
 and 
  ext.file_id = fil.file_id 
group by 
  segment_type, 
  owner,
  segment_name,
  partition_name
/ 
 
