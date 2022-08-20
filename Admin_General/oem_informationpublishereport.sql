-- Try with OEM Publisher reports
-- Version 1.0 
WITH 
target_list AS 
(SELECT target_name oem_target_name,
decode(instr(property_value,'.'),0,property_value,substr(property_value,1,instr(property_value,'.')-1)) host  
FROM sysman.mgmt$target_properties where property_name='MachineName' and target_type in ('oracle_database','oracle_pdb')
and target_name in
('test','test.servers.com'
)
)
--select * from target_list
,tbs_usage_pc
                   AS (SELECT entity_name,
                              COLLECTION_TIME,
                              metric_column_label,
                              METRIC_KEY_VALUE,
                              VALUE,
                              ROW_NUMBER ()
                              OVER (
                                 PARTITION BY entity_name, METRIC_KEY_VALUE
                                 ORDER BY
                                    entity_name,
                                    METRIC_KEY_VALUE,
                                    COLLECTION_TIME DESC)
                                 rn
                         FROM (SELECT entity_name,
                                              collection_time,
                                              metric_column_label,
                                              entity_type,
                                              METRIC_KEY_VALUE,
                                              VALUE
                                         FROM sysman.gc_metric_values,
                                              target_list
                                        WHERE entity_name = OEM_TARGET_NAME
                                              AND entity_type IN
                                                     ('oracle_database',
                                                      'oracle_pdb')
                                              AND metric_column_label =
                                                     'Tablespace Space Used (%)'
                                              AND TRUNC (collection_time) =
                                                     TRUNC (SYSDATE)))
--select * from tbs_usage_pc
,dfs_usage_pc
                   AS (SELECT 
                                      t.host,
                                      collection_time,
                                      metric_column_label,
                                      entity_type,
                                      METRIC_KEY_VALUE,
                                      VALUE
                                 FROM sysman.gc_metric_values gmv,target_list t
                                WHERE decode(instr(gmv.entity_name,'.'),0,gmv.entity_name,substr(gmv.entity_name,1,instr(gmv.entity_name,'.')-1))=t.host
                                        and entity_type IN ('host')
                                      AND metric_column_label =
                                             'Filesystem Space Available (%)'
                                      AND TRUNC (collection_time) =
                                             TRUNC (SYSDATE))
--select * from dfs_usage_pc
,dfs_avail_mb
                   AS (SELECT 
                                      t.host,
                                      collection_time,
                                      metric_column_label,
                                      entity_type,
                                      METRIC_KEY_VALUE,
                                      VALUE
                                 FROM sysman.gc_metric_values gmv,target_list t
                                WHERE decode(instr(gmv.entity_name,'.'),0,gmv.entity_name,substr(gmv.entity_name,1,instr(gmv.entity_name,'.')-1))=t.host
                                        and  entity_type IN ('host')
                                      AND metric_column_label =
                                             'Filesystem Space Available (MB)'
                                      AND TRUNC (collection_time) =
                                             TRUNC (SYSDATE))
--select * from dfs_avail_mb
,wait_ev_sec
                   AS (SELECT 
                                      entity_name,
                                      collection_time,
                                      metric_column_label,
                                      entity_type,
                                      METRIC_KEY_VALUE,
                                      VALUE
                                 FROM sysman.gc_metric_values
                                WHERE entity_type IN
                                         ('oracle_database',
                                          'oracle_pdb')
                                      AND metric_column_label =
                                             'Total Foreground Wait Time (second)'
                                      AND TRUNC (collection_time) =
                                             TRUNC (SYSDATE))
--select * from wait_ev_sec
,cpu_pc
                   AS (  SELECT t.host,
                                metric_column_label,
                                ROUND (MIN (VALUE), 1) CPU_Min_PC,
                                ROUND (MAX (VALUE), 1) CPU_Max_PC,
                                ROUND (AVG (VALUE), 1) CPU_Avg_PC
                           FROM sysman.gc_metric_values gmv, target_list t
                                WHERE decode(instr(gmv.entity_name,'.'),0,gmv.entity_name,substr(gmv.entity_name,1,instr(gmv.entity_name,'.')-1))=t.host
                                and entity_type = 'host'
                                AND metric_column_label IN
                                       ('CPU Utilization (%)')
                                AND TRUNC (collection_time) = TRUNC (SYSDATE)
                       GROUP BY host, metric_column_label
                       ORDER BY host, metric_column_label)
