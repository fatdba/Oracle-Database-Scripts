Create tuning task

set long 1000000000
DECLARE
l_sql_tune_task_id VARCHAR2(100);
BEGIN
l_sql_tune_task_id := DBMS_SQLTUNE.create_tuning_task (
sql_id => 'apwfwjhgc9sk8',
scope => DBMS_SQLTUNE.scope_comprehensive,
time_limit => 500,
task_name => 'apwfwjhgc9sk8_tuning_task_1',
description => 'Tuning task for statement apwfwjhgc9sk8');
DBMS_OUTPUT.put_line('l_sql_tune_task_id: ' || l_sql_tune_task_id);
END;
/

Execute tuning task

EXEC DBMS_SQLTUNE.execute_tuning_task(task_name => 'apwfwjhgc9sk8_tuning_task_1');

Generate report

SET LONG 10000000;
SET PAGESIZE 100000000
SET LINESIZE 200
SELECT DBMS_SQLTUNE.report_tuning_task('apwfwjhgc9sk8_tuning_task_1') AS recommendations FROM dual;
SET PAGESIZE 24
