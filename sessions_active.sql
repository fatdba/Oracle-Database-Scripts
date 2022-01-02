PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT------                 /)  (\
PROMPT------            .-._((,~~.))_.-,
PROMPT------             `-.   @@   ,-'
PROMPT------               / ,o--o. \
PROMPT------              ( ( .__. ) )
PROMPT------               ) `----' (
PROMPT------              /          \
PROMPT------             /            \
PROMPT------            /              \
PROMPT------    "The Silly Cow"
PROMPT----- Script: sessions_active.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Version: V1.1 (Date: 04-02-2019)
PROMPT-----
PROMPT-----
PROMPT-----

set linesize 200 trimspool on
set pagesize 60
col username for a30

col event format a30

SELECT
   NVL(s.username,s.program) username
 , s.sid                     sid
 , s.serial#                 serial
 , s.sql_hash_value          sql_hash_value
 , SUBSTR(DECODE(w.wait_time
               , 0, w.event
               , 'ON CPU'),1,15) event
 , w.p1                          p1
 , w.p2                          p2
 , w.p3 p3
 from v$session s
 , v$session_wait  w
 where w.sid=s.sid
 and s.status='ACTIVE'
   AND s.type='USER';
