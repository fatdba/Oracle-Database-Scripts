/*
================================================================================
 Script  : lockingmother_v2.sql
 Purpose : RAC-aware Oracle row-lock contention and blocking analysis
 Author  : Prashant "The FatDBA"
 Version : 2.2 (27-Aug-2026)

 Required privileges (direct grants or equivalent catalog role):
   GV_$SESSION, GV_$LOCK, GV_$SQLAREA, GV_$OPEN_CURSOR, GV_$INSTANCE,
   GV_$TRANSACTION, V_$INSTANCE, V_$DATABASE, DBA_OBJECTS

 Notes:
   - Run from SQL*Plus or SQLcl.
   - All instance/session identifiers are displayed as INST_ID:SID.
   - A blocker value of 2 in GV$LOCK means a remote/RAC blocker.
================================================================================
*/

CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES

SET ECHO OFF
SET VERIFY OFF
SET FEEDBACK ON
SET HEADING ON
SET PAGESIZE 100
SET LINESIZE 250
SET TAB OFF
SET TRIMOUT ON
SET TRIMSPOOL ON
SET WRAP ON
SET SQLBLANKLINES ON
SET COLSEP ' | '
SET NULL '-'

SET TERMOUT OFF
COLUMN report_instance  NEW_VALUE report_instance  NOPRINT
COLUMN report_database  NEW_VALUE report_database  NOPRINT
COLUMN report_db_unique NEW_VALUE report_db_unique NOPRINT
COLUMN report_time      NEW_VALUE report_time      NOPRINT
COLUMN reporter_inst_id NEW_VALUE reporter_inst_id NOPRINT
COLUMN reporter_sid     NEW_VALUE reporter_sid     NOPRINT
COLUMN reporter_prevsql NEW_VALUE reporter_prevsql NOPRINT

/* Capture the SQL executed immediately before this script. This is important
   when the report is run from a session that is itself holding the lock. */
SELECT TO_CHAR(SYS_CONTEXT('USERENV', 'INSTANCE')) AS reporter_inst_id,
       TO_CHAR(SYS_CONTEXT('USERENV', 'SID')) AS reporter_sid,
       NVL(prev_sql_id, '-') AS reporter_prevsql
FROM   v$session
WHERE  sid = SYS_CONTEXT('USERENV', 'SID');

SELECT instance_name report_instance FROM v$instance;
SELECT name report_database, db_unique_name report_db_unique FROM v$database;
SELECT TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') report_time FROM dual;
ALTER SESSION SET nls_date_format = 'DD-MON-YYYY HH24:MI:SS';
SET TERMOUT ON

PROMPT
PROMPT ================================================================================
PROMPT                              LOCKING MOTHER
PROMPT                    Oracle Row-Lock Contention Report
PROMPT ================================================================================
PROMPT Database      : &report_database
PROMPT DB Unique Name: &report_db_unique
PROMPT Connected To  : &report_instance
PROMPT Generated At  : &report_time
PROMPT RAC Key Format: INST_ID:SID
PROMPT ================================================================================


PROMPT
PROMPT ================================================================================
PROMPT [01] ACTIVE SESSIONS WAITING FOR ROW LOCKS
PROMPT      Current sessions waiting on enq: TX - row lock contention
PROMPT ================================================================================

COLUMN session_id       FORMAT A15       HEADING 'WAITING SESSION'
COLUMN blocker_id       FORMAT A14       HEADING 'BLOCKER'
COLUMN username         FORMAT A18       HEADING 'USERNAME'
COLUMN status           FORMAT A8        HEADING 'STATUS'
COLUMN wait_seconds     FORMAT 999999999 HEADING 'WAIT SEC'
COLUMN call_elapsed     FORMAT A12       HEADING 'CALL ELAPSED'
COLUMN sql_id           FORMAT A13       HEADING 'SQL_ID'
COLUMN event            FORMAT A36       HEADING 'WAIT EVENT'
COLUMN program          FORMAT A34       HEADING 'PROGRAM'
COLUMN module           FORMAT A28       HEADING 'MODULE'
COLUMN machine          FORMAT A30       HEADING 'MACHINE'

