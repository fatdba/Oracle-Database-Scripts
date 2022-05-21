----------------------------------------------------------------------------------------
--
-- File name:   profile_hints.sql
--
-- Purpose:     Show hints associated with a SQL Profile.
-
-- Author:      Kerry Osborne
--
-- Usage:       This scripts prompts for one value.
--
--              profile_name: the name of the profile to be modified
--
-- Description: This script pulls the hints associated with a SQL Profile.
--
-- Mods:        Modified to check for 10g or 11g as the hint structure changed.
--              Modified to join on category as well as signature.
--
--              See kerryosborne.oracle-guy.com for additional information.
---------------------------------------------------------------------------------------
--
set sqlblanklines on
set serveroutput on
set feedback off
accept profile_name -
       prompt 'Enter value for profile_name: ' -
       default 'X0X0X0X0'

declare
ar_profile_hints sys.sqlprof_attr;
cl_sql_text clob;
version varchar2(3);
l_category varchar2(30);
l_force_matching varchar2(3);
b_force_matching boolean;
begin
 select regexp_replace(version,'\..*') into version from v$instance;

if version = '10' then

-- dbms_output.put_line('version: '||version);
   execute immediate -- to avoid 942 error 
   'select attr_val as outline_hints '||
   'from dba_sql_profiles p, sqlprof$attr h '||
   'where p.signature = h.signature '||
   'and p.category = h.category  '||
   'and name like (''&&profile_name'') '||
   'order by attr#'
   bulk collect 
   into ar_profile_hints;

elsif version = '11' then

-- dbms_output.put_line('version: '||version);
   execute immediate -- to avoid 942 error 
   'select hint as outline_hints '||
   'from (select p.name, p.signature, p.category, row_number() '||
   '      over (partition by sd.signature, sd.category order by sd.signature) row_num, '||
   '      extractValue(value(t), ''/hint'') hint '||
   'from sys.sqlobj$data sd, dba_sql_profiles p, '||
   '     table(xmlsequence(extract(xmltype(sd.comp_data), '||
   '                               ''/outline_data/hint''))) t '||
   'where sd.obj_type = 1 '||
   'and p.signature = sd.signature '||
   'and p.category = sd.category '||
   'and p.name like (''&&profile_name'')) '||
   'order by row_num'
   bulk collect 
   into ar_profile_hints;

end if;

  dbms_output.put_line(' ');
  dbms_output.put_line('HINT');
  dbms_output.put_line('------------------------------------------------------------------------------------------------------------------------------------------------------');
  for i in 1..ar_profile_hints.count loop
    dbms_output.put_line(ar_profile_hints(i));
  end loop;
  dbms_output.put_line(' ');
  dbms_output.put_line(ar_profile_hints.count||' rows selected.');
  dbms_output.put_line(' ');

end;
/
undef profile_name
set feedback on

