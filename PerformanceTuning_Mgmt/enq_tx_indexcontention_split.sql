--
-- showing index contention due to splits for last_x_days
-- note that not all splits will trigger index contention; only the hot indexes (many concurrent transactions) will see contention 
--

col cnt		format 999999
col objid	format 99999999
col event	format a32	trunc
col oname	format a64	trunc

break on event on objid on oname on sqlid skip 1
select 	 * from
(
select	 event					event
        ,CURRENT_OBJ#				objid
        ,owner||'.'||object_name||decode(subobject_name,null,' ',' : ')||subobject_name	oname
	,SQL_ID					sqlid
       	,to_char(sample_time,'YY/MM/DD')	stime
	,count(*)				cnt
from 	 DBA_HIST_ACTIVE_SESS_HISTORY
	,dba_objects o
where	 event		= 'enq: TX - index contention'
and	 sample_time 	>= sysdate - &&last_x_days
and	 CURRENT_OBJ# = o.OBJECT_ID
group by to_char(sample_time,'YY/MM/DD')
	,CURRENT_OBJ#
        ,owner||'.'||object_name||decode(subobject_name,null,' ',' : ')||subobject_name
	,SQL_ID
	,event
having	 count (*)	>=1
order by count (*) desc
)
where	 rownum	<= 50
order by oname
	,sqlid
	,stime
;
