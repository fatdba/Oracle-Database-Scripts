--
-- Author: Prashant 'The FatDBA' Dixit
--
set linesi 190
set pagesi 1000
set serveroutput on
alter system set resource_manager_plan='' scope=both; 
execute dbms_scheduler.set_attribute('WEEKEND_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('WEEKNIGHT_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('MONDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('TUESDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('WEDNESDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('THURSDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('FRIDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('SATURDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.set_attribute('SUNDAY_WINDOW','RESOURCE_PLAN','');
execute dbms_scheduler.close_window('TUESDAY_WINDOW');
execute dbms_auto_task_admin.disable( client_name => 'sql tuning advisor',operation => NULL,window_name => NULL);
commit;
select window_name,resource_plan from dba_scheduler_windows;
select WINDOW_NAME ,WINDOW_ACTIVE,AUTOTASK_STATUS,OPTIMIZER_STATS,SEGMENT_ADVISOR,SQL_TUNE_ADVISOR,HEALTH_MONITOR from DBA_AUTOTASK_WINDOW_CLIENTS;
