PROMPT
PROMPT
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT------                 /)  (\
PROMPT------            .-._((,~~.))_.-,
PROMPT------             `-.   @@   ,-'
PROMPT------               / ,o--o. \
PROMPT------              ( ( .__. ) )
PROMPT------               ) `----' (
PROMPT------              /          \
PROMPT------             /            \
PROMPT------            /              \
PROMPT------    "The Silly Cow"
PROMPT----- Script: sharedpool_advise.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Performance Management and Issue Identification
PROMPT----- Version: V1.2 (Date: 11-02-2020)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~col shared_pool_size_for_estimate format 99,999 heading "Shared Pool|MB"
col size_pct format 999 heading "Size Pct|Current"
col estd_lc_time_saved format 999,999,999 heading "Time Saved|(s)"
col saved_pct format 999.99 heading "Relative|Time Saved(%)"
col estd_lc_load_time format 999,999,999 heading "Load/Parse|Time (s)"
col  load_pct heading "Relative|Time (%)"
set pages 1000
set lines 100
set echo on 
        
SELECT shared_pool_size_for_estimate,
       shared_pool_size_factor * 100 size_pct,
       estd_lc_time_saved, 
       estd_lc_time_saved_factor * 100 saved_pct,
       estd_lc_load_time, 
       estd_lc_load_time_factor * 100 load_pct
FROM v$shared_pool_advice
ORDER BY shared_pool_size_for_estimate;
