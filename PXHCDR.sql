-- Oracle provided script 
--
--
--
SPO pxhcdr.log
SET DEF ^ TERM OFF ECHO ON VER OFF SERVEROUT ON SIZE 1000000;
REM
REM $Header: 1460440.1 pxhcdr.sql 12.1.09 2013/06/13 carlos.sierra mauro.pagano $
REM
REM Copyright (c) 2000-2013, Oracle Corporation. All rights reserved.
REM
REM AUTHOR
REM   carlos.sierra@oracle.com
REM   mauro.pagano@oracle.com
REM
REM SCRIPT
REM   pxhcdr.sql
REM
REM DESCRIPTION
REM   Parallel Execution Health-Checks and Diagnostics Reports.
REM
REM   This read-only script performs two functions with regard to
REM   system-wide parallel execution:
REM     1. Reports on a set of commonly used health-checks.
REM     2. Generates a set of diagnostics reports based on PX
REM        performance views, PX static views and system tables.
REM
REM   Since pxhcdr.sql is a read-only script, which installs nothing
REM   and updates nothing, it is safe to use on any Oracle database
REM   10g or higher, including Dataguard and read-only systems.
REM
REM PRE-REQUISITES
REM   1. Execute as SYS or user with DBA role or user with access
REM      to data dictionary views.
REM
REM PARAMETERS
REM   1. Oracle Pack license (Tuning or Diagnostics or None) T|D|N
REM   2. Target directory path for output (optional). Default is cuurent.
REM
REM EXECUTION
REM   1. Start SQL*Plus connecting as SYS or user with DBA role or
REM      user with access to data dictionary views.
REM   2. Execute script pxhcdr.sql passing values for parameter.
REM
REM EXAMPLE
REM   # sqlplus / as sysdba
REM   SQL> START [path]pxhcdr.sql [T|D|N] [target_path]
REM
REM NOTES
REM   1. For possible errors see pxhcdr.log.
REM   2. If site has both Tuning and Diagnostics licenses then
REM      specified T (Oracle Tuning pack includes Oracle Diagnostics)
REM
DEF monitor_reports = '25';
DEF small_table_threshold = '1e9';

/**************************************************************************************************/

SET TERM ON ECHO OFF;
PRO
PRO Parameter 1:
PRO Oracle Pack License (Tuning, Diagnostics or None) [T|D|N] (required)
PRO
DEF input_license = '^1';
PRO
PRO Parameter 2:
PRO Target directory path for script output (optional)
PRO
DEF output_path = '^2';
PRO
SET TERM OFF;
COL license NEW_V license FOR A1;

SELECT UPPER(SUBSTR(TRIM('^^input_license.'), 1, 1)) license FROM DUAL;

VAR license CHAR(1);
EXEC :license := '^^license.';

