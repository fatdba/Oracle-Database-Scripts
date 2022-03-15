Delete statistics of the complete database

EXEC DBMS_STATS.delete_database_stats;

-- Delete statistics of a single schema

EXEC DBMS_STATS.delete_schema_stats('DBACLASS');

-- Delete statistics of single tabale
EXEC DBMS_STATS.delete_table_stats('DBACLASS', 'DEPT');

-- Delete statistics of a column
EXEC DBMS_STATS.delete_column_stats('DBACLASS', 'DEPT', 'CLASS');

--Delete statistics of an index

EXEC DBMS_STATS.delete_index_stats('DBACLASS', 'CLASS_IDX');

--Delete dictionary a in db

EXEC DBMS_STATS.delete_dictionary_stats;
