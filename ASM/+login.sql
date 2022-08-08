#col upper(instance_name) new_v dbname noprint 
#select upper(instance_name) from v$instance;
#set SQLP &dbname>
#clear col
--COLUMN user_name NEW_VALUE xUser NOPRINT
COLUMN instance_name NEW_VALUE xInstance NOPRINT
--SELECT user user_name, upper(instance_name) instance_name FROM v$instance;
SELECT upper(instance_name) instance_name FROM v$instance;
--SET SQLPROMPT &&xUser..&&xInstance . >
SET SQLPROMPT "&&xInstance.> " 
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD:HH24:MI';
select sysdate, startup_time from v$instance;
-- set echo on
