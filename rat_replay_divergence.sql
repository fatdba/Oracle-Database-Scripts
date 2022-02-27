set long 30000000 longchunksize 1000 serverout on
ACCEPT ls_replay_id PROMPT 'Replay Id: '

DECLARE
r CLOB;
ls_stream_id NUMBER;
ls_call_counter NUMBER;
ls_sql_cd VARCHAR2(20);
ls_sql_err VARCHAR2(512);
CURSOR c IS
SELECT stream_id,call_counter
FROM DBA_WORKLOAD_REPLAY_DIVERGENCE
WHERE replay_id = &ls_replay_id;
BEGIN
OPEN c;
LOOP
FETCH c INTO ls_stream_id, ls_call_counter;
EXIT when c%notfound;
DBMS_OUTPUT.PUT_LINE (ls_stream_id||''||ls_call_counter);
r:=DBMS_WORKLOAD_REPLAY.GET_DIVERGING_STATEMENT(replay_id => &ls_replay_id,
stream_id => ls_stream_id, call_counter => ls_call_counter);
DBMS_OUTPUT.PUT_LINE (r);
END LOOP;
END;
/