COL full_path NEW_V full_path;
SELECT TRIM('^^output_path.')||CASE
WHEN INSTR('^^output_path.', '/') > 0 THEN '/'
WHEN INSTR('^^output_path.', '\') > 0 THEN '\'
END full_path
FROM DUAL;

COL unique_id NEW_V unique_id FOR A15;
SELECT TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS') unique_id FROM DUAL;

SET TERM ON;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

BEGIN
  IF '^^license.' IS NULL OR '^^license.' NOT IN ('T', 'D', 'N') THEN
    RAISE_APPLICATION_ERROR(-20100, 'Oracle Pack License (Tuning, Diagnostics or None) must be specified as "T" or "D" or "N".');
  END IF;
END;
/

WHENEVER SQLERROR CONTINUE;

PRO Value passed:
PRO ~~~~~~~~~~~~
PRO License: "^^input_license."
PRO

SET ECHO ON TIMI ON;

DEF script = 'pxhcdr';
DEF method = 'PXHCDR';

DEF mos_doc = '1460440.1';
DEF doc_ver = '12.1.09';
DEF doc_date = '2014/06/13';
DEF doc_link = 'https://support.oracle.com/CSP/main/article?cmd=show&type=NOT&id=';
DEF bug_link = 'https://support.oracle.com/CSP/main/article?cmd=show&type=BUG&id=';

-- tracing script in case it takes long to execute so we can diagnose it
ALTER SESSION SET TRACEFILE_IDENTIFIER = "^^script._^^unique_id.";
ALTER SESSION SET STATISTICS_LEVEL = 'ALL';
ALTER SESSION SET EVENTS '10046 TRACE NAME CONTEXT FOREVER, LEVEL 12';

/**************************************************************************************************/

/* -------------------------
 *
 * assembly title
 *
 * ------------------------- */

-- get database name (up to 10, stop before first '.', no special characters)
COL database_name_short NEW_V database_name_short FOR A10;
SELECT SUBSTR(SYS_CONTEXT('USERENV', 'DB_NAME'), 1, 10) database_name_short FROM DUAL;
SELECT SUBSTR('^^database_name_short.', 1, INSTR('^^database_name_short..', '.') - 1) database_name_short FROM DUAL;
SELECT TRANSLATE('^^database_name_short.',
'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ''`~!@#$%^*()-_=+[]{}\|;:",.<>/?'||CHR(0)||CHR(9)||CHR(10)||CHR(13)||CHR(38),
'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789') database_name_short FROM DUAL;

-- get host name (up to 30, stop before first '.', no special characters)
COL host_name_short NEW_V host_name_short FOR A30;
SELECT SUBSTR(SYS_CONTEXT('USERENV', 'SERVER_HOST'), 1, 30) host_name_short FROM DUAL;
SELECT SUBSTR('^^host_name_short.', 1, INSTR('^^host_name_short..', '.') - 1) host_name_short FROM DUAL;
SELECT TRANSLATE('^^host_name_short.',
'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ''`~!@#$%^*()-_=+[]{}\|;:",.<>/?'||CHR(0)||CHR(9)||CHR(10)||CHR(13)||CHR(38),
'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789') host_name_short FROM DUAL;

-- get rdbms version
COL rdbms_version NEW_V rdbms_version FOR A17;
SELECT version rdbms_version FROM v$instance;

-- get platform
COL platform NEW_V platform FOR A80;
SELECT UPPER(TRIM(REPLACE(REPLACE(product, 'TNS for '), ':' ))) platform FROM product_component_version WHERE product LIKE 'TNS for%' AND ROWNUM = 1;

-- get instance
COL instance_number NEW_V instance_number FOR A10;
SELECT TO_CHAR(instance_number) instance_number FROM v$instance;

-- YYYYMMDD_HH24MISS
COL time_stamp NEW_V time_stamp FOR A15;
SELECT TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS') time_stamp FROM DUAL;

-- YYYY-MM-DD/HH24:MI:SS
COL time_stamp2 NEW_V time_stamp2 FOR A20;
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS') time_stamp2 FROM DUAL;

-- get db_block_size
COL sys_db_block_size NEW_V sys_db_block_size FOR A17;
SELECT value sys_db_block_size FROM v$system_parameter2 WHERE LOWER(name) = 'db_block_size';

-- get cpu_count
COL sys_cpu NEW_V sys_cpu FOR A17;
SELECT value sys_cpu FROM v$system_parameter2 WHERE LOWER(name) = 'cpu_count';

-- get ofe
COL sys_ofe NEW_V sys_ofe FOR A17;
SELECT value sys_ofe FROM v$system_parameter2 WHERE LOWER(name) = 'optimizer_features_enable';

-- get ds
COL sys_ds NEW_V sys_ds FOR A10;
SELECT value sys_ds FROM v$system_parameter2 WHERE LOWER(name) = 'optimizer_dynamic_sampling';

/* -------------------------
 *
 * application vendor
 *
 * ------------------------- */

-- ebs
COL is_ebs NEW_V is_ebs FOR A1;
COL ebs_owner NEW_V ebs_owner FOR A30;
SELECT 'Y' is_ebs, owner ebs_owner
  FROM dba_tab_columns
 WHERE table_name = 'FND_PRODUCT_GROUPS'
   AND column_name = 'RELEASE_NAME'
   AND data_type = 'VARCHAR2'
   AND ROWNUM = 1;

-- siebel
COL is_siebel NEW_V is_siebel FOR A1;
COL siebel_owner NEW_V siebel_owner FOR A30;
SELECT 'Y' is_siebel, owner siebel_owner
  FROM dba_tab_columns
 WHERE '^^is_ebs.' IS NULL
   AND table_name = 'S_REPOSITORY'
   AND column_name = 'ROW_ID'
   AND data_type = 'VARCHAR2'
   AND ROWNUM = 1;

-- psft
COL is_psft NEW_V is_psft FOR A1;
COL psft_owner NEW_V psft_owner FOR A30;
SELECT 'Y' is_psft, owner psft_owner
  FROM dba_tab_columns
 WHERE '^^is_ebs.' IS NULL
   AND '^^is_siebel.' IS NULL
   AND table_name = 'PSSTATUS'
   AND column_name = 'TOOLSREL'
   AND data_type = 'VARCHAR2'
   AND ROWNUM = 1;

/**************************************************************************************************/

/* -------------------------
 *
 * main report
 *
 * ------------------------- */

-- setup to produce report
SET ECHO OFF FEED OFF VER OFF SHOW OFF HEA OFF LIN 2000 NEWP NONE PAGES 0 NUM 20 LONG 2000000 LONGC 2000 SQLC MIX TAB ON TRIMS ON TI OFF TIMI OFF ARRAY 100 NUMF "" SQLP SQL> SUF sql BLO . RECSEP OFF APPI OFF AUTOT OFF;

/* -------------------------
 *
 * gv$sql_shared_cursor
 *
 * ------------------------- */
SPO sql_shared_cursor.sql;
PRO SELECT /* ^^script..sql Cursor Sharing as per Reason */
PRO        CHR(10)||'<tr>'||CHR(10)||
PRO        '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
PRO        '<td>'||v2.reason||'</td>'||CHR(10)||
PRO        '<td class="c">'||v2.inst_id||'</td>'||CHR(10)||
PRO        '<td class="r">'||v2.cursors||'</td>'||CHR(10)||
PRO        '</tr>'
PRO   FROM (
SELECT (CASE WHEN ROWNUM > 1 THEN 'UNION ALL'||CHR(10) END)||
       'SELECT '''||v.column_name||''' reason, inst_id, COUNT(*) cursors FROM gv$sql_shared_cursor WHERE '||v.column_name||' = ''Y'' GROUP BY inst_id' line
  FROM (
SELECT /*+ NO_MERGE */
       column_name
  FROM dba_tab_cols
 WHERE owner = 'SYS'
   AND table_name = 'GV_$SQL_SHARED_CURSOR'
   AND data_type = 'VARCHAR2'
   AND data_length = 1
 ORDER BY
       column_name ) v;
PRO ORDER BY reason, inst_id ) v2;;
SPO OFF;

/* -------------------------
 *
 * heading
 *
 * ------------------------- */
SPO ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._main.html;

PRO <html>
PRO <!-- $Header: ^^mos_doc. ^^script..sql ^^doc_ver. ^^doc_date. carlos.sierra $ -->
PRO <!-- Copyright (c) 2000-2012, Oracle Corporation. All rights reserved. -->
PRO <!-- Author: carlos.sierra@oracle.com -->
PRO
PRO <head>
PRO <title>^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._main.html</title>
PRO

PRO <style type="text/css">
PRO body {font:10pt Arial,Helvetica,Verdana,Geneva,sans-serif; color:black; background:white;}
PRO a {font-weight:bold; color:#663300;}
PRO pre {font:8pt Monaco,"Courier New",Courier,monospace;} /* for code */
PRO h1 {font-size:16pt; font-weight:bold; color:#336699;}
PRO h2 {font-size:14pt; font-weight:bold; color:#336699;}
PRO h3 {font-size:12pt; font-weight:bold; color:#336699;}
PRO li {font-size:10pt; font-weight:bold; color:#336699; padding:0.1em 0 0 0;}
PRO table {font-size:8pt; color:black; background:white;}
PRO th {font-weight:bold; background:#cccc99; color:#336699; vertical-align:bottom; padding-left:3pt; padding-right:3pt; padding-top:1pt; padding-bottom:1pt;}
PRO td {text-align:left; background:#fcfcf0; vertical-align:top; padding-left:3pt; padding-right:3pt; padding-top:1pt; padding-bottom:1pt;}
PRO td.c {text-align:center;} /* center */
PRO td.l {text-align:left;} /* left (default) */
PRO td.r {text-align:right;} /* right */
PRO font.n {font-size:8pt; font-style:italic; color:#336699;} /* table footnote in blue */
PRO font.f {font-size:8pt; color:#999999;} /* footnote in gray */
PRO </style>
PRO

PRO </head>
PRO <body>
PRO <h1><a target="MOS" href="^^doc_link.^^mos_doc.">^^mos_doc.</a> ^^method.
PRO ^^doc_ver. Report: ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._main.html</h1>
PRO

PRO <pre>
PRO License   : ^^input_license.
PRO RDBMS     : ^^rdbms_version.
PRO Platform  : ^^platform.
PRO Instance  : ^^instance_number.
PRO CPU Count : ^^sys_cpu.
PRO Block Size: ^^sys_db_block_size.
PRO OFE       : ^^sys_ofe.
PRO DYN_SAMP  : ^^sys_ds.
PRO EBS       : "^^is_ebs."
PRO SIEBEL    : "^^is_siebel."
PRO PSFT      : "^^is_psft."
PRO Date      : ^^time_stamp2.
PRO </pre>

PRO <ul>
PRO <li><a href="#obs">Observations</a></li>
PRO <li><a href="#pdlm">Parallel Degree Limit Method</a></li>
PRO <li><a href="#buf_adv">PX Buffer Advice</a></li>
PRO <li><a href="#pq_syssta">PQ System Statistics</a></li>
PRO <li><a href="#px_syssta">PX System Statistics</a></li>
PRO <li><a href="#par_syssta">System Statistics</a></li>
PRO <li><a href="#pq_slaves">PQ Slaves</a></li>
PRO <li><a href="#px_sess">PX Sessions</a></li>
PRO <li><a href="#services">Services</a></li>
PRO <li><a href="#io_cal">I/O Calibration Results</a></li> <!-- 11g -->
PRO <li><a href="#osstat">Operating System Statistics</a></li>
PRO <li><a href="#sysstat">System Statistics</a></li>
PRO <li><a href="#sysstath">System Statistics History</a></li>
PRO <li><a href="#sgastat">System Global Area (SGA) Statistics</a></li>
PRO <li><a href="#sgastath">System Global Area (SGA) Statistics History</a></li>
PRO <li><a href="#sys_params">System Parameters with Non-Default or Modified Values</a></li>
PRO <li><a href="#inst_params">Instance Parameters</a></li>
PRO <li><a href="#sql_monitor">SQL Monitor</a></li> <!-- 11g -->
PRO <li><a href="#share_vc">Version Count as per Cursor Sharing</a></li>
PRO <li><a href="#share_r">Cursor Sharing and Reason</a></li>
PRO </ul>

/* -------------------------
 *
 * observations
 *
 * ------------------------- */
PRO <a name="obs"></a><h2>Observations</h2>
PRO
PRO Observations below are the outcome of several heath-checks on your system with regard to Parallel Execution (PX).<br>
PRO Review them carefully and take action when appropriate.<br>
PRO Note: Ignore possible errors about dba_rsrc_io_calibrate and gv$io_calibration_status on 10g:
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>Type</th>
PRO <th>Name</th>
PRO <th>Observation</th>
PRO <th>Details</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

-- parallel_instance_group not in services or instance_groups
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td>System Parameter</td>'||CHR(10)||
       '<td>parallel_instance_group</td>'||CHR(10)||
       '<td>Value "'||pig.value||'" on instance '||pig.inst_id||' does not exist as a service or instance group.</td>'||CHR(10)||
       '<td>Unset this parallel_instance_group or verify it matches a valid service or a value in instance_groups parameter.<br>'||CHR(10)||
       'See <a target="MOS" href="^^doc_link.7352775.8">7352775.8</a>, <a target="MOS" href="^^doc_link.750645.1">750645.1</a> and <a target="MOS" href="^^bug_link.13940162">13940162</a>.</td>'||CHR(10)||
       '</tr>'
  FROM gv$system_parameter2 pig
 WHERE LOWER(pig.name) = 'parallel_instance_group'
   AND TRIM(REPLACE(REPLACE(pig.value, ''''), '"')) IS NOT NULL
   AND NOT EXISTS (
SELECT NULL
  FROM gv$services gsv
 WHERE gsv.name = pig.value )
   AND NOT EXISTS (
SELECT NULL
  FROM gv$system_parameter2 igr
 WHERE LOWER(igr.name) = 'instance_groups'
   AND igr.value = pig.value );

SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

-- parallel_instance_group is set or modified to a null value
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td>System Parameter</td>'||CHR(10)||
       '<td>parallel_instance_group</td>'||CHR(10)||
       '<td>A NULL value of this parameter on instance '||pig.inst_id||' is not valid.</td>'||CHR(10)||
       '<td>Unset this parallel_instance_group parameter altogether.</td>'||CHR(10)||
       '</tr>'
  FROM gv$system_parameter2 pig
 WHERE LOWER(pig.name) = 'parallel_instance_group'
   AND TRIM(REPLACE(REPLACE(pig.value, ''''), '"')) IS NULL
   AND (pig.isdefault = 'FALSE' OR pig.ismodified <> 'FALSE');

SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

-- parallel_max_servers > cpu_count * 4 * parallel_threads_per_cpu
WITH
pms AS (SELECT /*+ MATERIALIZE */ inst_id, TO_NUMBER(value) value FROM gv$system_parameter2 WHERE LOWER(name) = 'parallel_max_servers'),
cpc AS (SELECT /*+ MATERIALIZE */ inst_id, TO_NUMBER(value) value FROM gv$system_parameter2 WHERE LOWER(name) = 'cpu_count'),
tpc AS (SELECT /*+ MATERIALIZE */ inst_id, TO_NUMBER(value) value FROM gv$system_parameter2 WHERE LOWER(name) = 'parallel_threads_per_cpu'),
wsp AS (SELECT /*+ MATERIALIZE */ inst_id, CASE WHEN value = 'AUTO' THEN 2 ELSE 1 END value  FROM gv$system_parameter2 WHERE LOWER(name) = 'workarea_size_policy'),
stg AS (SELECT /*+ MATERIALIZE */ inst_id, CASE WHEN value > 0 THEN 4 ELSE NULL END value  FROM gv$system_parameter2 WHERE LOWER(name) = 'sga_target'),
mtg AS (SELECT /*+ MATERIALIZE */ inst_id, CASE WHEN value > 0 THEN 4 ELSE NULL END value  FROM gv$system_parameter2 WHERE LOWER(name) = 'memory_target'),
vrs AS (SELECT /*+ MATERIALIZE */ substr(version,1,4) version from gv$instance)
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td>System Parameter</td>'||CHR(10)||
       '<td>parallel_max_servers</td>'||CHR(10)||
       '<td>A value of '||pms.value||' for this parameter on instance '||pms.inst_id||' seems too high.</td>'||CHR(10)||
       '<td>Consider reducing this value to at most cpu_count * parallel_threads_per_cpu '||CASE WHEN vrs.version >= '11.2' THEN '* 5 * concurrent_parallel_users' ELSE '* 4' END ||'.<br>'||CHR(10)||
       'Current value for cpu_count is '||cpc.value||' and for parallel_threads_per_cpu is '||tpc.value||'.</td>'||CHR(10)||
       '</tr>'
  FROM pms, cpc, tpc, wsp, stg, mtg, vrs
 WHERE pms.inst_id = cpc.inst_id
   AND cpc.inst_id = tpc.inst_id
   AND tpc.inst_id = pms.inst_id
   AND cpc.inst_id = wsp.inst_id
   AND cpc.inst_id = stg.inst_id(+)
   AND cpc.inst_id = mtg.inst_id(+)
   AND pms.value > CASE WHEN vrs.version >= '11.2' THEN cpc.value * 5 * tpc.value * NVL(mtg.value,NVL(stg.value,wsp.value)) ELSE cpc.value * 4 * tpc.value END;

SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

-- parallel_servers_target > 0.75 * parallel_max_servers
WITH
pst AS (SELECT /*+ MATERIALIZE */ inst_id, TO_NUMBER(value) value FROM gv$system_parameter2 WHERE LOWER(name) = 'parallel_servers_target'),
pms AS (SELECT /*+ MATERIALIZE */ inst_id, TO_NUMBER(value) value FROM gv$system_parameter2 WHERE LOWER(name) = 'parallel_max_servers')
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td>System Parameter</td>'||CHR(10)||
       '<td>parallel_servers_target</td>'||CHR(10)||
       '<td>A value of '||pst.value||' for this parameter on instance '||pst.inst_id||' seems too high.</td>'||CHR(10)||
       '<td>Consider reducing this value to at most 0.75 * parallel_max_servers.<br>'||CHR(10)||
       'Current value for parallel_max_servers is '||pms.value||'.</td>'||CHR(10)||
       '</tr>'
  FROM pst, pms
 WHERE pst.inst_id = pms.inst_id
   AND pst.value > 0.75 * pms.value;

SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

-- parallel_adaptive_multi_user is set
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td>System Parameter</td>'||CHR(10)||
       '<td>parallel_adaptive_multi_user</td>'||CHR(10)||
       '<td>Parallel adaptive muti-user is enabled on instance '||amu.inst_id||'.</td>'||CHR(10)||
       '<td>Be aware that degree of parallelism (DOP) may be reduced at time of execution.</td>'||CHR(10)||
       '</tr>'
  FROM gv$system_parameter2 amu
 WHERE LOWER(amu.name) = 'parallel_adaptive_multi_user'
   AND amu.value = 'TRUE';

SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

-- parallel_automatic_tuning is set
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td>System Parameter</td>'||CHR(10)||
       '<td>parallel_automatic_tuning</td>'||CHR(10)||
       '<td>Parallel automatic tuning is enabled on instance '||aut.inst_id||'.</td>'||CHR(10)||
       '<td>This parameter is deprecated as of 10g. Avoid using it.</td>'||CHR(10)||
       '</tr>'
  FROM gv$system_parameter2 aut
 WHERE LOWER(aut.name) = 'parallel_automatic_tuning'
   AND aut.value = 'TRUE';

SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

-- parallel_execution_message_size has different values
WITH
ems AS (SELECT /*+ MATERIALIZE */ MIN(TO_NUMBER(value)) min_value, MAX(TO_NUMBER(value)) max_value FROM gv$system_parameter2 WHERE LOWER(name) = 'parallel_execution_message_size')
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td>System Parameter</td>'||CHR(10)||
       '<td>parallel_execution_message_size</td>'||CHR(10)||
       '<td>Parallel execution message size ranges between '||ems.min_value||' and '||ems.max_value||'.</td>'||CHR(10)||
       '<td>All RAC nodes must have same value. Fix this error immediately.<br>'||CHR(10)||
       'See <a target="MOS" href="^^doc_link.752967.1">752967.1</a>, <a target="MOS" href="^^doc_link.1374088.1">1374088.1</a> and <a target="MOS" href="^^bug_link.7486699">7486699</a>.</td>'||CHR(10)||
       '</tr>'
  FROM ems
 WHERE ems.min_value <> ems.max_value;

SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

-- parallel_execution_message_size < 8K
WITH
ems AS (SELECT /*+ MATERIALIZE */ inst_id, TO_NUMBER(value) value FROM gv$system_parameter2 WHERE LOWER(name) = 'parallel_execution_message_size')
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td>System Parameter</td>'||CHR(10)||
       '<td>parallel_execution_message_size</td>'||CHR(10)||
       '<td>Parallel execution message size of '||ems.value||' in instance '||ems.inst_id||' is too small.</td>'||CHR(10)||
       '<td>A size smaller than 8K may produce message fragmentation "PX Deq: Msg Fragment". Consider increasing the message size.<br>'||CHR(10)||
       'See <a target="MOS" href="^^doc_link.254760.1">254760.1</a> and <a target="MOS" href="^^doc_link.9792010.8">9792010.8</a>.</td>'||CHR(10)||
       '</tr>'
  FROM ems
 WHERE ems.value < 8192;

SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

-- 11g dba_rsrc_io_calibrate
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td>IO Calibration Results</td>'||CHR(10)||
       '<td>dba_rsrc_io_calibrate</td>'||CHR(10)||
       '<td>There seems to be no I/O Calibration results.</td>'||CHR(10)||
       '<td>Consider using DBMS_RESOURCE_MANAGER.CALIBRATE_IO.</td>'||CHR(10)||
       '</tr>'
  FROM dba_rsrc_io_calibrate
 WHERE '^^rdbms_version.' LIKE '11%'
HAVING COUNT(*) = 0;

SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

-- 11g gv$io_calibration_status
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td>IO Calibration Status</td>'||CHR(10)||
       '<td>gv$io_calibration_status</td>'||CHR(10)||
       '<td>'||status||' for instance '||inst_id||'.</td>'||CHR(10)||
       '<td>Time of last calibration: '||calibration_time||'.</td>'||CHR(10)||
       '</tr>'
  FROM gv$io_calibration_status
 ORDER BY
       inst_id;

SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

-- parallel_degree_policy is set to AUTO
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td>System Parameter</td>'||CHR(10)||
       '<td>parallel_degree_policy</td>'||CHR(10)||
       '<td>Parallel degree policy is set to AUTO in '||COUNT(*)||' instance(s).</td>'||CHR(10)||
       '<td>AUTO enables automatic degree of parallelism, statement queuing, and in-memory parallel execution.</td>'||CHR(10)||
       '</tr>'
  FROM gv$system_parameter2 pdp
 WHERE LOWER(pdp.name) = 'parallel_degree_policy'
   AND pdp.value = 'AUTO'
HAVING COUNT(*) > 0;

SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

-- tables < 1G with dop <> 1
WITH
tables AS (
SELECT /*+ MATERIALIZE */
       t.owner,
       t.table_name,
       TRIM(t.degree)table_degree,
       t.blocks,
       t.partitioned tab_part,
       t.temporary
  FROM dba_tables t
 WHERE t.degree IS NOT NULL
   AND TRIM(t.degree) <> '1'
   AND t.blocks * ^^sys_db_block_size. < ^^small_table_threshold.
)
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td>Degree of Parallelism</td>'||CHR(10)||
       '<td>Non-default DOP</td>'||CHR(10)||
       '<td>Schema '||owner||' contains '||COUNT(*)||' small table(s) with DOP set.</td>'||CHR(10)||
       '<td>Setting DOP in small tables (smaller than '||ROUND(^^small_table_threshold./1e9, 3)||' GB) may promote PX plans for which a serial plan may be more convenient. Review DOP report.</td>'||CHR(10)||
       '</tr>'
  FROM tables
 GROUP BY
       owner
 ORDER BY
       owner;

SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

-- tables dop <> indexes dop
WITH
tables_n_indexes AS (
SELECT /*+ MATERIALIZE */
       t.owner,
       t.table_name,
       TRIM(t.degree) table_degree,
       TRIM(t.instances) table_instances,
       t.blocks,
       t.partitioned tab_part,
       t.temporary,
       i.index_name,
       i.index_type,
       TRIM(i.degree) index_degree,
       TRIM(i.instances) index_instances,
       i.leaf_blocks,
       i.partitioned idx_part
  FROM dba_tables t,
       dba_indexes i
 WHERE t.degree IS NOT NULL
   AND i.table_owner = t.owner
   AND i.table_name = t.table_name
   AND i.table_type = 'TABLE'
   AND i.index_type <> 'LOB'
   AND i.degree IS NOT NULL
   AND TRIM(i.degree) <> TRIM(t.degree)
),
tables AS (
SELECT /*+ MATERIALIZE */
       owner,
       table_name
  FROM tables_n_indexes
 GROUP BY
       owner,
       table_name
)
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td>Degree of Parallelism</td>'||CHR(10)||
       '<td>DOP mismatch</td>'||CHR(10)||
       '<td>Schema '||owner||' contains '||COUNT(*)||' table(s) with DOP different than one or more index(es).</td>'||CHR(10)||
       '<td>This DOP mismatch between tables and indexes is more probably by accident. It may produce some unexpected PX plans. Review DOP report.</td>'||CHR(10)||
       '</tr>'
  FROM tables
 GROUP BY
       owner
 ORDER BY
       owner;

PRO
PRO <tr>
PRO <th>Type</th>
PRO <th>Name</th>
PRO <th>Observation</th>
PRO <th>Details</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * parallel degree limit method
 *
 * ------------------------- */
PRO <a name="pdlm"></a><h2>Parallel Degree Limit Method</h2>
PRO
PRO Collected from GV$PARALLEL_DEGREE_LIMIT_MTH.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Name</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td class="c">'||v.inst_id||'</td>'||CHR(10)||
       '<td>'||v.name||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       inst_id,
       name
  FROM gv$parallel_degree_limit_mth
 ORDER BY
       inst_id,
       name ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Name</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * px buffer advice
 *
 * ------------------------- */
PRO <a name="buf_adv"></a><h2>PX Buffer Advice</h2>
PRO
PRO Collected from GV$PX_BUFFER_ADVICE.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Statistic</th>
PRO <th>Value</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td class="c">'||v.inst_id||'</td>'||CHR(10)||
       '<td>'||v.statistic||'</td>'||CHR(10)||
       '<td class="r">'||value||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       inst_id,
       statistic,
       value
  FROM gv$px_buffer_advice
 ORDER BY
       inst_id,
       statistic ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Statistic</th>
PRO <th>Value</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * pq system statistics
 *
 * ------------------------- */
PRO <a name="pq_syssta"></a><h2>PQ System Statistics</h2>
PRO
PRO Collected from GV$PQ_SYSSTAT.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Statistic</th>
PRO <th>Value</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td class="c">'||v.inst_id||'</td>'||CHR(10)||
       '<td>'||v.statistic||'</td>'||CHR(10)||
       '<td class="r">'||v.value||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       inst_id,
       statistic,
       value
  FROM gv$pq_sysstat
 ORDER BY
       inst_id,
       statistic ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Statistic</th>
PRO <th>Value</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * px system statistics
 *
 * ------------------------- */
PRO <a name="px_syssta"></a><h2>PX System Statistics</h2>
PRO
PRO Collected from GV$PX_PROCESS_SYSSTAT.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Statistic</th>
PRO <th>Value</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td class="c">'||v.inst_id||'</td>'||CHR(10)||
       '<td>'||v.statistic||'</td>'||CHR(10)||
       '<td class="r">'||v.value||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       inst_id,
       statistic,
       value
  FROM gv$px_process_sysstat
 ORDER BY
       inst_id,
       statistic ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Statistic</th>
PRO <th>Value</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * system statistics
 *
 * ------------------------- */
PRO <a name="par_syssta"></a><h2>System Statistics</h2>
PRO
PRO Collected from GV$SYSSTAT.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Statistic</th>
PRO <th>Value</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td class="c">'||v.inst_id||'</td>'||CHR(10)||
       '<td>'||v.name||'</td>'||CHR(10)||
       '<td class="r">'||v.value||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       inst_id,
       name,
       value
  FROM gv$sysstat
 ORDER BY
       inst_id,
       name ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Statistic</th>
PRO <th>Value</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * pq slaves
 *
 * ------------------------- */
PRO <a name="pq_slaves"></a><h2>PQ Slaves</h2>
PRO
PRO Collected from GV$PQ_SLAVE.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Slave<br>Name</th>
PRO <th>Status</th>
PRO <th>Sessions</th>
PRO <th>Idle<br>Time<br>Total</th>
PRO <th>Busy<br>Time<br>Total</th>
PRO <th>CPU<br>Secs<br>Total</th>
PRO <th>Msgs<br>Sent<br>Total</th>
PRO <th>Msgs<br>Rcvd<br>Total</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td class="c">'||v.inst_id||'</td>'||CHR(10)||
       '<td>'||v.slave_name||'</td>'||CHR(10)||
       '<td>'||v.status||'</td>'||CHR(10)||
       '<td class="r">'||v.sessions||'</td>'||CHR(10)||
       '<td class="r">'||v.idle_time_total||'</td>'||CHR(10)||
       '<td class="r">'||v.busy_time_total||'</td>'||CHR(10)||
       '<td class="r">'||v.cpu_secs_total||'</td>'||CHR(10)||
       '<td class="r">'||v.msgs_sent_total||'</td>'||CHR(10)||
       '<td class="r">'||v.msgs_rcvd_total||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       inst_id,
       slave_name,
       status,
       sessions,
       idle_time_total,
       busy_time_total,
       cpu_secs_total,
       msgs_sent_total,
       msgs_rcvd_total
  FROM gv$pq_slave
 ORDER BY
       inst_id,
       slave_name ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Slave<br>Name</th>
PRO <th>Status</th>
PRO <th>Sessions</th>
PRO <th>Idle<br>Time<br>Total</th>
PRO <th>Busy<br>Time<br>Total</th>
PRO <th>CPU<br>Secs<br>Total</th>
PRO <th>Msgs<br>Sent<br>Total</th>
PRO <th>Msgs<br>Rcvd<br>Total</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * px sessions
 *
 * ------------------------- */
PRO <a name="px_sess"></a><h2>PX Sessions</h2>
PRO
PRO Collected from GV$PX_SESSION.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>QC<br>SID</th>
PRO <th>Server<br>Name</th>
PRO <th>SID</th>
PRO <th>Serial#</th>
PRO <th>PID</th>
PRO <th>SPID</th>
PRO <th>Server<br>Group</th>
PRO <th>Server<br>Set</th>
PRO <th>Server#</th>
PRO <th>Degree</th>
PRO <th>Req<br>Degree</th>
PRO <th>Wait Event</th>
PRO <th>SQL_ID</th>
PRO <th>Child#</th>
PRO <th>Resource<br>Consumer<br>Group</th>
PRO <th>Module</th>
PRO <th>Action</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT /* ^^script..sql PX Sessions */
       CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       v.line||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       '<td class="c">'||pxs.inst_id||'</td>'||CHR(10)||
       '<td class="c">'||pxs.qcsid||'</td>'||CHR(10)||
       '<td>'||NVL(pxp.server_name, 'QC')||'</td>'||CHR(10)||
       '<td class="c">'||pxs.sid||'</td>'||CHR(10)||
       '<td class="c">'||pxs.serial#||'</td>'||CHR(10)||
       '<td class="c">'||NVL(pxp.pid, pro.pid)||'</td>'||CHR(10)||
       '<td class="c">'||NVL(pxp.spid, pro.spid)||'</td>'||CHR(10)||
       '<td class="r">'||pxs.server_group||'</td>'||CHR(10)||
       '<td class="r">'||pxs.server_set||'</td>'||CHR(10)||
       '<td class="r">'||pxs.server#||'</td>'||CHR(10)||
       '<td class="r">'||pxs.degree||'</td>'||CHR(10)||
       '<td class="r">'||pxs.req_degree||'</td>'||CHR(10)||
       '<td>'||swt.event||'</td>'||CHR(10)||
       '<td class="c">'||ses.sql_id||'</td>'||CHR(10)||
       '<td class="c">'||ses.sql_child_number||'</td>'||CHR(10)||
       '<td>'||ses.resource_consumer_group||'</td>'||CHR(10)||
       '<td>'||ses.module||'</td>'||CHR(10)||
       '<td>'||ses.action||'</td>'||CHR(10)
       line
  FROM gv$px_session pxs,
       gv$px_process pxp,
       gv$session ses,
       gv$process pro,
       gv$session_wait swt
 WHERE pxp.inst_id(+) = pxs.inst_id
   AND pxp.sid(+) = pxs.sid
   AND pxp.serial#(+) = pxs.serial#
   AND ses.inst_id(+) = pxs.inst_id
   AND ses.sid(+) = pxs.sid
   AND ses.serial#(+) = pxs.serial#
   AND ses.saddr(+) = pxs.saddr
   AND pro.inst_id(+) = ses.inst_id
   AND pro.addr(+) = ses.paddr
   AND swt.inst_id(+) = ses.inst_id
   AND swt.sid(+) = ses.sid
 ORDER BY
       pxs.inst_id,
       pxs.qcsid,
       pxs.qcserial# NULLS FIRST,
       pxp.server_name NULLS FIRST ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>QC<br>SID</th>
PRO <th>Server<br>Name</th>
PRO <th>SID</th>
PRO <th>Serial#</th>
PRO <th>PID</th>
PRO <th>SPID</th>
PRO <th>Server<br>Group</th>
PRO <th>Server<br>Set</th>
PRO <th>Server#</th>
PRO <th>Degree</th>
PRO <th>Req<br>Degree</th>
PRO <th>Wait Event</th>
PRO <th>SQL_ID</th>
PRO <th>Child#</th>
PRO <th>Resource<br>Consumer<br>Group</th>
PRO <th>Module</th>
PRO <th>Action</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * services
 *
 * ------------------------- */
PRO <a name="services"></a><h2>Services</h2>
PRO
PRO Collected from GV$SERVICES.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Name</th>
PRO <th>Network Name</th>
PRO <th>Creation Date</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td class="c">'||v.inst_id||'</td>'||CHR(10)||
       '<td>'||v.name||'</td>'||CHR(10)||
       '<td>'||v.network_name||'</td>'||CHR(10)||
       '<td nowrap>'||TO_CHAR(v.creation_date, 'YYYY-MM-DD/HH24:MI:SS')||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       inst_id,
       name,
       network_name,
       creation_date
  FROM gv$services
 ORDER BY
       inst_id,
       name ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Name</th>
PRO <th>Network Name</th>
PRO <th>Creation Date</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * 11g io calibration results
 *
 * ------------------------- */
PRO <a name="io_cal"></a><h2>I/O Calibration Results</h2>
PRO
PRO Collected from DBA_RSRC_IO_CALIBRATE.<br>
PRO Note: Ignore possible errors about dba_rsrc_io_calibrate on 10g:
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Start Time</th>
PRO <th>End Time</th>
PRO <th>Max IO<br>per sec</th>
PRO <th>Max MB<br>per sec</th>
PRO <th>Max MB<br>per sec<br>per proc</th>
PRO <th>Latency</th>
PRO <th>Physical<br>Disks</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td>'||start_time||'</td>'||CHR(10)||
       '<td>'||end_time||'</td>'||CHR(10)||
       '<td class="r">'||max_iops||'</td>'||CHR(10)||
       '<td class="r">'||max_mbps||'</td>'||CHR(10)||
       '<td class="r">'||max_pmbps||'</td>'||CHR(10)||
       '<td class="r">'||latency||'</td>'||CHR(10)||
       '<td class="r">'||num_physical_disks||'</td>'||CHR(10)||
       '</tr>'
  FROM dba_rsrc_io_calibrate;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Start Time</th>
PRO <th>End Time</th>
PRO <th>Max IO<br>per sec</th>
PRO <th>Max MB<br>per sec</th>
PRO <th>Max MB<br>per sec<br>per proc</th>
PRO <th>Latency</th>
PRO <th>Physical<br>Disks</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * os stats
 *
 * ------------------------- */
PRO <a name="osstat"></a><h2>Operating System Statistics</h2>
PRO
PRO Collected from GV$OSSTAT.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (SELECT /*+ NO_MERGE */ * FROM gv$osstat ORDER BY 1, 2, 3) v;
SET HEA OFF PAGES 0 MARK HTML OFF;

/* -------------------------
 *
 * system statitics
 *
 * ------------------------- */
PRO <a name="sysstat"></a><h2>System Statistics</h2>
PRO
PRO Collected from SYS.AUX_STATS$.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Name</th>
PRO <th>Value</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td>'||v.pname||'</td>'||CHR(10)||
       '<td class="r">'||v.pval1||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       pname,
       pval1
  FROM sys.aux_stats$
 WHERE sname = 'SYSSTATS_MAIN'
 ORDER BY
       pname ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Name</th>
PRO <th>Value</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * system statitics history
 *
 * ------------------------- */
PRO <a name="sysstath"></a><h2>System Statistics History</h2>
PRO
PRO Collected from SYS.WRI$_OPTSTAT_AUX_HISTORY.<br>
PRO This section includes data captured by AWR.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Save Time</th>
PRO <th>Name</th>
PRO <th>Value</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td nowrap>'||TO_CHAR(v.savtime, 'YYYY-MM-DD/HH24:MI:SS.FF6')||'</td>'||CHR(10)||
       '<td>'||v.pname||'</td>'||CHR(10)||
       '<td class="r">'||v.pval1||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       savtime,
       pname,
       pval1
  FROM sys.wri$_optstat_aux_history
 WHERE :license IN ('T', 'D')
   AND sname = 'SYSSTATS_MAIN'
 ORDER BY
       savtime DESC,
       pname ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Save Time</th>
PRO <th>Name</th>
PRO <th>Value</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * sgastat
 *
 * ------------------------- */
PRO <a name="sgastat"></a><h2>System Global Area (SGA) Statistics</h2>
PRO
PRO Collected from GV$SGASTAT.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Pool</th>
PRO <th>Name</th>
PRO <th>Bytes</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td class="c">'||v.inst_id||'</td>'||CHR(10)||
       '<td>'||v.pool||'</td>'||CHR(10)||
       '<td>'||v.name||'</td>'||CHR(10)||
       '<td class="r">'||v.bytes||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       inst_id,
       pool,
       name,
       bytes
  FROM gv$sgastat
 ORDER BY
       inst_id,
       pool,
       name ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Pool</th>
PRO <th>Name</th>
PRO <th>Bytes</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * awr sgastat
 *
 * ------------------------- */
PRO <a name="sgastath"></a><h2>System Global Area (SGA) Statistics History</h2>
PRO
PRO Collected from DBA_HIST_SGASTAT.<br>
PRO This section includes data captured by AWR.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Pool</th>
PRO <th>Name</th>
PRO <th>Min Bytes</th>
PRO <th>Max Bytes</th>
PRO <th>Avg Bytes</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td class="c">'||instance_number||'</td>'||CHR(10)||
       '<td>'||pool||'</td>'||CHR(10)||
       '<td>'||name||'</td>'||CHR(10)||
       '<td class="r">'||min_bytes||'</td>'||CHR(10)||
       '<td class="r">'||max_bytes||'</td>'||CHR(10)||
       '<td class="r">'||avg_bytes||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       instance_number,
       pool,
       name,
       MIN(bytes) min_bytes,
       MAX(bytes) max_bytes,
       ROUND(AVG(bytes)) avg_bytes
  FROM dba_hist_sgastat
 WHERE :license IN ('T', 'D')
 GROUP BY
       instance_number,
       pool,
       name
 ORDER BY
       instance_number,
       pool,
       name ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Pool</th>
PRO <th>Name</th>
PRO <th>Min Bytes</th>
PRO <th>Max Bytes</th>
PRO <th>Avg Bytes</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * system parameters
 *
 * ------------------------- */
PRO <a name="sys_params"></a><h2>System Parameters with Non-Default or Modified Values</h2>
PRO
PRO Collected from GV$SYSTEM_PARAMETER2 where isdefault = 'FALSE' OR ismodified != 'FALSE'.<br>
PRO "Is Default" = FALSE means the parameter was set in the spfile.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Name</th>
PRO <th>Inst</th>
PRO <th>Ord</th>
PRO <th>Is<br>Default</th>
PRO <th>Is<br>Modified</th>
PRO <th>Value</th>
PRO <th>Display<br>Value</th>
PRO <th>Description</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT /* ^^script..sql System Parameters */
       CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td>'||v.name||'</td>'||CHR(10)||
       '<td class="c">'||v.inst_id||'</td>'||CHR(10)||
       '<td class="r">'||v.ordinal||'</td>'||CHR(10)||
       '<td>'||v.isdefault||'</td>'||CHR(10)||
       '<td>'||v.ismodified||'</td>'||CHR(10)||
       '<td>'||v.value||'</td>'||CHR(10)||
       '<td>'||DECODE(v.display_value, v.value, NULL, v.display_value)||'</td>'||CHR(10)||
       '<td>'||v.description||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */ *
  FROM gv$system_parameter2
 WHERE (isdefault = 'FALSE' OR ismodified <> 'FALSE')
 ORDER BY
       name,
       inst_id,
       ordinal ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Name</th>
PRO <th>Inst</th>
PRO <th>Ord</th>
PRO <th>Is<br>Default</th>
PRO <th>Is<br>Modified</th>
PRO <th>Value</th>
PRO <th>Display<br>Value</th>
PRO <th>Description</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * instance parameters
 *
 * ------------------------- */
PRO <a name="inst_params"></a><h2>Instance Parameters</h2>
PRO
PRO System Parameters collected from V$SYSTEM_PARAMETER2 for Instance number ^^instance_number..
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Name</th>
PRO <th>Ord</th>
PRO <th>Is<br>Default</th>
PRO <th>Is<br>Modified</th>
PRO <th>Value</th>
PRO <th>Display<br>Value</th>
PRO <th>Description</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT /* ^^script..sql System Parameters */
       CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td>'||v.name||'</td>'||CHR(10)||
       '<td class="r">'||v.ordinal||'</td>'||CHR(10)||
       '<td>'||v.isdefault||'</td>'||CHR(10)||
       '<td>'||v.ismodified||'</td>'||CHR(10)||
       '<td>'||v.value||'</td>'||CHR(10)||
       '<td>'||DECODE(v.display_value, v.value, NULL, v.display_value)||'</td>'||CHR(10)||
       '<td>'||v.description||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */ *
  FROM v$system_parameter2
 ORDER BY
       name,
       ordinal ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Name</th>
PRO <th>Ord</th>
PRO <th>Is<br>Default</th>
PRO <th>Is<br>Modified</th>
PRO <th>Value</th>
PRO <th>Display<br>Value</th>
PRO <th>Description</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * 11g sql monitor
 *
 * ------------------------- */
PRO <a name="sql_monitor"></a><h2>SQL Monitor</h2>
PRO
PRO Collected from GV$SQL_MONITOR where process_name = 'ora' and px_servers_requested > 1.<br>
PRO This section includes data from the Oracle Tuning pack.<br>
PRO Note: Ignore possible errors about gv$sql_monitor on 10g:
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Status</th>
PRO <th>First Refresh</th>
PRO <th>Last Refresh</th>
PRO <th>SQL_ID</th>
PRO <th>Plan<br>Hash<br>Value</th>
PRO <th>PX<br>Max<br>DOP</th>
PRO <th>PX<br>Max<br>DOP<br>Inst</th>
PRO <th>PX<br>Servers<br>Requested</th>
PRO <th>PX<br>Servers<br>Allocated</th>
PRO <th>Elapsed<br>Time<br>(secs)</th>
PRO <th>Queuing<br>Time<br>(secs)</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT /* ^^script..sql SQL Monitor */
       CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td class="c">'||v.inst_id||'</td>'||CHR(10)||
       '<td>'||v.status||'</td>'||CHR(10)||
       '<td nowrap>'||TO_CHAR(v.first_refresh_time, 'YYYY-MM-DD/HH24:MI:SS')||'</td>'||CHR(10)||
       '<td nowrap>'||TO_CHAR(v.last_refresh_time, 'YYYY-MM-DD/HH24:MI:SS')||'</td>'||CHR(10)||
       '<td class="c">'||v.sql_id||'</td>'||CHR(10)||
       '<td class="c">'||v.sql_plan_hash_value||'</td>'||CHR(10)||
       '<td class="c">'||v.px_maxdop||'</td>'||CHR(10)||
       '<td class="c">'||v.px_maxdop_instances||'</td>'||CHR(10)||
       '<td class="c">'||v.px_servers_requested||'</td>'||CHR(10)||
       '<td class="c">'||v.px_servers_allocated||'</td>'||CHR(10)||
       '<td class="r">'||TO_CHAR(ROUND(v.elapsed_time / 1e6, 3), '99999999999990D990')||'</td>'||CHR(10)||
       '<td class="r">'||TO_CHAR(ROUND(v.queuing_time / 1e6, 3), '99999999999990D990')||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */ *
  FROM gv$sql_monitor
 WHERE :license = 'T'
   AND process_name = 'ora'
   AND px_servers_requested > 1
 ORDER BY
       inst_id,
       status,
       first_refresh_time ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Inst</th>
PRO <th>Status</th>
PRO <th>First Refresh</th>
PRO <th>Last Refresh</th>
PRO <th>SQL_ID</th>
PRO <th>Plan<br>Hash<br>Value</th>
PRO <th>PX<br>Max<br>DOP</th>
PRO <th>PX<br>Max<br>DOP<br>Inst</th>
PRO <th>PX<br>Servers<br>Requested</th>
PRO <th>PX<br>Servers<br>Allocated</th>
PRO <th>Elapsed<br>Time<br>(secs)</th>
PRO <th>Queuing<br>Time<br>(secs)</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * version cursor sharing
 *
 * ------------------------- */
PRO <a name="share_vc"></a><h2>Version Count as per Cursor Sharing</h2>
PRO
PRO Collected from GV$SQL_SHARED_CURSOR.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>Inst</th>
PRO <th>Between<br>1 and 4</th>
PRO <th>Between<br>5 and 8</th>
PRO <th>Between<br>9 and 16</th>
PRO <th>Between<br>17 and 32</th>
PRO <th>Between<br>33 and 64</th>
PRO <th>Between<br>65 and 128</th>
PRO <th>Between<br>129 and 256</th>
PRO <th>Between<br>257 and 512</th>
PRO <th>Between<br>513 and 1024</th>
PRO <th>Between<br>1025 and 2048</th>
PRO <th>More Than<br>2048</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

SELECT /* ^^script..sql Version Count as per Cursor Sharing */
       CHR(10)||'<tr>'||CHR(10)||
       '<td class="c">'||v.inst_id||'</td>'||CHR(10)||
       '<td class="r">'||SUM(CASE WHEN v.versions BETWEEN 1 AND 4 THEN 1 ELSE 0 END)||'</td>'||CHR(10)||
       '<td class="r">'||SUM(CASE WHEN v.versions BETWEEN 5 AND 8 THEN 1 ELSE 0 END)||'</td>'||CHR(10)||
       '<td class="r">'||SUM(CASE WHEN v.versions BETWEEN 9 AND 16 THEN 1 ELSE 0 END)||'</td>'||CHR(10)||
       '<td class="r">'||SUM(CASE WHEN v.versions BETWEEN 17 AND 32 THEN 1 ELSE 0 END)||'</td>'||CHR(10)||
       '<td class="r">'||SUM(CASE WHEN v.versions BETWEEN 33 AND 64 THEN 1 ELSE 0 END)||'</td>'||CHR(10)||
       '<td class="r">'||SUM(CASE WHEN v.versions BETWEEN 65 AND 128 THEN 1 ELSE 0 END)||'</td>'||CHR(10)||
       '<td class="r">'||SUM(CASE WHEN v.versions BETWEEN 129 AND 256 THEN 1 ELSE 0 END)||'</td>'||CHR(10)||
       '<td class="r">'||SUM(CASE WHEN v.versions BETWEEN 257 AND 512 THEN 1 ELSE 0 END)||'</td>'||CHR(10)||
       '<td class="r">'||SUM(CASE WHEN v.versions BETWEEN 513 AND 1024 THEN 1 ELSE 0 END)||'</td>'||CHR(10)||
       '<td class="r">'||SUM(CASE WHEN v.versions BETWEEN 1025 AND 2048 THEN 1 ELSE 0 END)||'</td>'||CHR(10)||
       '<td class="r">'||SUM(CASE WHEN v.versions >= 2048 THEN 1 ELSE 0 END)||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       inst_id,
       sql_id,
       COUNT(*) versions
  FROM gv$sql_shared_cursor
 GROUP BY
       inst_id, sql_id ) v
 GROUP BY
       v.inst_id
 ORDER BY
       v.inst_id;

PRO
PRO <tr>
PRO <th>Inst</th>
PRO <th>Between<br>1 and 4</th>
PRO <th>Between<br>5 and 8</th>
PRO <th>Between<br>9 and 16</th>
PRO <th>Between<br>17 and 32</th>
PRO <th>Between<br>33 and 64</th>
PRO <th>Between<br>65 and 128</th>
PRO <th>Between<br>129 and 256</th>
PRO <th>Between<br>257 and 512</th>
PRO <th>Between<br>513 and 1024</th>
PRO <th>Between<br>1025 and 2048</th>
PRO <th>More Than<br>2048</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * cursor sharing reason
 *
 * ------------------------- */
PRO <a name="share_r"></a><h2>Cursor Sharing and Reason</h2>
PRO
PRO Collected from GV$SQL_SHARED_CURSOR.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Reason</th>
PRO <th>Inst</th>
PRO <th>Cursors</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

@sql_shared_cursor.sql;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Reason</th>
PRO <th>Inst</th>
PRO <th>Cursors</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * footer
 *
 * ------------------------- */
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <hr size="3">
PRO <font class="f">^^mos_doc. ^^method. ^^doc_ver. ^^time_stamp2.</font>
PRO </body>
PRO </html>

SPO OFF;

/**************************************************************************************************/

/* -------------------------
 *
 * dop report
 *
 * ------------------------- */

-- setup to produce report
SET ECHO OFF FEED OFF VER OFF SHOW OFF HEA OFF LIN 2000 NEWP NONE PAGES 0 NUM 20 LONG 2000000 LONGC 2000 SQLC MIX TAB ON TRIMS ON TI OFF TIMI OFF ARRAY 100 NUMF "" SQLP SQL> SUF sql BLO . RECSEP OFF APPI OFF AUTOT OFF;

/* -------------------------
 *
 * heading
 *
 * ------------------------- */
SPO ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._dop.html;

PRO <html>
PRO <!-- $Header: ^^mos_doc. ^^script..sql ^^doc_ver. ^^doc_date. carlos.sierra $ -->
PRO <!-- Copyright (c) 2000-2012, Oracle Corporation. All rights reserved. -->
PRO <!-- Author: carlos.sierra@oracle.com -->
PRO
PRO <head>
PRO <title>^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._dop.html</title>
PRO

PRO <style type="text/css">
PRO body {font:10pt Arial,Helvetica,Verdana,Geneva,sans-serif; color:black; background:white;}
PRO a {font-weight:bold; color:#663300;}
PRO pre {font:8pt Monaco,"Courier New",Courier,monospace;} /* for code */
PRO h1 {font-size:16pt; font-weight:bold; color:#336699;}
PRO h2 {font-size:14pt; font-weight:bold; color:#336699;}
PRO h3 {font-size:12pt; font-weight:bold; color:#336699;}
PRO li {font-size:10pt; font-weight:bold; color:#336699; padding:0.1em 0 0 0;}
PRO table {font-size:8pt; color:black; background:white;}
PRO th {font-weight:bold; background:#cccc99; color:#336699; vertical-align:bottom; padding-left:3pt; padding-right:3pt; padding-top:1pt; padding-bottom:1pt;}
PRO td {text-align:left; background:#fcfcf0; vertical-align:top; padding-left:3pt; padding-right:3pt; padding-top:1pt; padding-bottom:1pt;}
PRO td.c {text-align:center;} /* center */
PRO td.l {text-align:left;} /* left (default) */
PRO td.r {text-align:right;} /* right */
PRO font.n {font-size:8pt; font-style:italic; color:#336699;} /* table footnote in blue */
PRO font.f {font-size:8pt; color:#999999;} /* footnote in gray */
PRO </style>
PRO

PRO </head>
PRO <body>
PRO <h1><a target="MOS" href="^^doc_link.^^mos_doc.">^^mos_doc.</a> ^^method.
PRO ^^doc_ver. Report: ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._dop.html</h1>
PRO

PRO <pre>
PRO License   : ^^input_license.
PRO RDBMS     : ^^rdbms_version.
PRO Platform  : ^^platform.
PRO Instance  : ^^instance_number.
PRO CPU Count : ^^sys_cpu.
PRO Block Size: ^^sys_db_block_size.
PRO OFE       : ^^sys_ofe.
PRO DYN_SAMP  : ^^sys_ds.
PRO EBS       : "^^is_ebs."
PRO SIEBEL    : "^^is_siebel."
PRO PSFT      : "^^is_psft."
PRO Date      : ^^time_stamp2.
PRO </pre>

PRO <ul>
PRO <li><a href="#dop1">Tables with non-default DOP</a></li>
PRO <li><a href="#mismatch">Tables and Indexes with DOP mismatch</a></li>
PRO </ul>

/* -------------------------
 *
 * tables with dop <> 1
 *
 * ------------------------- */
PRO <a name="dop1"></a><h2>Tables with non-default DOP</h2>
PRO
PRO Collected from DBA_TABLES where degree != 1.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Owner</th>
PRO <th>Table</th>
PRO <th>DOP</th>
PRO <th>Inst</th>
PRO <th>Blocks</th>
PRO <th>MB</th>
PRO <th>GB</th>
PRO <th>Part</th>
PRO <th>Temp</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

WITH
tables AS (
SELECT /*+ MATERIALIZE */
       t.owner,
       t.table_name,
       TRIM(t.degree) table_degree,
       TRIM(t.instances) table_instances,
       t.blocks,
       ROUND(t.blocks * ^^sys_db_block_size. / 1e6) tab_mb,
       ROUND(t.blocks * ^^sys_db_block_size. / 1e9) tab_gb,
       t.partitioned tab_part,
       t.temporary
  FROM dba_tables t
 WHERE t.degree IS NOT NULL
   AND TRIM(t.degree) <> '1'
)
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td>'||v.owner||'</td>'||CHR(10)||
       '<td>'||v.table_name||'</td>'||CHR(10)||
       '<td class="c">'||v.table_degree||'</td>'||CHR(10)||
       '<td class="c">'||v.table_instances||'</td>'||CHR(10)||
       '<td class="r">'||v.blocks||'</td>'||CHR(10)||
       '<td class="r">'||v.tab_mb||'</td>'||CHR(10)||
       '<td class="r">'||v.tab_gb||'</td>'||CHR(10)||
       '<td class="c">'||v.tab_part||'</td>'||CHR(10)||
       '<td class="c">'||v.temporary||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       *
  FROM tables
 ORDER BY
       owner,
       table_name ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Owner</th>
PRO <th>Table</th>
PRO <th>DOP</th>
PRO <th>Inst</th>
PRO <th>Blocks</th>
PRO <th>MB</th>
PRO <th>GB</th>
PRO <th>Part</th>
PRO <th>Temp</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * tables dop <> indexes dop
 *
 * ------------------------- */
PRO <a name="mismatch"></a><h2>Tables and Indexes with DOP mismatch</h2>
PRO
PRO Collected from DBA_TABLES and DBA_INDEXES where t.degree != i.degree.
PRO
PRO <table>
PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Owner</th>
PRO <th>Table</th>
PRO <th>DOP</th>
PRO <th>Inst</th>
PRO <th>Blocks</th>
PRO <th>MB</th>
PRO <th>GB</th>
PRO <th>Part</th>
PRO <th>Temp</th>
PRO <th>Index</th>
PRO <th>Type</th>
PRO <th>DOP</th>
PRO <th>Inst</th>
PRO <th>Leaf<br>Blocks</th>
PRO <th>MB</th>
PRO <th>GB</th>
PRO <th>Part</th>
PRO </tr>
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <!-- Please Wait -->

WITH
tables_n_indexes AS (
SELECT /*+ MATERIALIZE */
       t.owner,
       t.table_name,
       TRIM(t.degree) table_degree,
       TRIM(t.instances) table_instances,
       t.blocks,
       ROUND(t.blocks * ^^sys_db_block_size. / 1e6) tab_mb,
       ROUND(t.blocks * ^^sys_db_block_size. / 1e9) tab_gb,
       t.partitioned tab_part,
       t.temporary,
       i.index_name,
       i.index_type,
       TRIM(i.degree) index_degree,
       TRIM(i.instances) index_instances,
       i.leaf_blocks,
       ROUND(i.leaf_blocks * ^^sys_db_block_size. / 1e6) idx_mb,
       ROUND(i.leaf_blocks * ^^sys_db_block_size. / 1e9) idx_gb,
       i.partitioned idx_part
  FROM dba_tables t,
       dba_indexes i
 WHERE t.degree IS NOT NULL
   AND i.table_owner = t.owner
   AND i.table_name = t.table_name
   AND i.table_type = 'TABLE'
   AND i.index_type <> 'LOB'
   AND i.degree IS NOT NULL
   AND TRIM(i.degree) <> TRIM(t.degree)
)
SELECT CHR(10)||'<tr>'||CHR(10)||
       '<td class="r">'||ROWNUM||'</td>'||CHR(10)||
       '<td>'||v.owner||'</td>'||CHR(10)||
       '<td>'||v.table_name||'</td>'||CHR(10)||
       '<td class="c">'||v.table_degree||'</td>'||CHR(10)||
       '<td class="c">'||v.table_instances||'</td>'||CHR(10)||
       '<td class="r">'||v.blocks||'</td>'||CHR(10)||
       '<td class="r">'||v.tab_mb||'</td>'||CHR(10)||
       '<td class="r">'||v.tab_gb||'</td>'||CHR(10)||
       '<td class="c">'||v.tab_part||'</td>'||CHR(10)||
       '<td class="c">'||v.temporary||'</td>'||CHR(10)||
       '<td>'||v.index_name||'</td>'||CHR(10)||
       '<td>'||v.index_type||'</td>'||CHR(10)||
       '<td class="c">'||v.index_degree||'</td>'||CHR(10)||
       '<td class="c">'||v.index_instances||'</td>'||CHR(10)||
       '<td class="r">'||v.leaf_blocks||'</td>'||CHR(10)||
       '<td class="r">'||v.idx_mb||'</td>'||CHR(10)||
       '<td class="r">'||v.idx_gb||'</td>'||CHR(10)||
       '<td class="c">'||v.idx_part||'</td>'||CHR(10)||
       '</tr>'
  FROM (
SELECT /*+ NO_MERGE */
       *
  FROM tables_n_indexes
 ORDER BY
       owner,
       table_name,
       index_name ) v;

PRO
PRO <tr>
PRO <th>#</th>
PRO <th>Owner</th>
PRO <th>Table</th>
PRO <th>DOP</th>
PRO <th>Inst</th>
PRO <th>Blocks</th>
PRO <th>MB</th>
PRO <th>GB</th>
PRO <th>Part</th>
PRO <th>Temp</th>
PRO <th>Index</th>
PRO <th>Type</th>
PRO <th>DOP</th>
PRO <th>Inst</th>
PRO <th>Leaf<br>Blocks</th>
PRO <th>MB</th>
PRO <th>GB</th>
PRO <th>Part</th>
PRO </tr>
PRO
PRO </table>
PRO

/* -------------------------
 *
 * footer
 *
 * ------------------------- */
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <hr size="3">
PRO <font class="f">^^mos_doc. ^^method. ^^doc_ver. ^^time_stamp2.</font>
PRO </body>
PRO </html>

SPO OFF;

/**************************************************************************************************/

/* -------------------------
 *
 * rsc report
 *
 * ------------------------- */

-- setup to produce report
SET ECHO OFF FEED OFF VER OFF SHOW OFF HEA OFF LIN 2000 NEWP NONE PAGES 0 NUM 20 LONG 2000000 LONGC 2000 SQLC MIX TAB ON TRIMS ON TI OFF TIMI OFF ARRAY 100 NUMF "" SQLP SQL> SUF sql BLO . RECSEP OFF APPI OFF AUTOT OFF;

-- default date formats
ALTER SESSION SET nls_date_format = 'YYYY-MM-DD/HH24:MI:SS';
ALTER SESSION SET nls_timestamp_format = 'YYYY-MM-DD/HH24:MI:SS.FF';
ALTER SESSION SET nls_timestamp_tz_format = 'YYYY-MM-DD/HH24:MI:SS.FF TZH:TZM';

/* -------------------------
 *
 * heading
 *
 * ------------------------- */
SPO ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._rscr.html;

PRO <html>
PRO <!-- $Header: ^^mos_doc. ^^script..sql ^^doc_ver. ^^doc_date. carlos.sierra $ -->
PRO <!-- Copyright (c) 2000-2012, Oracle Corporation. All rights reserved. -->
PRO <!-- Author: carlos.sierra@oracle.com -->
PRO
PRO <head>
PRO <title>^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._rscr.html</title>
PRO

PRO <style type="text/css">
PRO body {font:10pt Arial,Helvetica,Verdana,Geneva,sans-serif; color:black; background:white;}
PRO a {font-weight:bold; color:#663300;}
PRO pre {font:8pt Monaco,"Courier New",Courier,monospace;} /* for code */
PRO h1 {font-size:16pt; font-weight:bold; color:#336699;}
PRO h2 {font-size:14pt; font-weight:bold; color:#336699;}
PRO h3 {font-size:12pt; font-weight:bold; color:#336699;}
PRO li {font-size:10pt; font-weight:bold; color:#336699; padding:0.1em 0 0 0;}
PRO table {font-size:8pt; color:black; background:white;}
PRO th {font-weight:bold; background:#cccc99; color:#336699; vertical-align:bottom; padding-left:3pt; padding-right:3pt; padding-top:1pt; padding-bottom:1pt;}
PRO td {text-align:left; background:#fcfcf0; vertical-align:top; padding-left:3pt; padding-right:3pt; padding-top:1pt; padding-bottom:1pt;}
PRO td.c {text-align:center;} /* center */
PRO td.l {text-align:left;} /* left (default) */
PRO td.r {text-align:right;} /* right */
PRO font.n {font-size:8pt; font-style:italic; color:#336699;} /* table footnote in blue */
PRO font.f {font-size:8pt; color:#999999;} /* footnote in gray */
PRO </style>
PRO

PRO </head>
PRO <body>
PRO <h1><a target="MOS" href="^^doc_link.^^mos_doc.">^^mos_doc.</a> ^^method.
PRO ^^doc_ver. Report: ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._rscr.html</h1>
PRO

PRO <pre>
PRO License   : ^^input_license.
PRO RDBMS     : ^^rdbms_version.
PRO Platform  : ^^platform.
PRO Instance  : ^^instance_number.
PRO CPU Count : ^^sys_cpu.
PRO Block Size: ^^sys_db_block_size.
PRO OFE       : ^^sys_ofe.
PRO DYN_SAMP  : ^^sys_ds.
PRO EBS       : "^^is_ebs."
PRO SIEBEL    : "^^is_siebel."
PRO PSFT      : "^^is_psft."
PRO Date      : ^^time_stamp2.
PRO </pre>

PRO <ul>
PRO <li><a href="#users">Default Resource Consumer Group and Profile per User</a></li>
PRO <li><a href="#profiles">Resource Profiles</a></li>
PRO <li><a href="#sessions">Sessions per Resource Consumer Group</a></li>
PRO <li><a href="#rsrc_plan">Active Resource Plans</a></li>
PRO <li><a href="#rsrc_plan_h">Active Resource Plans History</a></li>
PRO <li><a href="#rsrc_group">Active Resource Consumer Groups</a></li>
PRO <li><a href="#rsrc_group_h">Active Resource Consumer Groups History</a></li>
PRO <li><a href="#rsrc_plans">Resource Plans</a></li>
PRO <li><a href="#rsrc_groups">Resource Consumer Groups</a></li>
PRO <li><a href="#rsrc_directives">Resource Plan Directives</a></li>
PRO <li><a href="#rsrc_group_privs">Resource Consumer Group Privileges</a></li>
PRO <li><a href="#rsrc_group_map">Resource Group Mappings</a></li>
PRO <li><a href="#rsrc_map_priority">Resource Mapping Priority</a></li>
PRO </ul>

/* -------------------------
 *
 * dba_users
 *
 * ------------------------- */
PRO <a name="users"></a><h2>Default Resource Consumer Group and Profile per User</h2>
PRO
PRO Collected from DBA_USERS.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (
SELECT /*+ NO_MERGE */
       username,
       initial_rsrc_consumer_group,
       profile
  FROM dba_users
 ORDER BY
       username ) v;
SET HEA OFF PAGES 0 MARK HTML OFF;

/* -------------------------
 *
 * dba_profiles
 *
 * ------------------------- */
PRO <a name="profiles"></a><h2>Resource Profiles</h2>
PRO
PRO Collected from DBA_PROFILES.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (SELECT /*+ NO_MERGE */ * FROM dba_profiles ORDER BY 1, 2, 3) v;
SET HEA OFF PAGES 0 MARK HTML OFF;

/* -------------------------
 *
 * gv$session
 *
 * ------------------------- */
PRO <a name="sessions"></a><h2>Sessions per Resource Consumer Group</h2>
PRO
PRO Collected from GV$SESSION.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (
SELECT /*+ NO_MERGE */
       inst_id,
       type,
       username,
       status,
       resource_consumer_group,
       COUNT(*)
  FROM gv$session
 GROUP BY
       inst_id,
       type,
       username,
       status,
       resource_consumer_group
 ORDER BY
       inst_id,
       type,
       username,
       status,
       resource_consumer_group ) v;
SET HEA OFF PAGES 0 MARK HTML OFF;

/* -------------------------
 *
 * gv$rsrc_plan
 *
 * ------------------------- */
PRO <a name="rsrc_plan"></a><h2>Active Resource Plans</h2>
PRO
PRO Collected from GV$RSRC_PLAN.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (SELECT /*+ NO_MERGE */ * FROM gv$rsrc_plan ORDER BY 1, 2, 3) v;
SET HEA OFF PAGES 0 MARK HTML OFF;

/* -------------------------
 *
 * gv$rsrc_plan_history
 *
 * ------------------------- */
PRO <a name="rsrc_plan_h"></a><h2>Active Resource Plans History</h2>
PRO
PRO Collected from GV$RSRC_PLAN_HISTORY.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (SELECT /*+ NO_MERGE */ * FROM gv$rsrc_plan_history ORDER BY 1, 2, 3, 4, 5) v;
SET HEA OFF PAGES 0 MARK HTML OFF;

/* -------------------------
 *
 * gv$rsrc_consumer_group
 *
 * ------------------------- */
PRO <a name="rsrc_group"></a><h2>Active Resource Consumer Groups</h2>
PRO
PRO Collected from GV$RSRC_CONSUMER_GROUP.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (SELECT /*+ NO_MERGE */ * FROM gv$rsrc_consumer_group ORDER BY 1, 2, 3) v;
SET HEA OFF PAGES 0 MARK HTML OFF;

/* -------------------------
 *
 * gv$rsrc_cons_group_history
 *
 * ------------------------- */
PRO <a name="rsrc_group_h"></a><h2>Active Resource Consumer Groups History</h2>
PRO
PRO Collected from GV$RSRC_CONS_GROUP_HISTORY.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (SELECT /*+ NO_MERGE */ * FROM gv$rsrc_cons_group_history ORDER BY 1, 2, 3, 4) v;
SET HEA OFF PAGES 0 MARK HTML OFF;

/* -------------------------
 *
 * dba_rsrc_plans
 *
 * ------------------------- */
PRO <a name="rsrc_plans"></a><h2>Resource Plans</h2>
PRO
PRO Collected from DBA_RSRC_PLANS.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (SELECT /*+ NO_MERGE */ * FROM dba_rsrc_plans ORDER BY 1, 2, 3) v;
SET HEA OFF PAGES 0 MARK HTML OFF;

/* -------------------------
 *
 * dba_rsrc_consumer_groups
 *
 * ------------------------- */
PRO <a name="rsrc_groups"></a><h2>Resource Consumer Groups</h2>
PRO
PRO Collected from DBA_RSRC_CONSUMER_GROUPS.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (SELECT /*+ NO_MERGE */ * FROM dba_rsrc_consumer_groups ORDER BY 1, 2, 3) v;
SET HEA OFF PAGES 0 MARK HTML OFF;

/* -------------------------
 *
 * dba_rsrc_plan_directives
 *
 * ------------------------- */
PRO <a name="rsrc_directives"></a><h2>Resource Plan Directives</h2>
PRO
PRO Collected from DBA_RSRC_PLAN_DIRECTIVES.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (SELECT /*+ NO_MERGE */ * FROM dba_rsrc_plan_directives ORDER BY 1, 2, 3) v;
SET HEA OFF PAGES 0 MARK HTML OFF;

/* -------------------------
 *
 * dba_rsrc_consumer_group_privs
 *
 * ------------------------- */
PRO <a name="rsrc_group_privs"></a><h2>Resource Consumer Group Privileges</h2>
PRO
PRO Collected from DBA_RSRC_CONSUMER_GROUP_PRIVS.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (SELECT /*+ NO_MERGE */ * FROM dba_rsrc_consumer_group_privs ORDER BY 1, 2, 3) v;
SET HEA OFF PAGES 0 MARK HTML OFF;

/* -------------------------
 *
 * dba_rsrc_group_mappings
 *
 * ------------------------- */
PRO <a name="rsrc_group_map"></a><h2>Resource Group Mappings</h2>
PRO
PRO Collected from DBA_RSRC_GROUP_MAPPINGS.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (SELECT /*+ NO_MERGE */ * FROM dba_rsrc_group_mappings ORDER BY 1, 2, 3) v;
SET HEA OFF PAGES 0 MARK HTML OFF;

/* -------------------------
 *
 * dba_rsrc_mapping_priority
 *
 * ------------------------- */
PRO <a name="rsrc_map_priority"></a><h2>Resource Mapping Priority</h2>
PRO
PRO Collected from DBA_RSRC_MAPPING_PRIORITY.
PRO

SET HEA ON PAGES 50 MARK HTML ON TABLE "" SPOOL OFF;
SELECT ROWNUM "#", v.* FROM (SELECT /*+ NO_MERGE */ * FROM dba_rsrc_mapping_priority ORDER BY 1, 2, 3) v;
SET HEA OFF PAGES 0 MARK HTML OFF;


/* -------------------------
 *
 * footer
 *
 * ------------------------- */
PRO
SELECT '<!-- '||TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS')||' -->' FROM dual;
PRO <hr size="3">
PRO <font class="f">^^mos_doc. ^^method. ^^doc_ver. ^^time_stamp2.</font>
PRO </body>
PRO </html>

SPO OFF;

/**************************************************************************************************/

/* -------------------------
 *
 * 11g sql monitor report
 *
 * ------------------------- */
PRO SQL Monitor Report
PRO
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD/HH24:MI:SS') FROM dual;
PRO Please Wait

SPO ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._monitor.sql;

DECLARE
  l_count NUMBER := 0;
  TYPE mon_rt IS RECORD (
    sql_id VARCHAR2(13),
    status VARCHAR2(4000),
    elapsed_time NUMBER,
    queuing_time NUMBER );
  mon_rec mon_rt;
  mon_cv SYS_REFCURSOR;
BEGIN
  IF :license = 'T' AND '^^rdbms_version.' >= '11.2' THEN
    DBMS_OUTPUT.PUT_LINE('-- Generating up to ^^monitor_reports. SQL Monitor Reports for PX statements.');
    DBMS_OUTPUT.PUT_LINE('VAR mon CLOB;');
    DBMS_OUTPUT.PUT_LINE('VAR sql_id VARCHAR2(13);');
    DBMS_OUTPUT.PUT_LINE('SET ECHO OFF FEED OFF VER OFF SHOW OFF HEA OFF LIN 2000 NEWP NONE PAGES 0 NUM 20 LONG 2000000 LONGC 2000 SQLC MIX TAB ON TRIMS ON TI OFF TIMI OFF ARRAY 100 NUMF "" SQLP SQL> SUF sql BLO . RECSEP OFF APPI OFF AUTOT OFF;');

    -- cursor variable to avoid error on 10g since v$sql_monitor didn't exist then
    OPEN mon_cv FOR
      'SELECT sql_id, '||
      '       MIN(DECODE(status, ''EXECUTING'', 1, ''QUEUED'', 2, 3)) status, '||
      '       MAX(elapsed_time) elapsed_time, '||
      '       MAX(queuing_time) queuing_time '||
      '  FROM gv$sql_monitor /* 11g */ '||
      ' WHERE process_name = ''ora'' '||
      '   AND px_servers_requested > 1 '||
      ' GROUP BY '||
      '       sql_id '||
      ' ORDER BY '||
      '       2, '||
      '       3 DESC, '||
      '       4 DESC ';
    LOOP
      FETCH mon_cv INTO mon_rec;
      EXIT WHEN mon_cv%NOTFOUND;

      l_count := l_count + 1;
      IF l_count = ^^monitor_reports. THEN
        EXIT; -- exits loop
      END IF;

      DBMS_OUTPUT.PUT_LINE('EXEC :sql_id := '''||mon_rec.sql_id||''';');
      DBMS_OUTPUT.PUT_LINE('BEGIN');
      DBMS_OUTPUT.PUT_LINE('  :mon := DBMS_SQLTUNE.REPORT_SQL_MONITOR (');
      DBMS_OUTPUT.PUT_LINE('    sql_id       => :sql_id,');
      DBMS_OUTPUT.PUT_LINE('    report_level => ''ALL'',');
      DBMS_OUTPUT.PUT_LINE('    type         => ''ACTIVE'' );');
      DBMS_OUTPUT.PUT_LINE('END;');
      DBMS_OUTPUT.PUT_LINE('/');
      DBMS_OUTPUT.PUT_LINE('SPO ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._'||mon_rec.sql_id||'_^^time_stamp._monitor.html;');
      DBMS_OUTPUT.PUT_LINE('SELECT :mon FROM DUAL;');
      DBMS_OUTPUT.PUT_LINE('SPO OFF;');
    END LOOP;
    CLOSE mon_cv;
  ELSE
    DBMS_OUTPUT.PUT_LINE('-- SQL Monitor Reports are available on 11.2 and higher, and they are part of the Oracle Tuning pack.');
  END IF;
END;
/

SPO OFF;

-- 11g
@^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._monitor.sql

/**************************************************************************************************/

/* -------------------------
 *
 * wrap up
 *
 * ------------------------- */

-- turing trace off
ALTER SESSION SET SQL_TRACE = FALSE;
ALTER SESSION SET STATISTICS_LEVEL = 'TYPICAL';

-- get udump directory path
COL udump_path NEW_V udump_path FOR A500;
SELECT value||DECODE(INSTR(value, '/'), 0, '\', '/') udump_path FROM v$parameter2 WHERE name = 'user_dump_dest';

-- tkprof for trace from execution of tool in case someone reports slow performance in tool
HOS tkprof ^^udump_path.*^^script._^^unique_id.*.trc ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._tkprof_from_tool_exec.txt

-- log zip
HOS zip -mT ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._log.zip ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._tkprof_from_tool_exec.txt
HOS zip -mT ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._log.zip sql_shared_cursor.sql
HOS zip -mT ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._log.zip ^^script..log
-- 11g
HOS zip -mT ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._log.zip ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._monitor.sql

-- 11g monitor zip
HOS zip -mT ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp._monitor.zip ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._*^^time_stamp._monitor.*

-- main zip
HOS zip -mT ^^full_path.^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp..zip ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._*^^time_stamp.*

-- end
SET TERM ON ECHO OFF FEED 6 VER ON SHOW OFF HEA ON LIN 80 NEWP 1 PAGES 14 NUM 10 LONG 80 LONGC 80 SQLC MIX TAB ON TRIMS OFF TI OFF TIMI OFF ARRAY 15 NUMF "" SQLP SQL> SUF sql BLO . RECSEP WR APPI OFF SERVEROUT OFF AUTOT OFF;
PRO
PRO ^^method. zip file has been created:
PRO ^^script._^^database_name_short._^^host_name_short._^^rdbms_version._^^time_stamp..zip.
PRO
CL COL;
SET DEF ON;
UNDEFINE 1 2 method script mos_doc doc_ver doc_date doc_link bug_link input_sql_id input_license input_event_10053 unique_id sql_id signature signaturef license event_10053 udump_path;
