accept days default 3 prompt "Number of days since the plan changed [3]: "

variable v_lo_snap number;
variable v_hi_snap number;
variable v_dbid number;

-- undef days
set feedback off
begin
select dbid into :v_dbid from v$database;
select min(snap_id), max(snap_id)
into :v_lo_snap, :v_hi_snap
from dba_hist_snapshot
  where begin_interval_time > sysdate - &&days;
end;
/


set pages 32000
set long 32000
set longc 32000
set lines 150
set feedback on
column module format a30 word_wrapped
column sql_text format a80 word_wrapped
SELECT nvl(m.module, 'N/A') module, t.sql_id, t.sql_text
FROM dba_hist_sqltext t left join (
  select distinct module, sql_id from dba_hist_sqlstat
  where dbid = :v_dbid and snap_id = :v_hi_snap ) m
on t.sql_id = m.sql_id
WHERE t.dbid = :v_dbid and t.sql_id in (
  select distinct old.sql_id
--    , old.plan_hash_value old_plan_hash_value
--    , new.plan_hash_value new_plan_hash_value
  from dba_hist_sqlstat old inner join dba_hist_sqlstat new
  on old.sql_id = new.sql_id and old.dbid = new.dbid
  and old.snap_id < new.snap_id and old.snap_id >= :v_lo_snap
  left outer join dba_hist_sqlstat miss
  on miss.sql_id = new.sql_id and miss.dbid = new.dbid
  and miss.snap_id < new.snap_id and miss.snap_id >= :v_lo_snap
  and miss.plan_hash_value = new.plan_hash_value
  where miss.sql_id is null
  and new.dbid = :v_dbid
  and new.snap_id <= :v_hi_snap
  and old.plan_hash_value != new.plan_hash_value
  and old.plan_hash_value > 0 and new.plan_hash_value > 0
)
order by module, sql_id
/

