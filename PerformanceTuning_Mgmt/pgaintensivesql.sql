SELECT 
       h.sql_id,
       ROUND(MAX(h.pga_allocated)/POWER(2,30),1) max_pga_gb,
       DBMS_LOB.SUBSTR(s.sql_text, 1000) sql_text
  FROM dba_hist_active_sess_history h,
       dba_hist_sqltext s
 WHERE h.pga_allocated > 2*POWER(2,30)
   AND h.sql_id IS NOT NULL
   AND h.snap_id BETWEEN 83426 AND 84165
   AND h.dbid = '&dbid'
   AND s.sql_id(+) = h.sql_id AND s.dbid(+) = '&dbid'
   AND s.con_id(+) = h.con_id
 GROUP BY
       h.sql_id,
       DBMS_LOB.SUBSTR(s.sql_text, 1000)
 ORDER BY
       2 DESC, 1;
