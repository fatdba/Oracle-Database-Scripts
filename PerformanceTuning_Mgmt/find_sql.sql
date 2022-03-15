accept sql_text -
prompt 'Enter sql_text :'
set pagesi 1000
set linesi 190
set verify off
column sql_text format a55
col sql_id format a20
col last_active_time format a30
select  sql_id,plan_hash_value,SQL_PLAN_BASELINE,max(last_active_time) last_active_time,max(sql_text) sql_text from v$sql where lower(sql_text) like lower('%&sql_text%') and sql_text not like '%where sql_text like%' group by sql_id,plan_hash_value,SQL_PLAN_BASELINE order by 4;
undef sql_text;
