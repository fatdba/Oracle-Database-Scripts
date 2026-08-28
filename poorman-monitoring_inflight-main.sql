------------------------------------------------------------------------------------------------------------------------
-- File name : prashant_active_session_report.sql
-- Version   : 2.3
-- Purpose   : Display active Oracle sessions in a clean, vertical, RAC-aware format.
-- Author    : Prashant Dixit - The FatDBA - www.fatdba.com
-- Notes     : Requires access to GV$SESSION, GV$SQLAREA, DBA_SQL_PROFILES,
--             DBA_SQL_PLAN_BASELINES and DBA_SQL_PATCHES.
------------------------------------------------------------------------------------------------------------------------

SET ECHO OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET PAGESIZE 0
SET LINESIZE 220
SET LONG 1000000
SET LONGCHUNKSIZE 32767
SET TRIMSPOOL ON
SET TAB OFF
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED

-- Uncomment the following three lines to spool every execution automatically.
-- COLUMN report_ts NEW_VALUE report_ts NOPRINT
-- SELECT TO_CHAR(SYSDATE, 'YYYYMMDD_HH24MISS') report_ts FROM dual;
-- SPOOL active_sessions_&report_ts..log

DECLARE
    c_width       CONSTANT PLS_INTEGER := 110;
    c_sql_width   CONSTANT PLS_INTEGER := 180;
    c_separator   CONSTANT VARCHAR2(220) := RPAD('=', c_width, '=');
    c_session_separator CONSTANT VARCHAR2(220) := RPAD('#', c_width, '#');
    c_subseparator CONSTANT VARCHAR2(220) := RPAD('-', c_width, '-');

    l_session_count  PLS_INTEGER := 0;

    FUNCTION display_value(p_value VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(TRIM(p_value), '-');
    END display_value;

    FUNCTION display_number(p_value NUMBER, p_format VARCHAR2 DEFAULT 'FM999G999G999G999G990')
        RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE WHEN p_value IS NULL THEN '-' ELSE TO_CHAR(p_value, p_format) END;
    END display_number;

    FUNCTION duration_text(p_seconds NUMBER) RETURN VARCHAR2 IS
        l_seconds NUMBER := NVL(p_seconds, 0);
    BEGIN
        RETURN CASE
                   WHEN l_seconds >= 86400
                   THEN FLOOR(l_seconds / 86400) || 'd '
                        || TO_CHAR(TRUNC(MOD(l_seconds, 86400) / 3600), 'FM00') || ':'
                        || TO_CHAR(TRUNC(MOD(l_seconds, 3600) / 60), 'FM00') || ':'
                        || TO_CHAR(TRUNC(MOD(l_seconds, 60)), 'FM00')
                   ELSE TO_CHAR(TRUNC(l_seconds / 3600), 'FM00') || ':'
                        || TO_CHAR(TRUNC(MOD(l_seconds, 3600) / 60), 'FM00') || ':'
                        || TO_CHAR(TRUNC(MOD(l_seconds, 60)), 'FM00')
               END;
    END duration_text;

    PROCEDURE print_item(p_label VARCHAR2, p_value VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE(RPAD(p_label, 29) || ': ' || display_value(p_value));
    END print_item;

    PROCEDURE print_sql_text(p_sql CLOB) IS
        l_offset     PLS_INTEGER := 1;
        l_length     PLS_INTEGER;
        l_raw_piece  VARCHAR2(32767);
        l_raw_length PLS_INTEGER;
        l_piece      VARCHAR2(32767);
        l_line       VARCHAR2(32767);
        l_break      PLS_INTEGER;
    BEGIN
        IF p_sql IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('  -');
            RETURN;
        END IF;

        l_length := DBMS_LOB.GETLENGTH(p_sql);

        WHILE l_offset <= l_length LOOP
            l_raw_piece  := DBMS_LOB.SUBSTR(p_sql, 30000, l_offset);
            l_raw_length := LENGTH(l_raw_piece);
            l_piece := REGEXP_REPLACE(
                           REPLACE(REPLACE(l_raw_piece, CHR(13), ' '), CHR(10), ' '),
                           '[[:space:]]+',
                           ' '
                       );

            WHILE LENGTH(l_piece) > c_sql_width LOOP
                l_break := INSTR(SUBSTR(l_piece, 1, c_sql_width + 1), ' ', -1);

                IF l_break <= 1 THEN
                    l_break := c_sql_width + 1;
                END IF;

                l_line  := RTRIM(SUBSTR(l_piece, 1, l_break - 1));
                l_piece := LTRIM(SUBSTR(l_piece, l_break + 1));
                DBMS_OUTPUT.PUT_LINE('  ' || l_line);
            END LOOP;

            IF l_piece IS NOT NULL THEN
                DBMS_OUTPUT.PUT_LINE('  ' || RTRIM(l_piece));
            END IF;

            l_offset := l_offset + l_raw_length;
        END LOOP;
    END print_sql_text;

BEGIN
    DBMS_OUTPUT.PUT_LINE(c_separator);
    DBMS_OUTPUT.PUT_LINE('Prashant Dixit''s In-flight Transaction Report');
    DBMS_OUTPUT.PUT_LINE(c_separator);

    FOR r IN (
        SELECT s.inst_id,
               s.sid,
               s.serial#,
               s.username,
               s.status,
               s.sql_id,
               s.sql_exec_id,
               q.plan_hash_value AS sql_plan_hash_value,
               (SELECT LISTAGG(p.name || ' [' || p.status || ']', ', ')
                           WITHIN GROUP (ORDER BY p.name)
                  FROM dba_sql_profiles p
                 WHERE p.signature IN
                       (q.exact_matching_signature, q.force_matching_signature)
               ) AS sql_profiles,
               (SELECT LISTAGG(b.plan_name || ' [Enabled=' || b.enabled
                               || ', Accepted=' || b.accepted || ']', ', ')
                           WITHIN GROUP (ORDER BY b.plan_name)
                  FROM dba_sql_plan_baselines b
                 WHERE b.signature = q.exact_matching_signature
               ) AS sql_baselines,
               (SELECT LISTAGG(p.name || ' [' || p.status || ']', ', ')
                           WITHIN GROUP (ORDER BY p.name)
                  FROM dba_sql_patches p
                 WHERE p.signature IN
                       (q.exact_matching_signature, q.force_matching_signature)
               ) AS sql_patches,
               s.sql_exec_start,
               s.last_call_et,
               s.event,
               s.wait_class,
               s.state,
               s.seconds_in_wait,
               s.blocking_session_status,
               s.blocking_instance,
               s.blocking_session,
               s.final_blocking_instance,
               s.final_blocking_session,
               s.osuser,
               s.process,
               s.machine,
               s.program,
               s.module,
               s.action,
               s.client_identifier,
               s.service_name,
               s.logon_time,
               q.sql_fulltext
          FROM gv$session s
          LEFT JOIN gv$sqlarea q
            ON q.inst_id = s.inst_id
           AND q.sql_id  = s.sql_id
         WHERE s.status = 'ACTIVE'
           AND s.username IS NOT NULL
           AND NOT (
                   s.inst_id = USERENV('INSTANCE')
               AND s.sid     = SYS_CONTEXT('USERENV', 'SID')
           )
         -- ORDER BY s.last_call_et DESC, s.inst_id, s.sid
		 ORDER BY s.sql_exec_start ASC NULLS LAST,s.last_call_et DESC,s.inst_id,s.sid
    ) LOOP
        l_session_count := l_session_count + 1;

        DBMS_OUTPUT.PUT_LINE(CHR(10) || c_session_separator);
        DBMS_OUTPUT.PUT_LINE(
            'SESSION ' || l_session_count
            || '  |  Instance ' || r.inst_id
            || '  |  SID ' || r.sid || ',' || r.serial#
            || '  |  User ' || display_value(r.username)
        );
        DBMS_OUTPUT.PUT_LINE(c_session_separator);

        DBMS_OUTPUT.PUT_LINE('[SESSION AND SQL IDENTITY]');
        print_item('Instance ID',       TO_CHAR(r.inst_id));
        print_item('SID, Serial#',      r.sid || ', ' || r.serial#);
        print_item('Username',          r.username);
        print_item('Session status',    r.status);
        print_item('SQL ID',            r.sql_id);
        print_item('SQL execution ID',  TO_CHAR(r.sql_exec_id));
        print_item('Plan hash value',   TO_CHAR(r.sql_plan_hash_value));
        print_item('Service',           r.service_name);
        print_item('SQL Profile',       r.sql_profiles);
        print_item('SQL Plan Baseline', r.sql_baselines);
        print_item('SQL Patch',         r.sql_patches);

        DBMS_OUTPUT.PUT_LINE(c_subseparator);
        DBMS_OUTPUT.PUT_LINE('[RUNTIME]');
        print_item('SQL execution started',
                   CASE WHEN r.sql_exec_start IS NULL THEN NULL
                        ELSE TO_CHAR(r.sql_exec_start, 'YYYY-MM-DD HH24:MI:SS') END);
        print_item('Current call duration', duration_text(r.last_call_et));
        print_item('Current call seconds',  display_number(r.last_call_et));
        print_item('Session logon time',    TO_CHAR(r.logon_time, 'YYYY-MM-DD HH24:MI:SS'));

        DBMS_OUTPUT.PUT_LINE(c_subseparator);
        DBMS_OUTPUT.PUT_LINE('[WAIT INFORMATION]');
        print_item('Event',            r.event);
        print_item('Wait class',       r.wait_class);
        print_item('Wait state',       r.state);
        print_item('Seconds in wait',  display_number(r.seconds_in_wait));

        DBMS_OUTPUT.PUT_LINE(c_subseparator);
        DBMS_OUTPUT.PUT_LINE('[BLOCKING INFORMATION]');
        print_item('Blocking status',   r.blocking_session_status);
        print_item('Blocking instance', TO_CHAR(r.blocking_instance));
        print_item('Blocking session',  TO_CHAR(r.blocking_session));
        print_item('Final blocker inst', TO_CHAR(r.final_blocking_instance));
        print_item('Final blocker SID',  TO_CHAR(r.final_blocking_session));

        DBMS_OUTPUT.PUT_LINE(c_subseparator);
        DBMS_OUTPUT.PUT_LINE('[CLIENT SOURCE]');
        print_item('OS user',            r.osuser);
        print_item('Client process',     r.process);
        print_item('Machine',            r.machine);
        print_item('Program',            r.program);
        print_item('Module',             r.module);
        print_item('Action',             r.action);
        print_item('Client identifier',  r.client_identifier);

        DBMS_OUTPUT.PUT_LINE(c_subseparator);
        DBMS_OUTPUT.PUT_LINE('[SQL TEXT]');
        print_sql_text(r.sql_fulltext);
    END LOOP;

    IF l_session_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No active user sessions were found.');
    ELSE
        DBMS_OUTPUT.PUT_LINE(CHR(10) || c_separator);
        DBMS_OUTPUT.PUT_LINE('Total active user sessions reported: ' || l_session_count);
        DBMS_OUTPUT.PUT_LINE(c_separator);
    END IF;
END;
/

-- SPOOL OFF

SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 100