--select * from cpu_pc                       
,swap_pc
                   AS (  SELECT t.host,
                                metric_column_label,
                                ROUND (MIN (VALUE), 1) SWAP_Min_PC,
                                ROUND (MAX (VALUE), 1) SWAP_Max_PC,
                                ROUND (AVG (VALUE), 1) SWAP_Avg_PC
                           FROM sysman.gc_metric_values gmv, target_list t
                                WHERE decode(instr(gmv.entity_name,'.'),0,gmv.entity_name,substr(gmv.entity_name,1,instr(gmv.entity_name,'.')-1))=t.host
                                and entity_type = 'host'
                                AND metric_column_label IN
                                       ('Swap Utilization (%)')
                                AND TRUNC (collection_time) = TRUNC (SYSDATE)
                       GROUP BY host, metric_column_label
                       ORDER BY host, metric_column_label)
--select * from swap_pc
,iops_pc
                   AS (  SELECT t.host,
                                metric_column_label,
                                ROUND (MIN (VALUE), 1) IOPS_Min_PC,
                                ROUND (MAX (VALUE), 1) IOPS_Max_PC,
                                ROUND (AVG (VALUE), 1) IOPS_Avg_PC
                           FROM sysman.gc_metric_values gmv, target_list t
                                WHERE decode(instr(gmv.entity_name,'.'),0,gmv.entity_name,substr(gmv.entity_name,1,instr(gmv.entity_name,'.')-1))=t.host
                                and entity_type = 'host'
                                AND metric_column_label IN
                                       ('Total Disk I/O made across all disks (per second)')
                                AND TRUNC (collection_time) = TRUNC (SYSDATE)
                       GROUP BY host, metric_column_label
                       ORDER BY host, metric_column_label)
--select * from iops_pc
,tbs_thresholds
                   AS (SELECT DISTINCT *
                         FROM (SELECT mt.target_name,
                                      mt.target_type,
                                      mmt.coll_name,
                                      mmt.warning_threshold,
                                      mmt.critical_threshold,
                                      mmt.key_value
                                 FROM sysman.mgmt_targets mt,
                                      sysman.
                                      mgmt_metric_thresholds mmt
                                WHERE mt.target_guid =
                                         mmt.target_guid
                                      AND mt.target_type IN
                                             ('oracle_database',
                                              'oracle_pdb')
                                      AND mmt.coll_name LIKE
                                             'problemTbsp%')
                        WHERE TRIM (warning_threshold) IS NOT NULL
                              AND TRIM (critical_threshold) IS NOT NULL)
--select * from tbs_thresholds
,tbs_max_pc
                   AS (  SELECT entity_name,
                                ROUND (MAX (VALUE), 1) TBS_MAX_PC
                           FROM (SELECT NVL (entity_name, OEM_TARGET_NAME) entity_name,
                                        COLLECTION_TIME,
                                        metric_column_label,
                                        METRIC_KEY_VALUE,
                                        VALUE
                                   FROM (SELECT entity_name,
                                                COLLECTION_TIME,
                                                metric_column_label,
                                                METRIC_KEY_VALUE,
                                                VALUE,
                                                ROW_NUMBER ()
                                                OVER (
                                                   PARTITION BY entity_name,
                                                                METRIC_KEY_VALUE
                                                   ORDER BY
                                                      entity_name,
                                                      METRIC_KEY_VALUE,
                                                      COLLECTION_TIME DESC)
                                                   rn
                                           FROM (SELECT entity_name,
                                                                collection_time,
                                                                metric_column_label,
                                                                entity_type,
                                                                METRIC_KEY_VALUE,
                                                                VALUE
                                                           FROM sysman.
                                                                gc_metric_values
                                                          WHERE entity_type IN
                                                                   ('oracle_database',
                                                                    'oracle_pdb')
                                                                AND metric_column_label =
                                                                       'Tablespace Space Used (%)'
                                                                AND TRUNC (
                                                                       collection_time) =
                                                                       TRUNC (
                                                                          SYSDATE))) tbs_usage_pc,
                                        target_list
                                  WHERE target_list.OEM_TARGET_NAME =
                                           tbs_usage_pc.entity_name(+)
                                        AND RN(+) = 1)
                       GROUP BY entity_name, entity_name)
