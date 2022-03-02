col objid	format 99999999 head 'Object Id'
col obj		format a70	head 'Owner.Object : SubObject'
col objid	format 9999999
col cnt		format 9,999,999
col event	format a32

break on event skip 1
select 	 event				event
	,count(*) 			cnt
	,current_obj# 			objid
	,o.owner||'.'||object_name||decode(subobject_name,null,' ',' : ')||subobject_name 	obj
from 	 v$active_session_history h
	,dba_objects o
where 	 event like 'enq:%'
and 	 current_obj# = o.object_id
group by current_obj#
	,o.owner||'.'||object_name||decode(subobject_name,null,' ',' : ')||subobject_name 	
	,event
having count(*) >20
order by event
	,cnt
;
