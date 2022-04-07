undef sid
set linesize 150
set pagesize 2000
accept sid prompt "Enter sid:"
prompt === prev sql ===
select t.*
from 	 v$session s
     	,table(dbms_xplan.display_cursor(s.prev_sql_id, s.prev_child_number)) t
where 	 s.sid=&&sid;
prompt === sql ===
select t.*
from 	 v$session s
     	,table(dbms_xplan.display_cursor(s.sql_id, s.sql_child_number)) t
where 	 s.sid=&&sid
and	 s.sql_id <> s.prev_sql_id;
