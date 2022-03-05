col child_number	format 999 heading 'CN'
col sql_id		format a13
col operation		format a30
col mb			format 99999.9
col object		format a40
col card		format 999999999
col latime		format a11		head 'Last ActvTime'
col execs		format 999999999
col bgpx                format 99999            head 'BGets|PerX'
col phash		format 99999999999

select	* from
(
SELECT	 distinct sp.sql_id
	,sp.plan_hash_value	phash
	,to_char(s.last_active_time,'MMDD HH24MISS')    latime
	,s.executions		execs
	,least((buffer_gets/executions),99999)                  bgpx
	,sp.bytes/(1024*1024)	mb
	,object_owner||'.'||object_name		object
	,operation||' '||options operation
FROM	 v$sql_plan		sp
	,v$sql			s
WHERE	 options like '%SAMPLE%' 
and	 sp.sql_id		= s.sql_id
and	 sp.plan_hash_value	= s.plan_hash_value
AND	 object_owner not in ('SYS','SYSTEM')
AND	 object_name not like 'SYS_%'
and	 s.executions		> 10
and	 s.object_status	= 'VALID'
and	 s.last_active_time	> sysdate-30
ORDER BY executions desc
)
where	 rownum < 301
;
