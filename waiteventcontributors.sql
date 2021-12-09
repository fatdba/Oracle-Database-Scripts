WITH
events AS (
SELECT /*+ MATERIALIZE NO_MERGE */
       SUBSTR(TRIM(h.sql_id||' '||h.program||' '||
       CASE h.module WHEN h.program THEN NULL ELSE h.module END), 1, 128) source,
       h.dbid,
       COUNT(*) samples
  FROM dba_hist_active_sess_history h,
       dba_hist_snapshot s
 WHERE h.wait_class = TRIM('&Event_Class') AND h.event = TRIM('&Event_Name')
   AND h.snap_id BETWEEN &Begin_Snap AND &End_Snap
   AND h.dbid = &dbid
   AND s.snap_id = h.snap_id
   AND s.dbid = h.dbid
   AND s.instance_number = h.instance_number
 GROUP BY
       h.sql_id,
       h.program,
       h.module,
       h.dbid
 ORDER BY
       3 DESC
),
total AS (
SELECT SUM(samples) samples,
       SUM(CASE WHEN ROWNUM > 15 THEN samples ELSE 0 END) others
  FROM events
)
SELECT e.source,
       e.samples,
       ROUND(100 * e.samples / t.samples, 1) percent,
       (SELECT DBMS_LOB.SUBSTR(s.sql_text, 1000, 1) FROM dba_hist_sqltext s WHERE s.sql_id = SUBSTR(e.source, 1, 13) AND s.dbid = e.dbid AND ROWNUM = 1) sql_text
  FROM events e,
       total t
 WHERE ROWNUM  0.1
 UNION ALL
SELECT 'Others',
       others samples,
       ROUND(100 * others / samples, 1) percent,
       NULL sql_text
  FROM total
 WHERE others > 0
   AND ROUND(100 * others / samples, 1) > 0.1;