SELECT s.inst_id || ':' || s.sid AS session_id,
       CASE
         WHEN s.blocking_instance IS NULL OR s.blocking_session IS NULL THEN '-'
         ELSE TO_CHAR(s.blocking_instance) || ':' || TO_CHAR(s.blocking_session)
       END AS blocker_id,
       s.username,
       s.status,
       s.seconds_in_wait AS wait_seconds,
       LPAD(TRUNC(s.last_call_et / 3600), 3, '0') || ':' ||
       LPAD(TRUNC(MOD(s.last_call_et, 3600) / 60), 2, '0') || ':' ||
       LPAD(MOD(s.last_call_et, 60), 2, '0') AS call_elapsed,
       s.sql_id,
       s.event,
       s.program,
       s.module,
       s.machine
FROM   gv$session s
WHERE  s.username IS NOT NULL
AND    s.state = 'WAITING'
AND    s.event LIKE 'enq: TX%row lock contention%'
ORDER BY s.seconds_in_wait DESC, s.inst_id, s.sid;


PROMPT
PROMPT ================================================================================
PROMPT [02] BLOCKING TREE
PROMPT      Root blockers are shown first; indentation represents blocking depth
PROMPT ================================================================================

COLUMN lock_tree FORMAT A80 HEADING 'BLOCKING TREE (INST_ID:SID)'

WITH lock_edges AS
(
    SELECT DISTINCT
           s.blocking_instance || ':' || s.blocking_session AS blocker,
           s.inst_id || ':' || s.sid AS waiter
    FROM   gv$session s
    WHERE  s.username IS NOT NULL
    AND    s.blocking_instance IS NOT NULL
    AND    s.blocking_session IS NOT NULL
),
tree_links AS
(
    SELECT blocker AS parent_node, waiter AS child_node
    FROM   lock_edges
    UNION ALL
    SELECT DISTINCT NULL AS parent_node, e.blocker AS child_node
    FROM   lock_edges e
    WHERE  NOT EXISTS
           (SELECT 1 FROM lock_edges x WHERE x.waiter = e.blocker)
)
SELECT LPAD(' ', 2 * (LEVEL - 1)) || child_node ||
       CASE WHEN CONNECT_BY_ISLEAF = 0 THEN '  [BLOCKS]' ELSE '  [WAITS]' END
       AS lock_tree
FROM   tree_links
START WITH parent_node IS NULL
CONNECT BY NOCYCLE PRIOR child_node = parent_node
ORDER SIBLINGS BY child_node;


PROMPT
PROMPT ================================================================================
PROMPT [03] BLOCKER TO WAITER MAPPING
PROMPT      Direct TX lock relationships, including the object awaited by the waiter
PROMPT ================================================================================

COLUMN blocker_session FORMAT A14 HEADING 'BLOCKER'
COLUMN blocker_user    FORMAT A18 HEADING 'BLOCKER USER'
COLUMN waiter_session  FORMAT A14 HEADING 'WAITER'
COLUMN waiter_user     FORMAT A18 HEADING 'WAITER USER'
COLUMN wait_seconds    FORMAT 999999999 HEADING 'WAIT SEC'
COLUMN requested_mode  FORMAT A16 HEADING 'REQUESTED MODE'
COLUMN locked_object   FORMAT A50 HEADING 'WAITED OBJECT'

