-- Change the number of SQL’s captured TOPNSQL
-- To change the settings to capture all the SQL’s in the cache
execute  dbms_workload_repository.modify_snapshot_settings (topnsql => 'MAXIMUM');

-- The number of SQL statements captured also depends on your statistics_level setting:
-- When statistics_level=typical, AWR will capture the topnsql.  Without the topnsql set, the default is to capture 30 SQL statements, for a total of 420 per snapshot.
-- When statistics_level=all, AWR will capture the top 100 SQL for each of the criteria (elapsed time, CPU, disk reads, etc.), for a total of 1400 SQL statements per snapshot.
-- Top N SQL size -> This can be set to (DEFAULT, MAXIMUM, N).  Specifying DEFAULT will revert the system back to the default behavior of Top 30 for statistics level TYPICAL and Top 100 for statistics level ALL. The number of Top SQL to flush for each SQL criteria (Elapsed Time, CPU Time, Parse Calls, Shareable Memory, Version Count). The value for this setting will not be affected by the statistics/flush level and will override the system default behavior for the AWR SQL collection. The setting will have a minimum value of 30 and a maximum value of 50,000. Specifying NULL will keep the current setting.

exec dbms_workload_repository.modify_snapshot_settings(retention=>28800, interval=>30, topnsql=>100, dbid=>3970683413);
