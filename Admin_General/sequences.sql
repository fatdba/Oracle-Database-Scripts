set linesi 190
set pagesi 190
col last_number format 999999999999999999999
select sequence_name,last_number,increment_by,cache_size from dba_sequences where sequence_owner='&owner' order by increment_by;
