undef sql_id
set linesize 80
set pagesize 9000

@sqlid_info

prompt	========== from awr ==========
select 	 t.*
from
	(select distinct sql_id, plan_hash_value from v$sql_plan where sql_id = '&&sql_id') s
	,table(dbms_xplan.display_awr(s.sql_id,null,null,'basic +predicate +peeked_binds')) t
;