--select * from tbs_max_pc
,tbs_usage_lvl
                   AS (  SELECT 
                                entity_name,
                                MAX (
                                   CASE
                                      WHEN tbs_max_pc >= critical_threshold
                                      THEN
                                         2
                                      WHEN tbs_max_pc >= warning_threshold
                                      THEN
                                         1
                                      ELSE
                                         0  /*Normal*/
                                   END)
                                   usage_level
                           FROM (  SELECT entity_name,
                                          metric_key_value,
                                          tbs_max_pc,
                                          MAX (warning_threshold)
                                             warning_threshold,
                                          MAX (critical_threshold)
                                             critical_threshold
                                     FROM (  SELECT entity_name,
                                                    metric_key_value,
                                                    ROUND (MAX (VALUE), 1)
                                                       tbs_max_pc,
                                                    warning_threshold,
                                                    critical_threshold
                                               FROM (SELECT 
                                                            entity_name,
                                                            COLLECTION_TIME,
                                                            metric_column_label,
                                                            METRIC_KEY_VALUE,
                                                            VALUE,
                                                            warning_threshold,
                                                            critical_threshold,
                                                            ROW_NUMBER ()
                                                            OVER (
                                                               PARTITION BY entity_name,
                                                                            METRIC_KEY_VALUE
                                                               ORDER BY
                                                                  entity_name,
                                                                  METRIC_KEY_VALUE,
                                                                  COLLECTION_TIME DESC)
                                                               rn
                                                       FROM tbs_usage_pc,
                                                            target_list,
                                                            tbs_thresholds
                                                      WHERE target_list.OEM_TARGET_NAME =
                                                               tbs_thresholds.
                                                               target_name(+)
                                                            AND METRIC_KEY_VALUE =
                                                                   tbs_thresholds.
                                                                   key_value
                                                            AND target_list.
                                                                OEM_TARGET_NAME =
                                                                   tbs_usage_pc.entity_name(+))
                                              WHERE rn(+) = 1
                                           GROUP BY 
                                                    entity_name,
                                                    METRIC_KEY_VALUE,
                                                    warning_threshold,
                                                    critical_threshold
                                           UNION
                                             SELECT 
                                                    entity_name,
                                                    METRIC_KEY_VALUE,
                                                    ROUND (MAX (VALUE), 1)
                                                       TBS_MAX_PC,
                                                    warning_threshold,
                                                    critical_threshold
                                               FROM (SELECT 
                                                            entity_name,
                                                            COLLECTION_TIME,
                                                            metric_column_label,
                                                            METRIC_KEY_VALUE,
                                                            VALUE,
                                                            warning_threshold,
                                                            critical_threshold,
                                                            ROW_NUMBER ()
                                                            OVER (
                                                               PARTITION BY entity_name,
                                                                            METRIC_KEY_VALUE
                                                               ORDER BY
                                                                  entity_name,
                                                                  METRIC_KEY_VALUE,
                                                                  COLLECTION_TIME DESC)
                                                               rn
                                                       FROM tbs_usage_pc,
                                                            target_list,
                                                            tbs_thresholds
                                                      WHERE target_list.OEM_TARGET_NAME =
                                                               tbs_thresholds.
                                                               target_name(+)
                                                            AND (key_value IS NULL
                                                                 OR key_value = ' ')
                                                            AND target_list.
                                                                OEM_TARGET_NAME =
                                                                   tbs_usage_pc.entity_name(+))
                                              WHERE rn(+) = 1
                                           GROUP BY 
                                                    entity_name,
                                                    metric_key_value,
                                                    warning_threshold,
                                                    critical_threshold)
                                 GROUP BY 
                                          entity_name,
                                          metric_key_value,
                                          tbs_max_pc)
                       GROUP BY entity_name)
