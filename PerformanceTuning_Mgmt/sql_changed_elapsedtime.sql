-- Not written by me but is an awesome script to identify SQLs with huge change in elapsed times
WITH
per_time AS (
SELECT 
       h.dbid,
       h.sql_id,
       SYSDATE - CAST(s.end_interval_time AS DATE) days_ago,
       SUM(h.elapsed_time_total) / SUM(h.executions_total) time_per_exec
  FROM dba_hist_sqlstat h,
       dba_hist_snapshot s
 WHERE h.snap_id BETWEEN &beginsnap AND &endsnap
   AND h.dbid = &DBID
   AND h.executions_total > 0
   AND h.plan_hash_value > 0
   AND s.snap_id = h.snap_id
   AND s.dbid = h.dbid
   AND s.instance_number = h.instance_number
   AND CAST(s.end_interval_time AS DATE) > SYSDATE - 31
 GROUP BY
       h.dbid,
       h.sql_id,
       SYSDATE - CAST(s.end_interval_time AS DATE)
),
avg_time AS (
SELECT 
       dbid,
       sql_id,
       MEDIAN(time_per_exec) med_time_per_exec,
       STDDEV(time_per_exec) std_time_per_exec,
       AVG(time_per_exec)    avg_time_per_exec,
       MIN(time_per_exec)    min_time_per_exec,
       MAX(time_per_exec)    max_time_per_exec
  FROM per_time
 GROUP BY
       dbid,
       sql_id
HAVING COUNT(*) >= 10
   AND MAX(days_ago) - MIN(days_ago) >= 5
   AND MEDIAN(time_per_exec) > 1e4
),
time_over_median AS (
SELECT 
       h.dbid,
       h.sql_id,
       h.days_ago,
       (h.time_per_exec / a.med_time_per_exec) time_per_exec_over_med,
       a.med_time_per_exec,
       a.std_time_per_exec,
       a.avg_time_per_exec,
       a.min_time_per_exec,
       a.max_time_per_exec
  FROM per_time h, avg_time a
 WHERE a.sql_id = h.sql_id
),
ranked AS (
SELECT 
       RANK () OVER (ORDER BY ABS(REGR_SLOPE(t.time_per_exec_over_med, t.days_ago)) DESC) rank_num,
       t.dbid,
       t.sql_id,
       CASE WHEN REGR_SLOPE(t.time_per_exec_over_med, t.days_ago) > 0 THEN 'IMPROVING' ELSE 'REGRESSING' END change,
       ROUND(REGR_SLOPE(t.time_per_exec_over_med, t.days_ago), 3) slope,
       ROUND(AVG(t.med_time_per_exec)/1e6, 3) med_secs_per_exec,
       ROUND(AVG(t.std_time_per_exec)/1e6, 3) std_secs_per_exec,
       ROUND(AVG(t.avg_time_per_exec)/1e6, 3) avg_secs_per_exec,
       ROUND(MIN(t.min_time_per_exec)/1e6, 3) min_secs_per_exec,
       ROUND(MAX(t.max_time_per_exec)/1e6, 3) max_secs_per_exec
  FROM time_over_median t
 GROUP BY
       t.dbid,
       t.sql_id
HAVING ABS(REGR_SLOPE(t.time_per_exec_over_med, t.days_ago)) > 0.1
)
SELECT 
       DISTINCT
       r.rank_num,
       r.sql_id,
       r.change,
       r.slope,
       r.med_secs_per_exec med_secs_per_exec,
       r.std_secs_per_exec std_secs_per_exec,
       r.avg_secs_per_exec avg_secs_per_exec,
       r.min_secs_per_exec min_secs_per_exec,
       r.max_secs_per_exec max_secs_per_exec,
       COUNT(DISTINCT p.plan_hash_value) plans,
       REPLACE(DBMS_LOB.SUBSTR(s.sql_text, 1000), CHR(10)) sql_text
  FROM ranked r,
       dba_hist_sqltext s,
       dba_hist_sql_plan p
 WHERE r.rank_num <= 20
   AND s.dbid(+) = r.dbid AND s.sql_id(+) = r.sql_id
   AND p.dbid(+) = r.dbid AND p.sql_id(+) = r.sql_id
 GROUP BY
       r.rank_num,
       r.sql_id,
       r.change,
       r.slope,
       r.med_secs_per_exec,
       r.std_secs_per_exec,
       r.avg_secs_per_exec,
       r.min_secs_per_exec,
       r.max_secs_per_exec,
       REPLACE(DBMS_LOB.SUBSTR(s.sql_text, 1000), CHR(10))
 ORDER BY
       r.rank_num;
