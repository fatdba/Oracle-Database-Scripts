accept sql_id 		prompt 'Enter sql_id : '
accept plan_hash 	prompt 'Enter plan_hash : '
set linesize 170
set pagesize 2000
prompt === from cursor cache ===
select t.*
from 	 (select distinct sql_id, plan_hash_value , max(child_number) child_number 
	  from v$sql 
	  where sql_id ='&&sql_id' 
	  and plan_hash_value=&&plan_hash 
	  group by sql_id, plan_hash_value) s
     	,table(dbms_xplan.display_cursor(s.sql_id, s.child_number)) t
;
prompt === from awr ===
select t.*
from 	 (select distinct sql_id, plan_hash_value 
	  from dba_hist_sqlstat 
	  where sql_id ='&&sql_id'
	  and plan_hash_value=&&plan_hash) s
     	,table(dbms_xplan.display_awr(s.sql_id,s.plan_hash_value)) t
;