--select * from tbs_usage_lvl                       
 ,dfs_max_pc
                   AS (  SELECT target_name,
                                MAX (data_fs_max_pc) data_fs_max_pc
                           FROM (SELECT 
                                        df.host,
                                        NVL (target_name, OEM_TARGET_NAME)
                                           target_name,
                                        data_fs_max_pc
                                   FROM (  SELECT 
                                                  host,
                                                  target_name,
                                                  ROUND (MAX (VALUE), 1)
                                                     DATA_FS_MAX_PC
                                             FROM (SELECT *
                                                     FROM (SELECT 
                                                                  host,
                                                                  target_name,
                                                                  collection_time,
                                                                  metric_column_label,
                                                                  metric_key_value,
                                                                  (100 - VALUE)
                                                                     VALUE,
                                                                  ROW_NUMBER ()
                                                                  OVER (
                                                                     PARTITION BY host,
                                                                                  metric_key_value
                                                                     ORDER BY
                                                                        host,
                                                                        metric_key_value,
                                                                        collection_time DESC)
                                                                     rn
                                                             FROM dfs_usage_pc m,
                                                                  (SELECT host_name,
                                                                          target_name,
                                                                          file_name,
                                                                          DECODE (
                                                                             SUBSTR (
                                                                                file_name,
                                                                                1,
                                                                                1),
                                                                             '/', os_storage_entity,
                                                                             SUBSTR (
                                                                                file_name,
                                                                                1,
                                                                                3))
                                                                             os_storage_entity
                                                                     FROM sysman.
                                                                          mgmt$db_datafiles
                                                                    WHERE target_type IN
                                                                             ('oracle_database',
                                                                              'oracle_pdb')) d
                                                            WHERE UPPER (
                                                                     m.host) =
                                                                     UPPER (
                                                                        d.
                                                                        host_name)
                                                                  AND metric_key_value <>
                                                                         '/'
                                                                  AND (d.
                                                                       os_storage_entity =
                                                                          metric_key_value
                                                                                          ))
                                                    WHERE RN = 1)
                                         GROUP BY host, target_name) df,
                                        target_list
                                  WHERE target_list.OEM_TARGET_NAME =
                                           df.target_name(+)
                                 UNION
                                 SELECT df.HOST,
                                        NVL (target_name, OEM_TARGET_NAME)
                                           target_name,
                                        data_fs_max_pc
                                   FROM (  SELECT 
                                                  host,
                                                  target_name,
                                                  ROUND (MAX (VALUE), 1)
                                                     DATA_FS_MAX_PC
                                             FROM (SELECT *
                                                     FROM (SELECT
                                                                  host,
                                                                  target_name,
                                                                  collection_time,
                                                                  metric_column_label,
                                                                  metric_key_value,
                                                                  (100 - VALUE)
                                                                     VALUE,
                                                                  ROW_NUMBER ()
                                                                  OVER (
                                                                     PARTITION BY host,
                                                                                  metric_key_value
                                                                     ORDER BY
                                                                        host,
                                                                        metric_key_value,
                                                                        collection_time DESC)
                                                                     rn
                                                             FROM dfs_usage_pc m,
                                                                  (SELECT decode(instr(host_name,'.'),0,host_name,substr(host_name,1,instr(host_name,'.')-1)) host_name,
                                                                          target_name,
                                                                          file_name,
                                                                          DECODE (
                                                                             SUBSTR (
                                                                                file_name,
                                                                                1,
                                                                                1),
                                                                             '/', os_storage_entity,
                                                                             SUBSTR (
                                                                                file_name,
                                                                                1,
                                                                                3))
                                                                             os_storage_entity
                                                                     FROM sysman.
                                                                          mgmt$db_datafiles
                                                                    WHERE target_type IN
                                                                             ('oracle_database',
                                                                              'oracle_pdb')) d
                                                            WHERE UPPER (
                                                                     m.
                                                                     host) =
                                                                     UPPER (
                                                                        d.
                                                                        host_name)
                                                                  AND metric_key_value <>
                                                                         '/'
                                                                  AND d.
                                                                      os_storage_entity =
                                                                         metric_key_value)
                                                    WHERE RN = 1)
                                         GROUP BY host, target_name) df,
                                        target_list
                                  WHERE target_list.OEM_TARGET_NAME =
                                           df.target_name(+))
                       GROUP BY target_name)
