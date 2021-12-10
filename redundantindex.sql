PROMPT
PROMPT
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT------                 /)  (\
PROMPT------            .-._((,~~.))_.-,
PROMPT------             `-.   @@   ,-'
PROMPT------               / ,o--o. \
PROMPT------              ( ( .__. ) )
PROMPT------               ) `----' (
PROMPT------              /          \
PROMPT------             /            \
PROMPT------            /              \
PROMPT------    "The Silly Cow"
PROMPT----- Script: redundantindex.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Performance Management and Issue Identification
PROMPT----- Version: V1.1 (Date: 11-08-2018)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~WITH
indexed_columns AS (
SELECT 
       col.index_owner,
       col.index_name,
       col.table_owner,
       col.table_name,
       idx.index_type,
       idx.uniqueness,
       MAX(CASE col.column_position WHEN 01 THEN      col.column_name END)||
       MAX(CASE col.column_position WHEN 02 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 03 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 04 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 05 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 06 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 07 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 08 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 09 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 10 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 11 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 12 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 13 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 14 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 15 THEN ':'||col.column_name END)||
       MAX(CASE col.column_position WHEN 16 THEN ':'||col.column_name END)
       indexed_columns
  FROM dba_ind_columns col,
       dba_indexes idx
 WHERE col.table_owner NOT IN ('ANONYMOUS','APEX_030200','APEX_040000','APEX_SSO','APPQOSSYS','CTXSYS','DBSNMP','DIP','EXFSYS','FLOWS_FILES','MDSYS','OLAPSYS','ORACLE_OCM','ORDDATA','ORDPLUGINS','ORDSYS','OUTLN','OWBSYS')
   AND col.table_owner NOT IN ('SI_INFORMTN_SCHEMA','SQLTXADMIN','SQLTXPLAIN','SYS','SYSMAN','SYSTEM','TRCANLZR','WMSYS','XDB','XS$NULL','PERFSTAT','STDBYPERF','MGDSYS','OJVMSYS')
   AND idx.owner = col.index_owner
   AND idx.index_name = col.index_name
 GROUP BY
       col.index_owner,
       col.index_name,
       col.table_owner,
       col.table_name,
       idx.index_type,
       idx.uniqueness
)
SELECT 
       r.table_owner,
       r.table_name,
       r.index_type,
       r.index_name||' ('||r.indexed_columns||')' redundant_index,
       i.index_name||' ('||i.indexed_columns||')' superset_index
  FROM indexed_columns r,
       indexed_columns i
 WHERE i.table_owner = r.table_owner
   AND i.table_name = r.table_name
   AND i.index_type = r.index_type
   AND i.index_name != r.index_name
   AND i.indexed_columns LIKE r.indexed_columns||':%'
   AND r.uniqueness = 'NONUNIQUE'
 ORDER BY
       r.table_owner,
       r.table_name,
       r.index_name,
       i.index_name;
