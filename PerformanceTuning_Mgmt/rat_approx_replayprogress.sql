set echo off

connect sys/<password> as sysdba

set serveroutput on

DECLARE
my_next_ticker NUMBER;
clock NUMBER;
wait_for_scn NUMBER;
counts NUMBER;
replay_id NUMBER;
thr_failure NUMBER;
start_time DATE;
num_tickers NUMBER;
min_scn NUMBER;
max_scn NUMBER;
done NUMBER;
total_time INTERVAL DAY TO SECOND;

CURSOR get_next_ticker(my_next_ticker NUMBER) IS
SELECT spid, event, inst_id, wrc_id, client_pid
FROM gv$workload_replay_thread
WHERE file_id = my_next_ticker;

BEGIN
dbms_output.put_line('********************************');
dbms_output.put_line('* Replay Status Report *');
dbms_output.put_line('********************************');

-----------------------------------------
-- Make sure that a replay is in progress
-----------------------------------------
SELECT count(*) INTO counts
FROM dba_workload_replays
WHERE status='IN PROGRESS';

if (counts = 0) then
dbms_output.put_line('No replay in progress!');
return;
end if;

-------------------
-- Get replay state
-------------------
SELECT id,start_time INTO replay_id, start_time
FROM dba_workload_replays
WHERE status='IN PROGRESS';

SELECT count(*) INTO counts
FROM gv$workload_replay_thread
WHERE session_type = 'REPLAY';

SELECT min(wait_for_scn), max(next_ticker), max(clock)
INTO wait_for_scn, my_next_ticker, clock
FROM v$workload_replay_thread
WHERE wait_for_scn <> 0
AND session_type = 'REPLAY';

dbms_output.put_line('Replay has been running for: ' ||
to_char(systimestamp - start_time));
dbms_output.put_line('Current clock is: ' || clock);
dbms_output.put_line('Replay is waiting on clock: ' ||
wait_for_scn);
dbms_output.put_line(counts || ' threads are currently being
replayed.');

----------------------------------------
-- Find info about the next clock ticker
----------------------------------------
num_tickers := 0;
for rec in get_next_ticker(my_next_ticker) loop
-- We only want the next clock ticker
num_tickers := num_tickers + 1;
exit when num_tickers > 1;

dbms_output.put_line('Next ticker is process ' || rec.spid ||
' (' || rec.wrc_id || ',' || rec.client_pid ||
') in instance ' || rec.inst_id ||
' and is waiting on ');
dbms_output.put_line(' ' || rec.event);

end loop;

---------------------------------------------------------------------------------------
-- Compute the replay progression and estimate the time left
-- Note: This is an estimated time only, not an absolute value as it is based on SCN.
---------------------------------------------------------------------------------------
SELECT min(post_commit_scn), max(post_commit_scn)
INTO min_scn,max_scn
FROM wrr$_replay_scn_order;

done := (clock - min_scn) / (max_scn - min_scn);
total_time := (systimestamp - start_time) / done;

dbms_output.put_line('Estimated progression in replay: ' ||
to_char(100*done, '00') || '% done.');
dbms_output.put_line('Estimated time before completion: ' ||
((1 - done) * total_time));
dbms_output.put_line('Estimated total time for replay: ' ||
total_time);
dbms_output.put_line('Estimated final time for replay: ' ||
to_char(start_time + total_time,
'DD-MON-YY HH24:MI:SS'));

END;
/
