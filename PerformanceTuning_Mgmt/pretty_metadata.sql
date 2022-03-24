set long 100000
set linesi 500
column ddl for a200
set pagesi 0
set feed off
exec DBMS_METADATA.SET_TRANSFORM_PARAM (DBMS_METADATA.SESSION_TRANSFORM, 'PRETTY', true);
exec   dbms_metadata.set_transform_param ( DBMS_METADATA.SESSION_TRANSFORM, 'CONSTRAINTS_AS_ALTER', true);
exec   dbms_metadata.set_transform_param ( DBMS_METADATA.SESSION_TRANSFORM, 'STORAGE', false );
exec   dbms_metadata.set_transform_param ( DBMS_METADATA.SESSION_TRANSFORM, 'SQLTERMINATOR', TRUE );
select dbms_metadata.get_ddl(upper('&object_type'),upper('&Object_name'),nvl(upper('&Owner'),NULL)) as ddl from dual;
set feed on
