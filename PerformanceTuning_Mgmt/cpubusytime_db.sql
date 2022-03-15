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
PROMPT----- Script: cpubusytime_db.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Performance Management and Issue Identification
PROMPT----- Version: V1.2 (Date: 04-02-2020)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~WITH
seed AS (
SELECT 
       o.snap_id,
       o.instance_number,
       o.value - LAG(o.value) OVER (PARTITION BY o.dbid, o.instance_number, o.stat_id ORDER BY o.snap_id) value,
       s.begin_interval_time,
       s.end_interval_time
  FROM dba_hist_osstat o,
       dba_hist_snapshot s
 WHERE o.stat_name = 'BUSY_TIME'
   AND o.snap_id BETWEEN &beginsnap AND &endsnap
   AND o.dbid = &DBID
   AND s.snap_id         = o.snap_id
   AND s.dbid            = o.dbid
   AND s.instance_number = o.instance_number
   AND (CAST(s.end_interval_time AS DATE) - CAST(s.begin_interval_time AS DATE)) * 24 * 60 > 1 -- ignore snaps closer than 1m appart
)
SELECT snap_id,
       TO_CHAR(MIN(begin_interval_time), 'YYYY-MM-DD HH24:MI:SS') begin_time,
       TO_CHAR(MIN(end_interval_time), 'YYYY-MM-DD HH24:MI:SS') end_time,
       SUM(CASE instance_number WHEN 1 THEN value ELSE 0 END) inst_01,
       SUM(CASE instance_number WHEN 2 THEN value ELSE 0 END) inst_02,
       SUM(CASE instance_number WHEN 3 THEN value ELSE 0 END) inst_03,
       SUM(CASE instance_number WHEN 4 THEN value ELSE 0 END) inst_04,
       SUM(CASE instance_number WHEN 5 THEN value ELSE 0 END) inst_05,
       SUM(CASE instance_number WHEN 6 THEN value ELSE 0 END) inst_06,
       SUM(CASE instance_number WHEN 7 THEN value ELSE 0 END) inst_07,
       SUM(CASE instance_number WHEN 8 THEN value ELSE 0 END) inst_08,
       0 dummy_09,
       0 dummy_10,
       0 dummy_11,
       0 dummy_12,
       0 dummy_13,
       0 dummy_14,
       0 dummy_15
  FROM seed
 WHERE value >= 0
 GROUP BY
       snap_id
 ORDER BY
       snap_id;
