column mux format a18 heading 'Mutex Type' trunc;
column loc format a32 heading 'Location' trunc;
column sleeps format 9,999,999,990 heading 'Sleeps';
column wt format 9,999,990.9 heading 'Wait |Time (s)';
select e.mutex_type mux
, e.location loc
, e.sleeps - nvl(b.sleeps, 0) sleeps
, (e.wait_time - nvl(b.wait_time, 0))/1000000 wt
from DBA_HIST_MUTEX_SLEEP b
, DBA_HIST_MUTEX_SLEEP e
where b.snap_id(+) = &bid
and e.snap_id = &eid
and b.dbid(+) = e.dbid
and b.instance_number(+) = e.instance_number
and b.mutex_type(+) = e.mutex_type
and b.location(+) = e.location
and e.sleeps - nvl(b.sleeps, 0) > 0
order by e.wait_time - nvl(b.wait_time, 0) desc;
