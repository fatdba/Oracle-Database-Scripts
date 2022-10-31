--
-- Author: Prashant 'The FatDBA' Dixit
--
set verify off
set heading off echo off feed off pages 0 linesize 505
accept tab_owner        prompt 'Enter Table Owner: '
accept tab_name         prompt 'Enter Table Name : '
spool run-set-table-stats.sql
SELECT  'exec dbms_stats.set_table_stats(ownname=>'||chr(39)||owner||chr(39)||','||
                                        'tabname=>'||chr(39)||table_name||chr(39)||','||
                                        'numrows=>'||num_rows||','||
                                        'numblks=>'||blocks||','||
                                        'avgrlen=>'||avg_row_len||');'
FROM     dba_tables
WHERE    owner          = upper('&&tab_owner')
AND      table_name     = upper('&&tab_name')
AND      last_analyzed is not null
;

SELECT  'exec dbms_stats.set_table_stats(ownname=>'||chr(39)||table_owner||chr(39)||','||
                                        'tabname=>'||chr(39)||table_name||chr(39)||','||
                                        'partname=>'||chr(39)||partition_name||chr(39)||','||
                                        'numrows=>'||num_rows||','||
                                        'numblks=>'||blocks||','||
                                        'avgrlen=>'||avg_row_len||');'
FROM     dba_tab_partitions
WHERE    table_owner    = upper('&&tab_owner')
AND      table_name     = upper('&&tab_name')
AND      last_analyzed is not null
;

SELECT  'exec dbms_stats.set_index_stats(ownname=>'||chr(39)||owner||chr(39)||','||
                                        'indname=>'||chr(39)||index_name||chr(39)||','||
                                        'numrows=>'||round(num_rows)||','||
                                        'numlblks=>'||leaf_blocks||','||
                                        'numdist=>'||distinct_keys||','||
                                        'avglblk=>'||avg_leaf_blocks_per_key||','||
                                        'avgdblk=>'||avg_data_blocks_per_key||','||
                                        'clstfct=>'||clustering_factor||','||
                                        'indlevel=>'||blevel||');'
FROM     dba_indexes
WHERE    owner          = upper('&&tab_owner')
AND      table_name     = upper('&&tab_name')
AND      last_analyzed is not null
;

SELECT  'exec dbms_stats.set_index_stats(ownname=>'||chr(39)||i.owner||chr(39)||','||
                                        'indname=>'||chr(39)||i.index_name||chr(39)||','||
                                        'partname=>'||chr(39)||p.partition_name||chr(39)||','||
                                        'numrows=>'||round(p.num_rows)||','||
                                        'numlblks=>'||p.leaf_blocks||','||
                                        'numdist=>'||p.distinct_keys||','||
                                        'avglblk=>'||p.avg_leaf_blocks_per_key||','||
                                        'avgdblk=>'||p.avg_data_blocks_per_key||','||
                                        'clstfct=>'||p.clustering_factor||','||
                                        'indlevel=>'||p.blevel||');'
FROM     dba_ind_partitions p, dba_indexes i
WHERE    i.owner        = upper('&&tab_owner')
AND      i.table_name   = upper('&&tab_name')
AND      i.owner        = p.index_owner
AND      i.index_name   = p.index_name
AND      p.last_analyzed is not null
;

SELECT  'exec dbms_stats.set_column_stats(ownname=>'||chr(39)||tc.owner||chr(39)||','||
                                        'tabname=>'||chr(39)||tc.table_name||chr(39)||','||
                                        'colname=>'||chr(39)||tc.column_name||chr(39)||','||
                                        'distcnt=>'||tc.num_distinct||','||
                                        'density=>'||tc.density||','||
                                        'nullcnt=>'||tc.num_nulls||','||
                                        'avgclen=>'||tc.avg_col_len||');'
FROM     dba_tab_col_statistics tc
WHERE    tc.owner 	= upper('&&tab_owner')
AND      tc.table_name  = upper('&&tab_name')
AND      tc.last_analyzed is not null 
order by 1
;

SELECT  'exec dbms_stats.set_column_stats(ownname=>'||chr(39)||pc.owner||chr(39)||','||
                                         'tabname=>'||chr(39)||pc.table_name||chr(39)||','||
                                         'partname=>'||chr(39)||pc.partition_name||chr(39)||','||
                                         'colname=>'||chr(39)||pc.column_name||chr(39)||','||
                                         'distcnt=>'||pc.num_distinct||','||
                                         'density=>'||pc.density||','||
                                         'nullcnt=>'||pc.num_nulls||','||
                                         'avgclen=>'||pc.avg_col_len||');'
FROM     dba_part_col_statistics pc
WHERE    pc.owner 	= upper('&&tab_owner')
AND      pc.table_name  = upper('&&tab_name')
AND      pc.last_analyzed is not null 
order by 1
;

spool off
prompt Generated=> run-set-table-stats.sql
undef tab_owner
undef tab_name
set echo on feed on head on
