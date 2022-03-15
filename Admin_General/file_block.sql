undef file_id
undef block_id
undef tsname

col ts_name new_value tsname

select 	 ts.name ts_name
from 	 v$tablespace ts
	,v$datafile df
where	 file#	= &&file_id
and	 ts.ts#	= df.ts#
;

set termout on
set heading off
col a	format a77 	fold_after

select 	 'File number   : '||&&file_id	a
	,'Block number  : '||&&block_id a
	,'Owner         : '||owner a
	,'segment name  : '||segment_name a
	,'Segment type  : '||segment_type a
	,'Partition name: '||partition_name a
	,'Tablespace    : '||e.tablespace_name a
	,'File name     : '||f.file_name a
from	 dba_extents e
	,dba_data_files f
where	 e.file_id	= f.file_id
and	 e.file_id	= &&file_id
and	 e.block_id	<= &&block_id
and	 e.block_id + e.blocks	> &&block_id
and	 e.tablespace_name = '&&tsname'
;
