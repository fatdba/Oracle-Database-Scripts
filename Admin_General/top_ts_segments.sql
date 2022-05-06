@plusenv
undef tsname
undef top_x_rows
col mb		format 99,999,999.9
col segpart	format a70
col segtyp	format a16	trunc
col tablespace_name format a28

select * from
(
select 	 sum(BYTES)/(1024*1024) 	mb
	,owner||'.'||segment_name||decode(partition_name,null,'',' -- ')||partition_name	segpart
	,segment_type										segtyp
	,tablespace_name
from 	 dba_segments 
where	 tablespace_name = upper('&&tsname')
group by owner||'.'||segment_name||decode(partition_name,null,'',' -- ')||partition_name
	,tablespace_name
	,segment_type
order by 1 desc
)
where	 rownum <= &&top_x_rows
;
