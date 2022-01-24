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
PROMPT----- Script: sharedpool_advisory.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Version: V1.1 (Date: 04-02-2019)
PROMPT-----
PROMPT-----
PROMPT-----
col shared_pool_size_for_estimate format 999999 heading "Size of Shared Pool in MB"
col shared_pool_size_factor format 99.90 head "Size Factor"
col estd_lc_time_saved format 999,999,999 head "Time Saved in sec" 
col estd_lc_size format 99,999,999,999 head "Est libcache mem"
col estd_lc_memory_object_hits format 999,999,999,999 head 'libcache hits'

SELECT shared_pool_size_for_estimate 
   , shared_pool_size_factor 
   , estd_lc_size 
   , estd_lc_time_saved 
   , estd_lc_memory_object_hits
FROM v$shared_pool_advice
/
