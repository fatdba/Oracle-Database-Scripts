col 	objn 		format a30
col 	sname 		format a30
col 	otype 		format a10	trunc
col 	obj 		format a40
col 	tbs 		format a25
col	cnt		format 9999
col	p1		format 999999999999
col	p2		format 9999
col	p3		format 999999
col	fno		format 9999
col	blkno		format 9999999

break on obj on otype skip 1
select	 o.owner||'.'||nvl(object_name,CURRENT_OBJ#) 	obj
       	,o.object_type 					otype
       	,o.subobject_name 				sname
	,ash.current_file#				fno
	,ash.current_block#				blkno
	,count(*)					cnt
       	,ash.SQL_ID 					sql_id
       	,ash.p1 					p1
       	,ash.p2 					p2
from 	 v$active_session_history 	ash
        ,all_objects 			o
where 	 event			='latch: cache buffers chains'
and 	 o.object_id (+)	= ash.CURRENT_OBJ#
and 	 ash.session_state	='WAITING'
and 	 ash.sample_time 	> sysdate - &&last_x_mins/(60*24)
group by o.owner
	,o.object_name
	,ash.current_obj#
	,o.object_type
	,o.subobject_name
	,ash.current_file#
	,ash.current_block#
	,ash.sql_id
	,ash.p1
	,ash.p2
order by 2,1
;
