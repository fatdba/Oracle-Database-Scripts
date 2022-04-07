undef sql_hash
set linesize 150
set pagesize 2000
select t.*
from 	 v$sql s
     	,table(dbms_xplan.display_cursor(s.sql_id, s.child_number)) t
where 	 s.hash_value=&&sql_hash;
