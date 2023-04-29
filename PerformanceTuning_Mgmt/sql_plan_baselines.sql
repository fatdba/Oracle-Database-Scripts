1.Get the sql_handle and sql_baseline name of the sql_id:

SELECT sql_handle, plan_name FROM dba_sql_plan_baselines WHERE signature IN ( SELECT exact_matching_signature FROM gv$sql WHERE sql_id='&SQL_ID')

SQL_HANDLE PLAN_NAME
--------------------------------------------- ----------------------------------------------------
SQL_164b2be280f1ffba SQL_PLAN_1cktbwa0g3zxu06dab5d5

2. Drop the baseline:

SQL> select sql_handle,plan_name from dba_sql_plan_baselines where plan_name='SQL_PLAN_1cktbwa0g3zxu06dab5d5';

SQL_HANDLE PLAN_NAME
--------------------------------------------- -------------------------------------------------------------------
SQL_164b2be280f1ffba SQL_PLAN_1cktbwa0g3zxu06dab5d5


declare
drop_result pls_integer;
begin
drop_result := DBMS_SPM.DROP_SQL_PLAN_BASELINE(
sql_handle => 'SQL_164b2be280f1ffba',
plan_name => 'SQL_PLAN_1cktbwa0g3zxu06dab5d5');
dbms_output.put_line(drop_result);
end;
/

PL/SQL procedure successfully completed.

SQL> SQL> select sql_handle,plan_name from dba_sql_plan_baselines where plan_name='SQL_PLAN_1cktbwa0g3zxu06dab5d5';

no rows selected

An sql_handle can have multiple sql baselines tagged, So if you want to drop all the sql baselines of that handle, then drop the sql handle itself.

declare
drop_result pls_integer;
begin
drop_result := DBMS_SPM.DROP_SQL_PLAN_BASELINE(
sql_handle => 'SQL_164b2be280f1ffba');
dbms_output.put_line(drop_result);
end;
/
