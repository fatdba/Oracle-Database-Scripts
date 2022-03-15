Setting Publish preference

exec dbms_stats.set_table_prefs('SCOTT','EMP','PUBLISH','FALSE');

Check the publish preference status

select dbms_stats.get_prefs('PUBLISH', 'SCOTT','EMP') FROM DUAL;

Similarly for schema also use as below:

select dbms_stats.get_prefs('PUBLISH', 'SCOTT') from dual

exec dbms_stats.SET_SCHEMA_PREFS('DBATEST','PUBLISH','FALSE');

--- FOR INDEX

SET_INDEX_STATS
GET_INDEX_STATS

-- FOR DATABASE

SET_DATABASE_PREFS
