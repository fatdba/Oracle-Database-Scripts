@plusenv
undef obj_id

col obj		format a40	head 'Owner.ObjectName'
col objid	format 9999999
col dobjid	format 9999999
col timestamp	format a19
col created	format a11
col last_ddl	format a11
col g		format a1
col bp		format a1
col mb		format 99999
SELECT 	/*+ RULE */
	 o.owner||'.'||object_name			obj
	,object_id					objid
	,data_object_id					dobjid
	,object_type
	,s.bytes/(1024*1024)				mb
	,substr(s.buffer_pool,1,1)			bp
	,status
	,generated					g
	,timestamp
	,to_char(created,'YYMMDD-HH24MI') 		created
	,to_char(last_ddl_time,'YYMMDD-HH24MI') 	last_ddl
FROM 	 dba_segments	s
	,dba_objects	o
WHERE 	 o.object_id 	= &&obj_id
AND	 o.owner	= s.owner (+)
AND	 o.object_name	= s.segment_name (+)
ORDER BY object_name
	,object_type
;
undef obj_name
