----------------------------------------------------------------------------------------
--
-- File name:   dbtime.sql
-- Purpose:     Find busiest time periods in AWR.
--
-- Usage:       This scripts prompts for three values, all of which can be left blank.
--
--              instance_number: set to limit to a single instance in RAC environment
--
--              begin_snap_id: set it you want to limit to a specific range, defaults to 0
--
--              end_snap_id: set it you want to limit to a specific range, defaults to 99999999
--
--
---------------------------------------------------------------------------------------
set lines 155
col dbtime for 999,999.99
col begin_timestamp for a40
select * from (
select begin_snap, end_snap, timestamp begin_timestamp, inst, a/1000000/60 DBtime from
(
select
 e.snap_id end_snap,
 lag(e.snap_id) over (order by e.snap_id) begin_snap,
 lag(s.end_interval_time) over (order by e.snap_id) timestamp,
 s.instance_number inst,
 e.value,
 nvl(value-lag(value) over (order by e.snap_id),0) a
from dba_hist_sys_time_model e, DBA_HIST_SNAPSHOT s
where s.snap_id = e.snap_id
 and e.instance_number = s.instance_number
 and to_char(e.instance_number) like nvl('&instance_number',to_char(e.instance_number))
 and stat_name             = 'DB time'
)
where  begin_snap between nvl('&begin_snap_id',0) and nvl('&end_snap_id',99999999)
and begin_snap=end_snap-1
order by dbtime desc
)
where rownum < 31
/
