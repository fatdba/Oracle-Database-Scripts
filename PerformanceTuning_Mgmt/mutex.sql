set linesi 190
set pagesi 0
col event format a30 trunc
col sid format 99999999
SELECT w.sid,w.username,w.module,w.status,substr(w.event,1,20) event,w.sql_id,w.last_call_et,b.sid,b.status,b.sql_id,b.last_call_et
FROM v$session w,  -- waiter
v$session b    -- blocker
WHERE w.event in ( 'cursor: pin S wait on X','cursor: mutex X','cursor: mutex S','cursor: pin X','cursor: pin S','library cache: mutex X','library cache: mutex S')
and to_number(substr(to_char(rawtohex(w.p2raw)), 1, 8), 'XXXXXXXX')=b.sid(+)
order by b.sid,w.event,w.last_call_et;
