col table_name for a20
col column_name for a20
select a.tablE_name,a.column_name, b.EQUALITY_PREDS,b.EQUIJOIN_PREds,b.RANGE_PREDS,b.LIKE_PREDS,b.NULL_PREDS from dba_tab_columns a, sys.col_usage$ b,dba_objects c where a.COLUMN_ID=b.intcol# and c.object_id=b.obj# and c.object_name=a.table_name and c.owner = a.owner and c.object_name='&table_name' and c.owner='&owner';



set linesi 190
set verify off
col histogram format a15
col low_value format a20
col high_value format a20
col column_name format a30
set pagesi 0
set echo off
select COLUMN_NAME,NUM_DISTINCT,LOW_VALUE,HIGH_VALUE,DENSITY,NUM_NULLS,histogram from DBA_TAB_COL_STATISTICS where table_name=upper('&table_name') and owner=nvl(upper('&owner'),'BOOKER');
