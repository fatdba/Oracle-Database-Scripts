--
-- Given a sql_id and child number (cursor still in shared pool), show explain plan 
-- Use xplan_phash.sql to explain old plans from AWR
--
undef sql_id
undef child_num
set linesize 170
set pagesize 2000
select *
from 	 table(dbms_xplan.display_cursor('&&sql_id', &&child_num,'typical +predicate +peeked_binds')) 
--from 	 table(dbms_xplan.display_cursor('&&sql_id', &&child_num,'basic +predicate +peeked_binds')) 
--from 	 table(dbms_xplan.display_cursor('&&sql_id', &&child_num,'basic +iostats +predicate +peeked_binds')) 
;
