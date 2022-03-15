--- Lock  statistics

EXEC DBMS_STATS.lock_schema_stats('SCOTT');
EXEC DBMS_STATS.lock_table_stats('SCOTT', 'TEST');
EXEC DBMS_STATS.lock_partition_stats('SCOTT', 'TEST', 'TEST_JAN2016');

-- Unlock statistics

EXEC DBMS_STATS.unlock_schema_stats('SCOTT');
EXEC DBMS_STATS.unlock_table_stats('SCOTT', 'TEST');
EXEC DBMS_STATS.unlock_partition_stats('SCOTT', 'TEST', 'TEST_JAN2016');

--- check stats status:

SELECT stattype_locked FROM dba_tab_statistics WHERE table_name = 'TEST' and owner = 'SCOTT';
