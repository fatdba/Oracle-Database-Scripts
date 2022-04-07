undef sql_id
set linesize 150
set pagesize 2000
accept sql_id prompt 'Enter sql_id: '
accept plan_hash prompt 'Enter Plan Hash: '
select * from table(dbms_xplan.display_awr('&&sql_id',&&plan_hash,null,'typical +predicate +peeked_binds'));