--select * from dfs_max_pc                       
,afs_usage_pc
                   AS (  SELECT target_name,
                                MAX (arch_fra_fs_max_pc) arch_fra_fs_max_pc
                           FROM (SELECT NVL (target_name, OEM_TARGET_NAME) target_name,
                                        arch_fra_fs_max_pc
                                   FROM (SELECT target_name,
                                                arc_file_system,
                                                ROUND (VALUE, 1)
                                                   ARCH_FRA_FS_MAX_PC
                                           FROM (SELECT target_name,
                                                        metric_key_value
                                                           arc_file_system,
                                                        VALUE,
                                                        ROW_NUMBER ()
                                                        OVER (
                                                           PARTITION BY target_name
                                                           ORDER BY
                                                              LENGTH (
                                                                 metric_key_value) DESC)
                                                           rn
                                                   FROM (  SELECT 
                                                                  target_name,
                                                                  metric_column_label,
                                                                  metric_key_value,
                                                                  VALUE
                                                             FROM (SELECT *
                                                                     FROM (SELECT a.target_name,
                                                                                  collection_time,
                                                                                  metric_column_label,
                                                                                  metric_key_value,
                                                                                  (100
                                                                                   - VALUE)
                                                                                     VALUE,
                                                                                  ROW_NUMBER ()
                                                                                  OVER (
                                                                                     PARTITION BY host,
                                                                                                  metric_key_value
                                                                                     ORDER BY
                                                                                        collection_time DESC)
                                                                                     rn
                                                                             FROM dfs_usage_pc p,
                                                                                  (SELECT host_name,
                                                                                          target_name,
                                                                                          DECODE (
                                                                                             INSTR (
                                                                                                arc_file_system,
                                                                                                '$ORACLE_SID'),
                                                                                             0, arc_file_system,
                                                                                             REPLACE (
                                                                                                arc_file_system,
                                                                                                '$ORACLE_SID',
                                                                                                SUBSTR (
                                                                                                   target_name,
                                                                                                   1,
                                                                                                   INSTR (
                                                                                                      target_name,
                                                                                                      '_')
                                                                                                   - 1)))
                                                                                             arc_file_system
                                                                                     FROM (SELECT decode(instr(host_name,'.'),0,host_name,substr(host_name,1,instr(host_name,'.')-1)) host_name,
                                                                                                  target_name,
                                                                                                  SUBSTR (
                                                                                                     VALUE,
                                                                                                     DECODE (
                                                                                                        INSTR (
                                                                                                           UPPER (
                                                                                                              VALUE),
                                                                                                           'LOCATION=',
                                                                                                           1),
                                                                                                        0, 1,
                                                                                                        10))
                                                                                                     arc_file_system
                                                                                             FROM sysman.
                                                                                                  mgmt$db_init_params
                                                                                            WHERE target_type IN
                                                                                                     ('oracle_database',
                                                                                                      'oracle_pdb')
                                                                                                  AND ( (name LIKE
                                                                                                            'log_archive_dest%'
                                                                                                         AND name NOT LIKE
                                                                                                                'log_archive_dest_state%')
                                                                                                       OR name =
                                                                                                             'db_recovery_file_dest')
                                                                                                  AND (VALUE
                                                                                                          IS NOT NULL
                                                                                                       OR LENGTH (
                                                                                                             VALUE) >
                                                                                                             0)
                                                                                                  AND UPPER (
                                                                                                         VALUE) NOT LIKE
                                                                                                         'SERVICE=%'
                                                                                                  AND UPPER (
                                                                                                         VALUE) NOT LIKE
                                                                                                         '%USE_DB_RECOVERY_FILE_DEST%')) a
                                                                            WHERE UPPER (
                                                                                     p.host) =
                                                                                     UPPER (
                                                                                        a.
                                                                                        host_name)
                                                                                  AND metric_key_value <>
                                                                                         '/'
                                                                                  AND INSTR (
                                                                                         arc_file_system,
                                                                                         metric_key_value,
                                                                                         1) >
                                                                                         0)
                                                                    WHERE RN = 1)
                                                         ORDER BY LENGTH (
                                                                     metric_key_value) DESC))
                                          WHERE RN = 1) af,
                                        target_list
                                  WHERE target_list.OEM_TARGET_NAME =
                                           af.target_name(+)
    UNION
                                 SELECT NVL (target_name, OEM_TARGET_NAME) target_name,
                                        arch_fra_fs_max_pc
                                   FROM (SELECT target_name,
                                                arc_file_system,
                                                ROUND (VALUE, 1)
                                                   ARCH_FRA_FS_MAX_PC
                                           FROM (SELECT target_name,
                                                        metric_key_value
                                                           arc_file_system,
                                                        VALUE,
                                                        ROW_NUMBER ()
                                                        OVER (
                                                           PARTITION BY target_name
                                                           ORDER BY
                                                              LENGTH (
                                                                 metric_key_value) DESC)
                                                           rn
                                                   FROM (  SELECT target_name,
                                                                  metric_column_label,
                                                                  metric_key_value,
                                                                  VALUE
                                                             FROM (SELECT *
                                                                     FROM (SELECT a.target_name,
                                                                                  collection_time,
                                                                                  metric_column_label,
                                                                                  metric_key_value,
                                                                                  (100
                                                                                   - VALUE)
                                                                                     VALUE,
                                                                                  ROW_NUMBER ()
                                                                                  OVER (
                                                                                     PARTITION BY metric_key_value
                                                                                     ORDER BY
                                                                                        collection_time DESC)
                                                                                     rn
                                                                             FROM dfs_usage_pc p,
                                                                                  (SELECT host_name,
                                                                                          target_name,
                                                                                          DECODE (
                                                                                             INSTR (
                                                                                                arc_file_system,
                                                                                                '$ORACLE_SID'),
                                                                                             0, arc_file_system,
                                                                                             REPLACE (
                                                                                                arc_file_system,
                                                                                                '$ORACLE_SID',
                                                                                                SUBSTR (
                                                                                                   target_name,
                                                                                                   1,
                                                                                                   INSTR (
                                                                                                      target_name,
                                                                                                      '_')
                                                                                                   - 1)))
                                                                                             arc_file_system
                                                                                     FROM (SELECT decode(instr(host_name,'.'),0,host_name,substr(host_name,1,instr(host_name,'.')-1)) host_name,
                                                                                                  target_name,
                                                                                                  SUBSTR (
                                                                                                     VALUE,
                                                                                                     DECODE (
                                                                                                        INSTR (
                                                                                                           UPPER (
                                                                                                              VALUE),
                                                                                                           'LOCATION=',
                                                                                                           1),
                                                                                                        0, 1,
                                                                                                        10))
                                                                                                     arc_file_system
                                                                                             FROM sysman.
                                                                                                  mgmt$db_init_params
                                                                                            WHERE target_type IN
                                                                                                     ('oracle_database',
                                                                                                      'oracle_pdb')
                                                                                                  AND ( (name LIKE
                                                                                                            'log_archive_dest%'
                                                                                                         AND name NOT LIKE
                                                                                                                'log_archive_dest_state%')
                                                                                                       OR name =
                                                                                                             'db_recovery_file_dest')
                                                                                                  AND (VALUE
                                                                                                          IS NOT NULL
                                                                                                       OR LENGTH (
                                                                                                             VALUE) >
                                                                                                             0)
                                                                                                  AND UPPER (
                                                                                                         VALUE) NOT LIKE
                                                                                                         'SERVICE=%'
                                                                                                  AND UPPER (
                                                                                                         VALUE) NOT LIKE
                                                                                                         '%USE_DB_RECOVERY_FILE_DEST%')) a
                                                                            WHERE UPPER (
                                                                                     p.host) =
                                                                                     UPPER (
                                                                                        a.host_name)
                                                                                  AND metric_key_value <>
                                                                                         '/'
                                                                                  AND INSTR (
                                                                                         arc_file_system,
                                                                                         metric_key_value,
                                                                                         1) >
                                                                                         0)
                                                                    WHERE RN = 1)
                                                         ORDER BY LENGTH (
                                                                     metric_key_value) DESC))
                                          WHERE RN = 1) af,
                                        target_list
                                  WHERE target_list.OEM_TARGET_NAME =
                                           af.target_name(+)
                                           )
                       GROUP BY target_name 
                       )
