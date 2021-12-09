SELECT 
       h.sql_id,
       ROUND(MAX(h.temp_space_allocated)/POWER(10,9),1) max_temp_space_gb,
       DBMS_LOB.SUBSTR(s.sql_text, 1000) sql_text
  FROM dba_hist_active_sess_history h,
       dba_hist_sqltext s
 WHERE h.temp_space_allocated > 10*POWER(10,9)
   AND h.sql_id IS NOT NULL
   AND h.snap_id BETWEEN 83426 AND 84165
   AND h.dbid = '&DBID'
   AND s.sql_id(+) = h.sql_id AND s.dbid(+) = '&DBID'
   AND s.con_id(+) = h.con_id
 GROUP BY
       h.sql_id,
       DBMS_LOB.SUBSTR(s.sql_text, 1000)
 ORDER BY
       2 DESC, 1;
