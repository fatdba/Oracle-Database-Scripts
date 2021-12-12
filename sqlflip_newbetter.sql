----------------------------------------------------------------------------------------
--
-- File name:   sqlflip_newbetter.sql
--
-- Purpose:     Provides SQL with multiple Execution Plans and their PHVs and text with
-- average max and min runtimes with median slope
--
---------------------------------------------------------------------------------------
WITH
per_phv AS (
SELECT 
       h.dbid,
       h.sql_id,
       h.plan_hash_value,
       MIN(s.begin_interval_time) min_time,
       MAX(s.end_interval_time) max_time,
       MEDIAN(h.elapsed_time_total / h.executions_total) med_time_per_exec,
       STDDEV(h.elapsed_time_total / h.executions_total) std_time_per_exec,
       AVG(h.elapsed_time_total / h.executions_total)    avg_time_per_exec,
       MIN(h.elapsed_time_total / h.executions_total)    min_time_per_exec,
       MAX(h.elapsed_time_total / h.executions_total)    max_time_per_exec,
       STDDEV(h.elapsed_time_total / h.executions_total) / AVG(h.elapsed_time_total / h.executions_total) std_dev,
       MAX(h.executions_total) executions_total,
       MEDIAN(h.elapsed_time_total / h.executions_total) * MAX(h.executions_total) total_elapsed_time
  FROM dba_hist_sqlstat h,
       dba_hist_snapshot s
 WHERE h.snap_id BETWEEN &beginsnap AND &endsnap
   AND h.dbid = &dbid
   AND h.executions_total > 1
   AND h.plan_hash_value > 0
   AND s.snap_id = h.snap_id
   AND s.dbid = h.dbid
   AND s.instance_number = h.instance_number
   AND CAST(s.end_interval_time AS DATE) > SYSDATE - 31
 GROUP BY
       h.dbid,
       h.sql_id,
       h.plan_hash_value
),
ranked1 AS (
SELECT 
       RANK () OVER (ORDER BY STDDEV(med_time_per_exec)/AVG(med_time_per_exec) DESC) rank_num1,
       dbid,
       sql_id,
       COUNT(*) plans,
       SUM(total_elapsed_time) total_elapsed_time,
       MIN(med_time_per_exec) min_med_time_per_exec,
       MAX(med_time_per_exec) max_med_time_per_exec
  FROM per_phv
 GROUP BY
       dbid,
       sql_id
HAVING COUNT(*) > 1
),
ranked2 AS (
SELECT 
       RANK () OVER (ORDER BY r.total_elapsed_time DESC) rank_num2,
       r.rank_num1,
       r.sql_id,
       r.plans,
       p.plan_hash_value,
       TO_CHAR(CAST(p.min_time AS DATE), 'YYYY-MM-DD/HH24') min_time,
       TO_CHAR(CAST(p.max_time AS DATE), 'YYYY-MM-DD/HH24') max_time,
       ROUND(p.med_time_per_exec / 1e6, 3) med_secs_per_exec,
       p.executions_total executions,
       ROUND(p.med_time_per_exec * p.executions_total / 1e6, 3) aprox_tot_secs,
       ROUND(p.std_time_per_exec / 1e6, 3) std_secs_per_exec,
       ROUND(p.avg_time_per_exec / 1e6, 3) avg_secs_per_exec,
       ROUND(p.min_time_per_exec / 1e6, 3) min_secs_per_exec,
       ROUND(p.max_time_per_exec / 1e6, 3) max_secs_per_exec,
       REPLACE(DBMS_LOB.SUBSTR(s.sql_text, 1000), CHR(10)) sql_text
  FROM ranked1 r,
       per_phv p,
       dba_hist_sqltext s
 WHERE r.rank_num1 <= 20 * 5
   AND p.dbid = r.dbid
   AND p.sql_id = r.sql_id
   AND s.dbid(+) = r.dbid AND s.sql_id(+) = r.sql_id
)
SELECT 
       r.sql_id,
       r.plans,
       r.plan_hash_value,
       r.min_time,
       r.max_time,
       r.med_secs_per_exec,
       r.executions,
       r.aprox_tot_secs,
       r.std_secs_per_exec,
       r.avg_secs_per_exec,
       r.min_secs_per_exec,
       r.max_secs_per_exec,
       r.sql_text
  FROM ranked2 r
 WHERE rank_num2 <= 20
 ORDER BY
       r.rank_num2,
       r.sql_id,
       r.min_time,
       r.plan_hash_value;