--select * from afs_usage_pc
,db_wait_class
                   AS (SELECT top_wait_event.target target_name,
                                 top_wait_event.metric_key_value
                              || ' ('
                              || top_wait_class.metric_key_value
                              || ')'
                                 top_db_wait
                         FROM (SELECT *
                                 FROM (SELECT target,
                                              metric_key_value,
                                              Avg_PC,
                                              ROW_NUMBER ()
                                              OVER (PARTITION BY target
                                                    ORDER BY AVG_PC DESC)
                                                 rn
                                         FROM (  SELECT 
                                                        entity_name target,
                                                        metric_key_value,
                                                        ROUND (MIN (VALUE), 1)
                                                           Min_PC,
                                                        ROUND (MAX (VALUE), 1)
                                                           Max_PC,
                                                        ROUND (AVG (VALUE), 1)
                                                           AVG_PC
                                                   FROM wait_ev_sec, target_list
                                                  WHERE target_list.OEM_TARGET_NAME =
                                                           wait_ev_sec.entity_name
                                               GROUP BY 
                                                        entity_name,
                                                        metric_key_value))
                                WHERE rn = 1) top_wait_event,
                              (SELECT *
                                 FROM (SELECT target,
                                              metric_key_value,
                                              AVG_PC,
                                              ROW_NUMBER ()
                                              OVER (
                                                 PARTITION BY target
                                                 ORDER BY
                                                    AVG_PC DESC)
                                                 rn
                                         FROM (  SELECT entity_name
                                                           target,
                                                        metric_column_label,
                                                        METRIC_KEY_VALUE,
                                                        ROUND (
                                                           MIN (
                                                              VALUE),
                                                           1)
                                                           Min_PC,
                                                        ROUND (
                                                           MAX (
                                                              VALUE),
                                                           1)
                                                           Max_PC,
                                                        ROUND (
                                                           AVG (
                                                              VALUE),
                                                           1)
                                                           AVG_PC
                                                   FROM sysman.
                                                        gc_metric_values tbs_usage_pc,
                                                        target_list
                                                  WHERE target_list.
                                                        OEM_TARGET_NAME =
                                                           tbs_usage_pc.
                                                           entity_name
                                                        AND entity_type IN
                                                               ('oracle_database',
                                                                'oracle_pdb')
                                                        AND metric_column_label IN
                                                               ('Database Time Spent Waiting (%)')
                                                        AND TRUNC (
                                                               collection_time) =
                                                               TRUNC (
                                                                  SYSDATE)
                                               GROUP BY entity_name,
                                                        metric_column_label,
                                                        METRIC_KEY_VALUE
                                               ORDER BY entity_name,
                                                        AVG_PC DESC,
                                                        METRIC_KEY_VALUE))
                                WHERE rn = 1) top_wait_class
                        WHERE top_wait_class.target = top_wait_event.target)
