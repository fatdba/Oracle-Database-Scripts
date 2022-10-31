--
-- Author: Prashant 'The FatDBA' Dixit
--
accept sql_text -
prompt 'Enter sql_text :'
set pagesi 1000
set linesi 190
col plan_hash format 9999999999
col p format a1
set verify off
column sql_text format a60 trunc
col sql_id format a14
col SQL_PLAN_BASELINE format a30
col last_active_time format a20
col user_name format a10 trunc
col module format a5 trunc
select  parsing_schema_name user_name,module,sql_id,plan_hash_value plan_hash,SQL_PLAN_BASELINE,(case when sql_profile is not null then 'Y' else 'N' end) p,max(last_active_time) last_active_time,max(sql_text) sql_text from v$sql where lower(sql_text) like lower('%&sql_text%') and sql_text not like '%where sql_text like%' group by parsing_schema_name,module,sql_id,plan_hash_value,SQL_PLAN_BASELINE,(case when sql_profile is not null then 'Y' else 'N' end) order by 7;
undef sql_text;