SELECT DISTINCT
       bs.inst_id || ':' || bs.sid AS blocker_session,
       bs.username AS blocker_user,
       ws.inst_id || ':' || ws.sid AS waiter_session,
       ws.username AS waiter_user,
       ws.seconds_in_wait AS wait_seconds,
       DECODE(wl.request,
              0, 'None', 1, 'Null', 2, 'Row Share', 3, 'Row Exclusive',
              4, 'Share', 5, 'Share Row Excl', 6, 'Exclusive',
              TO_CHAR(wl.request)) AS requested_mode,
       NVL(o.owner || '.' || o.object_name, 'Object ID ' || ws.row_wait_obj#)
       AS locked_object
FROM   gv$lock bl
JOIN   gv$lock wl
       ON  wl.type = bl.type
       AND wl.id1  = bl.id1
       AND wl.id2  = bl.id2
       AND wl.request > 0
JOIN   gv$session bs
       ON  bs.inst_id = bl.inst_id
       AND bs.sid     = bl.sid
JOIN   gv$session ws
       ON  ws.inst_id = wl.inst_id
       AND ws.sid     = wl.sid
LEFT JOIN dba_objects o
       ON  o.object_id = ws.row_wait_obj#
WHERE  bl.type = 'TX'
AND    bl.block <> 0
ORDER BY wait_seconds DESC, blocker_session, waiter_session;


PROMPT
PROMPT ================================================================================
PROMPT [04] CONTENDED LOCK RESOURCES
PROMPT      Low-level GV$LOCK data for resources that have blockers or waiters
PROMPT ================================================================================

COLUMN session_id   FORMAT A14 HEADING 'SESSION'
COLUMN lock_type    FORMAT A10 HEADING 'TYPE'
COLUMN lock_role    FORMAT A12 HEADING 'ROLE'
COLUMN held_mode    FORMAT A16 HEADING 'HELD MODE'
COLUMN request_mode FORMAT A16 HEADING 'REQUEST MODE'
COLUMN age_seconds  FORMAT 999999999 HEADING 'AGE SEC'
COLUMN id1          FORMAT 999999999999999 HEADING 'ID1'
COLUMN id2          FORMAT 999999999999999 HEADING 'ID2'

SELECT l.inst_id || ':' || l.sid AS session_id,
       l.type AS lock_type,
       CASE
         WHEN l.block = 1 THEN 'BLOCKER'
         WHEN l.block = 2 THEN 'RAC BLOCKER'
         WHEN l.request > 0 THEN 'WAITER'
         ELSE 'HOLDER'
       END AS lock_role,
       DECODE(l.lmode,
              0, 'None', 1, 'Null', 2, 'Row Share', 3, 'Row Exclusive',
              4, 'Share', 5, 'Share Row Excl', 6, 'Exclusive',
              TO_CHAR(l.lmode)) AS held_mode,
       DECODE(l.request,
              0, 'None', 1, 'Null', 2, 'Row Share', 3, 'Row Exclusive',
              4, 'Share', 5, 'Share Row Excl', 6, 'Exclusive',
              TO_CHAR(l.request)) AS request_mode,
       l.ctime AS age_seconds,
       l.id1,
       l.id2
FROM   gv$lock l
WHERE  (l.type, l.id1, l.id2) IN
       (SELECT c.type, c.id1, c.id2
        FROM   gv$lock c
        GROUP BY c.type, c.id1, c.id2
        HAVING MAX(c.request) > 0
        AND    MAX(c.block)   > 0)
ORDER BY l.id1, l.id2,
         CASE WHEN l.block <> 0 THEN 1 ELSE 2 END,
         l.ctime DESC;


PROMPT
PROMPT ================================================================================
PROMPT [05A] AFFECTED SESSION AND TRANSACTION DETAILS
PROMPT       Compact transaction view for blockers and waiters
PROMPT ================================================================================

COLUMN session_id     FORMAT A14 HEADING 'SESSION'
COLUMN lock_role      FORMAT A12 HEADING 'ROLE'
COLUMN username       FORMAT A18 HEADING 'USERNAME'
COLUMN status         FORMAT A8  HEADING 'STATUS'
COLUMN sql_id         FORMAT A13 HEADING 'CURRENT SQL'
COLUMN prev_sql_id    FORMAT A13 HEADING 'PREVIOUS SQL'
COLUMN blocker_id     FORMAT A14 HEADING 'BLOCKER'
COLUMN call_elapsed   FORMAT A12 HEADING 'CALL ELAPSED'
COLUMN logon_time     FORMAT A20 HEADING 'LOGON TIME'
COLUMN txn_start      FORMAT A20 HEADING 'TXN START'

WITH affected AS
(
    SELECT l.inst_id,
           l.sid,
           CASE
             WHEN MAX(CASE WHEN l.block <> 0 THEN 1 ELSE 0 END) = 1
              AND MAX(CASE WHEN l.request > 0 THEN 1 ELSE 0 END) = 1
               THEN 'BLOCK/WAIT'
             WHEN MAX(CASE WHEN l.block <> 0 THEN 1 ELSE 0 END) = 1
               THEN 'BLOCKER'
             ELSE 'WAITER'
           END AS lock_role
    FROM   gv$lock l
    WHERE  l.type = 'TX'
    AND    (l.block <> 0 OR l.request > 0)
    GROUP BY l.inst_id, l.sid
)
SELECT s.inst_id || ':' || s.sid AS session_id,
       a.lock_role,
       s.username,
       s.status,
       s.sql_id,
       s.prev_sql_id,
       CASE
         WHEN s.blocking_instance IS NULL OR s.blocking_session IS NULL THEN '-'
         ELSE TO_CHAR(s.blocking_instance) || ':' || TO_CHAR(s.blocking_session)
       END AS blocker_id,
       LPAD(TRUNC(s.last_call_et / 3600), 3, '0') || ':' ||
       LPAD(TRUNC(MOD(s.last_call_et, 3600) / 60), 2, '0') || ':' ||
       LPAD(MOD(s.last_call_et, 60), 2, '0') AS call_elapsed,
       TO_CHAR(s.logon_time, 'DD-MON-YYYY HH24:MI:SS') AS logon_time,
       t.start_time AS txn_start
FROM   affected a
JOIN   gv$session s
       ON  s.inst_id = a.inst_id
       AND s.sid     = a.sid
LEFT JOIN gv$transaction t
       ON  t.inst_id = s.inst_id
       AND t.addr    = s.taddr
WHERE  s.username IS NOT NULL
ORDER BY CASE a.lock_role WHEN 'BLOCKER' THEN 1 WHEN 'BLOCK/WAIT' THEN 2 ELSE 3 END,
         s.inst_id, s.sid;


PROMPT
PROMPT ================================================================================
PROMPT [05B] AFFECTED SESSION CLIENT DETAILS
PROMPT       OS, client program, module and machine information
PROMPT ================================================================================

COLUMN session_id FORMAT A14 HEADING 'SESSION'
COLUMN lock_role  FORMAT A12 HEADING 'ROLE'
COLUMN osuser     FORMAT A18 HEADING 'OS USER'
COLUMN process    FORMAT A14 HEADING 'OS PROCESS'
COLUMN machine    FORMAT A30 HEADING 'MACHINE'
COLUMN program    FORMAT A34 HEADING 'PROGRAM'
COLUMN module     FORMAT A28 HEADING 'MODULE'
COLUMN action     FORMAT A24 HEADING 'ACTION'

WITH affected AS
(
    SELECT l.inst_id,
           l.sid,
           CASE
             WHEN MAX(CASE WHEN l.block <> 0 THEN 1 ELSE 0 END) = 1
              AND MAX(CASE WHEN l.request > 0 THEN 1 ELSE 0 END) = 1
               THEN 'BLOCK/WAIT'
             WHEN MAX(CASE WHEN l.block <> 0 THEN 1 ELSE 0 END) = 1
               THEN 'BLOCKER'
             ELSE 'WAITER'
           END AS lock_role
    FROM   gv$lock l
    WHERE  l.type = 'TX'
    AND    (l.block <> 0 OR l.request > 0)
    GROUP BY l.inst_id, l.sid
)
SELECT s.inst_id || ':' || s.sid AS session_id,
       a.lock_role,
       s.osuser,
       s.process,
       s.machine,
       s.program,
       s.module,
       s.action
FROM   affected a
JOIN   gv$session s
       ON  s.inst_id = a.inst_id
       AND s.sid     = a.sid
WHERE  s.username IS NOT NULL
ORDER BY CASE a.lock_role WHEN 'BLOCKER' THEN 1 WHEN 'BLOCK/WAIT' THEN 2 ELSE 3 END,
         s.inst_id, s.sid;


PROMPT
PROMPT ================================================================================
PROMPT [06] RELEVANT SQL FOR BLOCKERS AND WAITERS
PROMPT      Waiter SQL is exact; blocker DML is the best available candidate
PROMPT ================================================================================

COLUMN session_id FORMAT A14  HEADING 'SESSION'
COLUMN lock_role  FORMAT A12  HEADING 'ROLE'
COLUMN sql_source FORMAT A19  HEADING 'SQL SOURCE'
COLUMN sql_id     FORMAT A13  HEADING 'SQL_ID'
COLUMN sql_time   FORMAT A20  HEADING 'LAST ACTIVE'
COLUMN sql_text   FORMAT A145 WORD_WRAPPED HEADING 'SQL TEXT'

SET RECSEP EACH
SET RECSEPCHAR '-'

WITH affected AS
(
    SELECT l.inst_id,
           l.sid,
           CASE
             WHEN MAX(CASE WHEN l.block <> 0 THEN 1 ELSE 0 END) = 1
              AND MAX(CASE WHEN l.request > 0 THEN 1 ELSE 0 END) = 1
               THEN 'BLOCK/WAIT'
             WHEN MAX(CASE WHEN l.block <> 0 THEN 1 ELSE 0 END) = 1
               THEN 'BLOCKER'
             ELSE 'WAITER'
           END AS lock_role
    FROM   gv$lock l
    WHERE  l.type = 'TX'
    AND    (l.block <> 0 OR l.request > 0)
    GROUP BY l.inst_id, l.sid
),
waiter_sql AS
(
    SELECT s.inst_id,
           s.sid,
           a.lock_role,
           'WAITING SQL' AS sql_source,
           s.sql_id,
           s.sql_exec_start AS sql_time
    FROM   affected a
    JOIN   gv$session s
           ON  s.inst_id = a.inst_id
           AND s.sid     = a.sid
    WHERE  a.lock_role IN ('WAITER', 'BLOCK/WAIT')
),
blocker_dml_ranked AS
(
    SELECT s.inst_id,
           s.sid,
           a.lock_role,
           'BLOCKER DML CAND.' AS sql_source,
           oc.sql_id,
           oc.last_sql_active_time AS sql_time,
           ROW_NUMBER() OVER
           (
               PARTITION BY s.inst_id, s.sid
               ORDER BY oc.last_sql_active_time DESC NULLS LAST, oc.sql_id
           ) AS rn
    FROM   affected a
    JOIN   gv$session s
           ON  s.inst_id = a.inst_id
           AND s.sid     = a.sid
    JOIN   gv$open_cursor oc
           ON  oc.inst_id = s.inst_id
           AND oc.sid     = s.sid
    JOIN   gv$sqlarea q
           ON  q.inst_id = oc.inst_id
           AND q.sql_id  = oc.sql_id
    WHERE  a.lock_role IN ('BLOCKER', 'BLOCK/WAIT')
    AND    q.command_type IN (2, 6, 7, 189)
),
blocker_fallback AS
(
    SELECT s.inst_id,
           s.sid,
           a.lock_role,
           'LAST SESSION SQL' AS sql_source,
           CASE
             WHEN s.inst_id = TO_NUMBER('&reporter_inst_id')
              AND s.sid     = TO_NUMBER('&reporter_sid')
               THEN NULLIF('&reporter_prevsql', '-')
             ELSE NVL(s.prev_sql_id, s.sql_id)
           END AS sql_id,
           CAST(NULL AS DATE) AS sql_time
    FROM   affected a
    JOIN   gv$session s
           ON  s.inst_id = a.inst_id
           AND s.sid     = a.sid
    WHERE  a.lock_role IN ('BLOCKER', 'BLOCK/WAIT')
    AND    NOT EXISTS
           (SELECT 1
            FROM   blocker_dml_ranked d
            WHERE  d.inst_id = s.inst_id
            AND    d.sid     = s.sid
            AND    d.rn      = 1)
),
sql_candidates AS
(
    SELECT inst_id, sid, lock_role, sql_source, sql_id, sql_time
    FROM   waiter_sql

    UNION ALL

    SELECT inst_id, sid, lock_role, sql_source, sql_id, sql_time
    FROM   blocker_dml_ranked
    WHERE  rn = 1

    UNION ALL

    SELECT inst_id, sid, lock_role, sql_source, sql_id, sql_time
    FROM   blocker_fallback
)
SELECT c.inst_id || ':' || c.sid AS session_id,
       c.lock_role,
       c.sql_source,
       c.sql_id,
       TO_CHAR(c.sql_time, 'DD-MON-YYYY HH24:MI:SS') AS sql_time,
       q.sql_text
FROM   sql_candidates c
LEFT JOIN gv$sqlarea q
       ON  q.inst_id = c.inst_id
       AND q.sql_id  = c.sql_id
ORDER BY CASE c.lock_role WHEN 'BLOCKER' THEN 1 WHEN 'BLOCK/WAIT' THEN 2 ELSE 3 END,
         c.inst_id,
         c.sid,
         CASE c.sql_source WHEN 'BLOCKER DML CAND.' THEN 1
                           WHEN 'LAST SESSION SQL' THEN 2
                           ELSE 3 END;

SET RECSEP OFF

PROMPT
PROMPT Note: BLOCKER DML CAND. is selected from the blocker's most recently
PROMPT       active open DML cursor. Treat it as a candidate, not absolute proof.


PROMPT
PROMPT ================================================================================
PROMPT [07] RAC INSTANCE STATUS
PROMPT ================================================================================

COLUMN instance_id   FORMAT 99  HEADING 'ID'
COLUMN instance_name FORMAT A18 HEADING 'INSTANCE'
COLUMN host_name     FORMAT A32 HEADING 'HOST'
COLUMN status        FORMAT A12 HEADING 'STATUS'
COLUMN startup_time  FORMAT A20 HEADING 'STARTUP TIME'

SELECT inst_id AS instance_id,
       instance_name,
       host_name,
       status,
       TO_CHAR(startup_time, 'DD-MON-YYYY HH24:MI:SS') AS startup_time
FROM   gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ================================================================================
PROMPT END OF LOCKING REPORT
PROMPT ================================================================================

SET COLSEP ' '
CLEAR COLUMNS
