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
PROMPT----- Script: autostatsgatherdet.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Performance Management and Issue Identification
PROMPT----- Version: V1.1 (Date: 01-11-2020)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~SET LINESIZE 250
COLUMN autostats_target FORMAT A20
COLUMN cascade FORMAT A25
COLUMN degree FORMAT A10
COLUMN estimate_percent FORMAT A30
COLUMN method_opt FORMAT A25
COLUMN no_invalidate FORMAT A30
COLUMN granularity FORMAT A15
COLUMN publish FORMAT A10
COLUMN incremental FORMAT A15
COLUMN stale_percent FORMAT A15

SELECT DBMS_STATS.GET_PREFS('AUTOSTATS_TARGET') AS autostats_target,
       DBMS_STATS.GET_PREFS('CASCADE') AS cascade,
       DBMS_STATS.GET_PREFS('DEGREE') AS degree,
       DBMS_STATS.GET_PREFS('ESTIMATE_PERCENT') AS estimate_percent,
       DBMS_STATS.GET_PREFS('METHOD_OPT') AS method_opt,
       DBMS_STATS.GET_PREFS('NO_INVALIDATE') AS no_invalidate,
       DBMS_STATS.GET_PREFS('GRANULARITY') AS granularity,
       DBMS_STATS.GET_PREFS('PUBLISH') AS publish,
       DBMS_STATS.GET_PREFS('INCREMENTAL') AS incremental,
       DBMS_STATS.GET_PREFS('STALE_PERCENT') AS stale_percent
FROM   dual;
