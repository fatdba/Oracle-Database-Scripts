BEGIN
DBMS_STATS.GATHER_TABLE_STATS (
ownname => 'SCOTT',
tabname => 'TEST',
cascade => true, ---- For collecting stats for respective indexes
method_opt=>'for all indexed columns size 1',
granularity => 'ALL',
estimate_percent =>dbms_stats.auto_sample_size,
degree => 8);
END;
/

-- For a single table partition

BEGIN
DBMS_STATS.GATHER_TABLE_STATS (
ownname => 'SCOTT',
tabname => 'TEST', --- TABLE NAME
partname => 'TEST_JAN2016' --- PARTITOIN NAME
method_opt=>'for all indexed columns size 1',
GRANULARITY => 'APPROX_GLOBAL AND PARTITION',
degree => 8);
END;
/




-- for schema
Begin
dbms_stats.gather_schema_stats(
ownname => 'SCOTT', --- schema name
options => 'GATHER AUTO',
estimate_percent => dbms_stats.auto_sample_size,
method_opt => 'for all columns size repeat',
degree => 24
);
END;
/

