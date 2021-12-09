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
PROMPT----- Script: sqlid_main.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Performance Management and Issue Identification
PROMPT----- Version: V1.6 (Date: 07-07-2019)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~@plusenv
set lines 250
undef sql_id
accept sql_id prompt 'Enter sql_id : '

col apwpx               format 99999.999        head 'AppWms|PerX'
col bgpx                format 999999999        head 'BGets|PerX'
col conw                format 99999.999        head 'Conwms|PerX'
col cpx                 format 99999999.999     head 'CPUms|PerX'
col drpx                format 9999999.99       head 'DReads|PerX'
col fetchx              format 99999            head 'Fetchs|PerX'
col sortx               format 999              head 'Sorts|PerX'
col elpx                format 99999999.999     head 'Elapms|PerX'
col exec                format 999999999999     head 'Execs'
col iowpx               format 99999999.999     head 'IOWms|PerX'
col latime              format a11              head 'Last Active'
col lltime              format a09              head 'Last Load'
col maxsnapid           format 999999           head 'Max|SnapId'
col m                   format a01      trunc
col minsnapid           format 999999           head 'Min|SnapId'
col module              format a14      trunc   head 'Module'
col o                   format a01              head 'O'                trunc
col opt_mode            format a08      trunc   head 'Opt|Mode'         trunc
col parse_usr           format a08              head 'ParsUser'         trunc
col phash               format 9999999999       head 'PlanHash'
col phashp              format a12              head 'PlanHash   P'
col rwpx                format 999999.99        head 'RwsP|PerX'
col s_cn                format a07              head 'S:Child'          trunc
col sql_id              format a15              head 'SQL Id'
col sqltext             format a12      trunc   head 'Sql Text'
col ue                  format 999
col cpct                format 999              head 'CPU|Pct'          trunc
col ipct                format 999              head 'IO|Pct'           trunc
col btime               format a11              head 'Begin Time'
col smem                format 99999            head 'ShrMem|KB'

-- profile/baseline associated with sql_id
col name        format a26
col category    format a04              trunc
col created     format a14
col type        format a03              trunc
col status      format a03              trunc
col sql_text    format a80              trunc
col min_ago     format 9999             trunc   head 'Mins|Ago'
select   parsing_schema_name                                            parse_usr
        ,sql_id
        ,lpad(plan_hash_value,10,' ')||' '||
         case when sql_profile is not null then 'P'
              when sql_plan_baseline is not null then 'B'
              else ' '
         end                                                            phashp
        --,is_bind_sensitive||is_bind_aware||is_shareable       pas
        --,optimizer_mode                                       m
        --,is_obsolete                                          o
        ,users_executing                                                ue
        ,substr(object_status,1,1)||':'||lpad(child_number,5,' ')       s_cn
        --,to_char(to_date(last_load_time,'YYYY-MM-DD/HH24:MI:SS'),'MMDD HH24MI')       lltime
        ,to_char(last_active_time,'MMDD HH24:MI')                       latime
        ,(sysdate-last_active_time)*1440                                min_ago
        ,decode(executions,0,1,executions)                              exec
        ,cpu_time/decode(executions,0,1,executions)/1000                cpx
        ,elapsed_time/decode(executions,0,1,executions)/1000            elpx
        ,(cpu_time/elapsed_time)*100                                    cpct
        ,buffer_gets/decode(executions,0,1,executions)                  bgpx
        ,user_io_wait_time/decode(executions,0,1,executions)/1000       iowpx
        ,(user_io_wait_time/elapsed_time)*100                           ipct
        ,disk_reads/decode(executions,0,1,executions)                   drpx
        ,application_wait_time/decode(executions,0,1,executions)/1000   apwpx
        ,concurrency_wait_time/decode(executions,0,1,executions)/1000   conw
        ,rows_processed/decode(executions,0,1,executions)               rwpx
        ,sorts/decode(executions,0,1,executions)                        sortx
        ,fetches/decode(executions,0,1,executions)                      fetchx
        ,module                                                         module
        ,replace(sql_text,chr(30))                                      sqltext
from     v$sql
where    sql_id                 = '&&sql_id'
and      last_active_time       > sysdate-3
order by parsing_schema_name
        ,last_active_time
;
