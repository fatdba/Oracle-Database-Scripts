-- View current AWR retention period

select retention from dba_hist_wr_control;

-- Modify retention period to 7 days and interval to 30 min

select dbms_workload_repository.modify_snapshot_settings (interval => 30, retention => 10080);

NOTE - 7 DAYS = 7*24*3600= 10080 minutes
