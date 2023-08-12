set linesize 400 pagesize 400
SELECT
    OUTPUT || CHR(10) || RPAD('-', LENGTH(OUTPUT) - LENGTH(REPLACE(OUTPUT, CHR(10), '')), '-') AS OUTPUT
FROM (
    SELECT
    'INST_ID -->  '||x.INST_ID || CHR(10) ||
    'Serial ID -->  '||x.sid || CHR(10) ||
    'Serial Num -->  '||x.serial# || CHR(10) ||
    'User Name -->  '||x.username || CHR(10) ||
    'Session Status -->  '||x.status || CHR(10) ||
    'Program -->  '||x.program || CHR(10) ||
    'Module -->  '||x.Module || CHR(10) ||
    'Action -->  '||x.action || CHR(10) ||
    'Machine -->  '||x.machine || CHR(10) ||
    'OS_USER -->  '||x.OSUSER || CHR(10) ||
    'Process -->  '||x.process || CHR(10) ||
    'State -->  '||x.State || CHR(10) ||
    'EVENT -->  '||x.event || CHR(10) ||
    'SECONDS_IN_WAIT -->  '||x.SECONDS_IN_WAIT || CHR(10) ||
    'LAST_CALL_ET -->  '||x.LAST_CALL_ET || CHR(10) ||
    'SQL_PROFILE --> '||SQL_PROFILE || CHR(10) ||
    'ROWS_PROCESSED --> '||ROWS_PROCESSED || CHR(10) ||
    'BLOCKING_SESSION_STATUS --> '||BLOCKING_SESSION_STATUS || CHR(10) ||
    'BLOCKING_INSTANCE --> '||BLOCKING_INSTANCE || CHR(10) ||
    'BLOCKING_SESSION --> '||BLOCKING_SESSION || CHR(10) ||
    'FINAL_BLOCKING_SESSION_STATUS --> '||FINAL_BLOCKING_SESSION_STATUS || CHR(10) ||
    'SQL_ID -->  '||x.sql_id || CHR(10) ||
    'SQL_TEXT -->  '||SQL_TEXT || CHR(10) ||
    'Logon Time -->  '||TO_CHAR(x.LOGON_TIME, 'MM-DD-YYYY HH24MISS') || CHR(10) ||
    'RunTime -->  '||ltrim(to_char(floor(x.LAST_CALL_ET/3600), '09')) || ':'
    || ltrim(to_char(floor(mod(x.LAST_CALL_ET, 3600)/60), '09')) || ':'
    || ltrim(to_char(mod(x.LAST_CALL_ET, 60), '09')) || CHR(10) AS OUTPUT,
    x.LAST_CALL_ET AS RUNT
    FROM   gv$sqlarea sqlarea
    ,gv$session x
    WHERE  x.sql_hash_value = sqlarea.hash_value
    AND    x.sql_address    = sqlarea.address
    AND    x.status='ACTIVE'
    -- AND x.event like '%row lock contention%'
    AND SQL_TEXT not like '%SELECT     OUTPUT || CHR(10)%'
    AND x.USERNAME IS NOT NULL
    AND x.SQL_ADDRESS    = sqlarea.ADDRESS
    AND x.SQL_HASH_VALUE = sqlarea.HASH_VALUE
)
ORDER BY RUNT DESC;
