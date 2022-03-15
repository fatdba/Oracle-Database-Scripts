-- Check the status of incremental pref

select dbms_stats.get_prefs('INCREMENTAL', tabname=>'EMPLOYEE',ownname=>'SCOTT') from dual;

FALSE

-- Enable incremental stats collection

SQL> exec DBMS_STATS.SET_TABLE_PREFS('SCOTT','EMPLOYEE','INCREMENTAL','TRUE');

PL/SQL procedure successfully completed.

-- Check the pref again:

select dbms_stats.get_prefs('INCREMENTAL', tabname=>'EMPLOYEE',ownname=>'SCOTT') from dual;

TRUE
