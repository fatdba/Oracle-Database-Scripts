undef object_name
set linesize 150 feed on
set pagesize 2000
accept object_name prompt "Enter object_name:"
col sql_id	format a13		head 'SQL Id'
col cn		format 99
col module 	format a26	trunc
col sqltext 	format a70	trunc
col phash	format 9999999999	head 'Plan Hash'
col execs	format 9999999999
col opt_mode	format a06	trunc	head 'Opt|Mode'


select   s.sql_id					sql_id
	,s.child_number					cn
	,s.plan_hash_value				phash
	,optimizer_mode					opt_mode
	,s.executions					execs
	,module
	,substr(replace(sql_text,chr(13)),1,70)		sqltext
from     v$sql          s
        ,(select distinct sql_id, plan_hash_value from v$sql_plan where object_name=upper('&&object_name')) p
where    s.sql_id               = p.sql_id
and      s.plan_hash_value      = p.plan_hash_value
and      s.last_active_time     > sysdate-8
order by s.executions desc
;

prompt	 =============== from awr ===============
select 	 t.*
from     (select distinct sql_id, plan_hash_value from dba_hist_sql_plan where object_name=upper('&&object_name') and timestamp > sysdate-8) p
	,table(dbms_xplan.display_awr(p.sql_id,p.plan_hash_value,null,'basic +predicate +peeked_binds')) t
;

