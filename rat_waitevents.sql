column event format a40
select event, count(*), min(wait_for_scn)
from gv$workload_replay_thread
where session_type = 'REPLAY'
group by event;
