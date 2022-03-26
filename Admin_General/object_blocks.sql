@plusenv
undef objname
col blocks	format 99,999,999
col segname	format a40
col pname	format a30	head 'Partition Name'
col stype	format a15	trunc
col tsname	format a25	trunc
break on report
compute sum of mb on report
select 	 sum(blocks)		blocks
	,owner||'.'||segment_name	segname
	,partition_name			pname
	,segment_type		stype
	,tablespace_name	tsname
from 	 dba_extents 	s
where 	 segment_name	= upper('&&objname')
group by owner||'.'||segment_name
	,partition_name
	,segment_type
	,tablespace_name
;
