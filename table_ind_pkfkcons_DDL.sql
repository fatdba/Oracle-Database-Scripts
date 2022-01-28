col v_owner new_value v_owner noprint
col v_table_name new_value v_table_name noprint

prompt
prompt Table Owner:
prompt

set feed off term off
select upper('&1') v_owner from dual;
set feed on term on

prompt
prompt Table Name:
prompt

set feed off term off
select upper('&2') v_table_name from dual;
set feed on term on

-- use binds to avoid stressing shared pool and hard parsing
var v_owner varchar2(30)
var v_table_name varchar2(30)

begin
	:v_owner := '&&v_owner';
	:v_table_name := '&&v_table_name';
end;
/


set pagesize 50000
set linesize 200 trimspool on
col ddl format a200
set long 2000000

col mydb noprint new_value mydb
set term off
select lower(name) mydb from v$database;
set term on

define sqlfile=_gen_tab_&&mydb

-- dbms_metadata setup
begin
	dbms_metadata.set_transform_param(dbms_metadata.session_transform,'PRETTY',TRUE);
	dbms_metadata.set_transform_param(dbms_metadata.session_transform,'SQLTERMINATOR',TRUE);
	dbms_metadata.set_transform_param(dbms_metadata.session_transform,'SEGMENT_ATTRIBUTES',TRUE);
	dbms_metadata.set_transform_param(dbms_metadata.session_transform,'STORAGE', TRUE);
	dbms_metadata.set_transform_param(dbms_metadata.session_transform,'TABLESPACE',TRUE);
	dbms_metadata.set_transform_param(dbms_metadata.session_transform,'SPECIFICATION',TRUE);
	dbms_metadata.set_transform_param(dbms_metadata.session_transform,'BODY',TRUE);
	dbms_metadata.set_transform_param(dbms_metadata.session_transform,'CONSTRAINTS',TRUE);
end;
/


col ddl format a200

spool &&sqlfile..sql

prompt set echo on
prompt spool &&sqlfile..log

-- dbms_metadata here

prompt --########################################
prompt --## TABLE DDL
prompt --########################################

select replace(dbms_metadata.get_ddl('TABLE',:v_table_name,:v_owner),'"','') ddl from dual
/

prompt --########################################
prompt --## INDEX DDL
prompt --########################################

select replace(dbms_metadata.get_ddl('INDEX',i.index_name, i.owner),'"','') ddl
from dba_indexes i
where i.owner = :v_owner
and i.table_name = :v_table_name
/

prompt --########################################
prompt --## PRIMARY KEY
prompt --########################################

select replace(dbms_metadata.get_ddl('CONSTRAINT',c.constraint_name, c.owner),'"','') ddl
from dba_constraints c
where c.owner = :v_owner
and c.table_name = :v_table_name
and c.constraint_type = 'P'
/

prompt --########################################
prompt --## FOREIGN KEYS
prompt --########################################

select replace(dbms_metadata.get_ddl('REF_CONSTRAINT',c.constraint_name, c.owner),'"','') ddl
from dba_constraints c
where c.owner = :v_owner
and c.table_name = :v_table_name
and c.constraint_type = 'R'
/

prompt --########################################
prompt --## CHECK CONSTRAINTS
prompt --########################################

select replace(dbms_metadata.get_ddl('CONSTRAINT',c.constraint_name, c.owner),'"','') ddl
from dba_constraints c
where c.owner = :v_owner
and c.table_name = :v_table_name
and c.constraint_type = 'C'
and c.generated not like 'GENERATED%'
/


prompt spool off
prompt set echo off

spool off
