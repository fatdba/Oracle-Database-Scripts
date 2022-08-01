PROMPT
PROMPT
PROMPT
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
PROMPT----- Script: rman1.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Performance Management and Issue Identification
PROMPT----- Version: V1.2 (Date: 04-02-2020)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~set lines 120
col RMAN_Status FORMAT A20 heading "Status"
col INPUT_TYPE  FORMAT A15 heading "Backup Type"
col Hrs         FORMAT 999.99 heading "Backup Time"
col Start_Time  FORMAT A20 heading "Backup Start Time"
col Start_Time  FORMAT A20 heading "Backup End Time"

SELECT SESSION_KEY "Backup Session ID", INPUT_TYPE, 
       STATUS 				      RMAN_Status,
       TO_CHAR(START_TIME,'DY mm/dd hh24:mi') Start_Time,
       TO_CHAR(END_TIME,'DY mm/dd hh24:mi')   Start_Time,
       ELAPSED_SECONDS/3600                   Hrs
FROM GV$RMAN_BACKUP_JOB_DETAILS
ORDER BY SESSION_KEY desc;

