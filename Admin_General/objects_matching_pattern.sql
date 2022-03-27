REM ------------------------------------------------------------------------------------------------
REM $Id: objs.sql,v 1.1 2002/03/14 19:59:56 hien Exp $
REM #DESC      : Show objects matching a given name pattern
REM Usage      : Input parameter: obj_pattern
REM Description: For tables/indexes, show segment size and buffer pool assignment
REM ------------------------------------------------------------------------------------------------

@plusenv

col oname	format a39	head 'Owner.ObjectName'
col subobj	format a30
col objid	format 9999999
col dobjid	format 9999999
col otype	format a10	head 'Object|Type'	trunc
col times	format a12	head 'Timestamp'
col created	format a11
col last_ddl	format a11
col g		format a1
col bp		format a1
col mb		format 99999
col sta		format a01	head 'S'	trunc

SELECT 	/*+ RULE */
	 o.owner||'.'||object_name			oname
	,object_id					objid
	,data_object_id					dobjid
	,object_type					otype
	,subobject_name					sobj
	,s.bytes/(1024*1024)				mb
	,substr(s.buffer_pool,1,1)			bp
	,status						sta
	,generated					g
	,to_char(to_date(timestamp,'YYYY-MM-DD:HH24:MI:SS'),'YYMMDD HH24:MI')		times
	,to_char(created,'YYMMDD-HH24MI') 		created
	,to_char(last_ddl_time,'YYMMDD-HH24MI') 	last_ddl
FROM 	 dba_segments	s
	,dba_objects	o
WHERE 	 object_name 	like upper('%&obj_pattern%')
AND	 o.owner		= s.owner (+)
AND	 o.object_name		= s.segment_name (+)
and	 o.subobject_name	=s.partition_name (+)
ORDER BY o.owner
	,o.object_name
	,o.object_type
	,o.subobject_name
;
undef obj_pattern
ttitle off
