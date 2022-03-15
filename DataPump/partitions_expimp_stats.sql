--- Create staging table to store the statistics data

exec dbms_stats.create_stat_table(ownname => 'SCOTT', stattab => 'STAT_BACKUP',tblspace=>'USERS');

-- Export stats

exec dbms_stats.export_table_stats(ownname=>'SCOTT', tabname=>'EMP', stattab=>'STAT_BACKUP', cascade=>true);

-- Import stats

exec dbms_stats.import_table_stats(ownname=>'SCOTT', tabname=>'EMP', stattab=>'STAT_BACKUP', cascade=>true);
