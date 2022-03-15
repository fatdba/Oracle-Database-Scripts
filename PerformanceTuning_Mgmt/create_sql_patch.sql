----------------------------------------------------------------------------------------
--
-- File name:   create_sql_patch.sql
--
-- Purpose:     Prompts for a hint and makes a SQL Patch out of it.
-

--
-- Usage:       This scripts prompts for five values.
--
--              sql_id: the sql_id of the statement to attach the patch to 
--                      (the statement must be in the shared pool)
--
--              patch_name: the name of the patch to be created 
--
--              category: the category to assign to the new patch 
--
--              hint_text: text to be used as a hint
--
--              validate: a toggle to turn on or off validation
--
-- Description: This script prompts for a hint. It does not validate the hint. It creates a 
--              SQL Patch with the hint text and attaches it to the provided sql_id.
--              This script should work with 11g.
--              
----------------------------------------------------------------------------------------- 

accept sql_id -
       prompt 'Enter value for sql_id: ' -
       default 'X0X0X0X0'
accept patch_name -
       prompt 'Enter value for patch_name (PATCH_sqlid): ' -
       default 'X0X0X0X0'
accept category -
       prompt 'Enter value for category (DEFAULT): ' -
       default 'DEFAULT'
accept hint_txt -
       prompt 'Enter value for hint_text: ' -
       default 'comment'
accept validate -
       prompt 'Enter value for validate (false): ' -
       default 'false'


set feedback off
set sqlblanklines on
set serverout on format wrapped

declare
l_patch_name varchar2(30);
cl_sql_text clob;
l_category varchar2(30);
l_validate varchar2(3);
b_validate boolean;
begin

select
sql_fulltext
into
cl_sql_text
from
v$sqlarea
where
sql_id = '&&sql_id';

select decode('&&patch_name','X0X0X0X0','PATCH_'||'&&sql_id','&&patch_name')
into l_patch_name
from dual;

dbms_sqldiag_internal.i_create_patch(
sql_text => cl_sql_text, 
hint_text => q'[&&hint_txt]',
name => l_patch_name,
category => '&&category',
validate => &&validate
);

dbms_output.put_line(' ');
dbms_output.put_line('SQL Patch '||l_patch_name||' created.');
dbms_output.put_line(' ');

EXCEPTION
   WHEN NO_DATA_FOUND THEN
      dbms_output.put_line(' ');
      dbms_output.put_line('ERROR: SQL_ID: '||'&&sql_id'||' does not exist in v$sqlarea.');
      dbms_output.put_line('The SQL statement must be in the shared pool to use this script.');
      dbms_output.put_line(' ');
end;
/

undef patch_name
undef sql_id
undef category
undef validate
undef hint_txt

set sqlblanklines off
set feedback on
set serverout off
