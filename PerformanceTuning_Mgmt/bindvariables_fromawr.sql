PROMPT
PROMPT
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT------                 /)  (\
PROMPT------            .-._((,~~.))_.-,
PROMPT------             `-.   @@   ,-'
PROMPT------               / ,o--o. \
PROMPT------              ( ( .__. ) )
PROMPT------               ) `----' (
PROMPT------              /          \
PROMPT------             /            \
PROMPT------            /              \
PROMPT------    "The Silly Cow"
PROMPT----- Script: bindvariables_fromawr.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Version: V1.4 (Date: 08-011-2016)
PROMPT-----
PROMPT-----
PROMPT-----
col username format a15
col sid format 9999

col instance_number format 999 head 'INST'
col begin_interval_time format a28
col datatype_string format a15 head 'DATA TYPE'
col child_nume format 999999 head 'CHILD|NUMBER'
col position format 999 head 'POS'
col name format a20
col value_string format a40
col bind_string format a40
col type_name format a15
col begin_interval_time format a22

set line 200 trimspool on
set pagesize 60

col u_sql_id new_value u_sql_id noprint

set term on feed on echo off pause off verify off
prompt Which SQL_ID? :

set term off feed off
select '&1' u_sql_id from dual;
set term on feed on

var v_sql_id varchar2(30)
exec :v_sql_id := '&u_sql_id'

clear break

break on begin_interval_time on instance_number	 


select
	to_char(s.begin_interval_time,'yyyy-mm-dd hh24:mi:ss') begin_interval_time
	, b.instance_number
	, b.position
	, b.name
	, b.value_string
	, anydata.GETTYPENAME(b.value_anydata) type_name
	-- use the anydata values as they are sometimes more reliable dependent on oracle version
	, case anydata.GETTYPENAME(b.value_anydata) 
		when 'SYS.VARCHAR' then	 anydata.accessvarchar(b.value_anydata)
		when 'SYS.VARCHAR2' then anydata.accessvarchar2(b.value_anydata)
		when 'SYS.CHAR' then anydata.accesschar(b.value_anydata)
		when 'SYS.DATE' then to_char(anydata.accessdate(b.value_anydata),'yyyy-mm-dd hh24:mi:ss')
		when 'SYS.TIMESTAMP' then to_char(anydata.accesstimestamp(b.value_anydata),'yyyy-mm-dd hh24:mi:ss')
		when 'SYS.NUMBER' then to_char(anydata.accessnumber(b.value_anydata))
	end bind_string
from dba_hist_sqlbind  b
join dba_hist_snapshot s on s.instance_number = b.instance_number
	and s.dbid = b.dbid
	and b.snap_id = s.snap_id
where b.sql_id = :v_sql_id
order by s.begin_interval_time, b.instance_number, b.position
/
