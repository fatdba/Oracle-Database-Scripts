set linesi 190
set verify off
set pagesi 500
set heading on
col what format a60
col interval format a32 
column job format 99999
column last_date format a17
column this_date format a17
column next_date format a17
select job,to_char(last_date,'YYYYMMDD HH24:MI:SS') last_date,to_char(this_date,'YYYYMMDD HH24:MI:SS') this_date,to_char(next_date,'YYYYMMDD HH24:MI:SS') next_date,broken,interval,failures,what from dba_jobs where lower(what) like lower('%&job%');