--select * from db_wait_class
,stby_lag 
    AS (
     select
          target_name
          , MAX( case when column_label = 'Apply Lag (seconds)' then to_number(value) end ) as apply_lag_sec
          , MAX( case when column_label = 'Transport Lag (seconds)' then to_number(value) end ) as transport_lag_sec
          --, collection_timestamp
     from sysman.mgmt$metric_current,
     target_list
     WHERE target_name = OEM_TARGET_NAME
     and metric_name like '%dataguard%'
     and metric_label = 'Data Guard Performance'
     and column_label in ('Apply Lag (seconds)', 'Transport Lag (seconds)' )
     group by target_name--, collection_timestamp
)
--select * from stby_lag
SELECT oem_target_name,
                    LOWER (target_list.HOST) HOST,
                    CPU_Max_PC,
                    CPU_Avg_PC,
                    SWAP_Max_PC,
                    SWAP_Avg_PC,
                    IOPS_Max_PC,
                    IOPS_Avg_PC,
                    TBS_MAX_PC,
                    USAGE_LEVEL,
                    DATA_FS_MAX_PC,
                    ARCH_FRA_FS_MAX_PC,
                    APPLY_LAG_SEC,
                    TRANSPORT_LAG_SEC,
                    TOP_DB_WAIT
               FROM target_list,
                    cpu_pc,
                    swap_pc,
                    iops_pc,
                    tbs_max_pc,
                    tbs_usage_lvl,
                    dfs_max_pc,
                    afs_usage_pc,
                    db_wait_class,
                    stby_lag
              WHERE  target_list.HOST = cpu_pc.host
                    AND target_list.HOST = swap_pc.host
                    AND target_list.HOST = iops_pc.host
                    AND target_list.OEM_TARGET_NAME = tbs_max_pc.entity_name(+)
                    AND target_list.OEM_TARGET_NAME = tbs_usage_lvl.entity_name(+)
                    AND target_list.OEM_TARGET_NAME = dfs_max_pc.target_name(+)
                    AND target_list.OEM_TARGET_NAME = afs_usage_pc.target_name(+)
                    AND target_list.OEM_TARGET_NAME = db_wait_class.target_name(+)
                    AND target_list.OEM_TARGET_NAME = stby_lag.target_name(+)
           ORDER BY 1
