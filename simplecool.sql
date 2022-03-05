-- Plan from the Shared Pool
select * from table(dbms_xplan.display_cursor('SQL_ID',null,'ALL'));

-- Plan from the AWR
select * from table(dbms_xplan.display_awr('SQL_ID',null,null,'ALL'));
select * from table(dbms_xplan.display_awr('SQL_ID',null,DBID,'ALL'));


-- kill all sessions executing a bad SQL
select 
     'alter system kill session '''|| s.SID||',' || s.serial# ||''';' 
    from v$session s
where s.sql_id='&SQL_ID';


-- kill all sessions executing a bad SQL but in a RAC environment 
SELECT 'alter system kill session '''|| SID|| ','|| SERIAL#|| ',@'|| inst_id|| ''' immediate ;'
FROM gv$session
WHERE sql_id = '&sql_id'


-- Kill all sessions waiting for specific events by a specific user
select       'alter system kill session '''|| s.SID||',' || s.serial# ||''';' 
from gv$session s
where 1=1 
and (event='latch: shared pool' or event='library cache lock') and s.USERNAME='DBSNMP';



-- generate commands to kill all sessions from a specific user on specific instance
select 'alter system kill session '''|| SID||',' || serial# ||''' immediate;' from gv$session where username='BAD_USER' and inst_id=1;

-- To enable SQL Tracing
alter system set events 'sql_trace [sql:8krc88r46raff]';




-- Get current scn value:
select current_scn from v$database;

-- Get scn value at particular time:
select timestamp_to_scn('19-JAN-08:22:00:10') from dual;

-- Get timestamp from scn:
select scn_to_timestamp(224292)from dual;


set line 200 pages 2000
select * from table(dbms_xplan.display_cursor(format=>'ALLSTATS LAST, ADVANCED, +METRICS'));

set line 200 pages 200
select * from table (Dbms_xplan.display_cursor(format=>'allstats last'));

