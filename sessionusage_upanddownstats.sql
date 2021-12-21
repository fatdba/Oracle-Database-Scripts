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
PROMPT----- Script: sessionusage_upanddownstats.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Performance Management and Issue Identification
PROMPT----- Version: V1.1 (Date: 01-11-2020)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

WITH
by_instance_and_snap AS (
SELECT 
       r.snap_id,
       r.instance_number,
       s.begin_interval_time,
       s.end_interval_time,
       MAX(r.current_utilization) current_utilization,
       MAX(r.max_utilization) max_utilization
  FROM dba_hist_resource_limit r,
       dba_hist_snapshot s
 WHERE s.snap_id BETWEEN &beginsnapid AND &endsnapid
   AND s.dbid = &dbid
   AND r.snap_id = s.snap_id
   AND r.dbid = s.dbid
   AND r.instance_number = s.instance_number
   AND r.resource_name = 'sessions'
 GROUP BY
       r.snap_id,
       r.instance_number,
       s.begin_interval_time,
       s.end_interval_time
)
SELECT 
       snap_id,
       TO_CHAR(MIN(begin_interval_time), 'YYYY-MM-DD HH24:MI:SS') begin_time,
       TO_CHAR(MIN(end_interval_time), 'YYYY-MM-DD HH24:MI:SS') end_time,
       SUM(current_utilization) current_utilization,
       SUM(max_utilization) max_utilization,
       0 dummy_03,
       0 dummy_04,
       0 dummy_05,
       0 dummy_06,
       0 dummy_07,
       0 dummy_08,
       0 dummy_09,
       0 dummy_10,
       0 dummy_11,
       0 dummy_12,
       0 dummy_13,
       0 dummy_14,
       0 dummy_15
  FROM by_instance_and_snap
 GROUP BY
       snap_id
 ORDER BY
       snap_id;
