-- Authored by Prashant The FatDBA 
-- 
undef sql_handle
undef plan_name
set serveroutput on
declare
  gg binary_integer;
begin
  gg:=dbms_spm.drop_sql_plan_baseline( sql_handle => '&sql_handle', plan_name => nvl('&plan_name',null));
end;
/
undef sql_handle
undef plan_name
