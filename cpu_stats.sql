set linesize 160
set pagesize 50
set colsep '  ' -- thanks @Boneist <img src="http://s2.wp.com/wp-includes/images/smilies/icon_smile.gif?m=1235673185g" alt=":)" class="wp-smiley">
column "Total Available CPU Seconds"    head "Total Available|CPU Seconds"      format 990
column "Used Oracle Seconds"            head "Used Oracle|Seconds"              format 990.9
column "Used Host CPU %"                head "Used Host|CPU %"                  format 990.9
column "Idle Host CPU %"                head "Idle Host|CPU %"                  format 990.9
column "Total Used Seconds"             head "Total Used|Seconds"               format 990.9
column "Idle Seconds"                   head "Idle|Seconds"                     format 990.9
column "Non-Oracle Seconds Used"        head "Non-Oracle|Seconds Used"          format 990.9
column "Oracle CPU %"                   head "Oracle|CPU %"                     format 990.9
column "Non-Oracle CPU %"               head "Non-Oracle|CPU %"                 format 990.9
column "throttled"                      head "Oracle Throttled|Time (s)"        format 990.9
 
select to_char(rm.BEGIN_TIME,'YYYY-MM-DD HH24:MI:SS') as BEGIN_TIME
        ,60 * (select value from v$osstat where stat_name = 'NUM_CPUS') as "Total Available CPU Seconds"
        ,sum(rm.cpu_consumed_time) / 1000 as "Used Oracle Seconds"
        ,min(s.value) as "Used Host CPU %"
        ,(60 * (select value from v$osstat where stat_name = 'NUM_CPUS')) * (min(s.value) / 100) as "Total Used Seconds"
        ,((100 - min(s.value)) / 100) * (60 * (select value from v$osstat where stat_name = 'NUM_CPUS')) as "Idle Seconds"
        ,((60 * (select value from v$osstat where stat_name = 'NUM_CPUS')) * (min(s.value) / 100)) - sum(rm.cpu_consumed_time) / 1000 as "Non-Oracle Seconds Used"
        ,100 - min(s.value) as "Idle Host CPU %"
        ,((((60 * (select value from v$osstat where stat_name = 'NUM_CPUS')) * (min(s.value) / 100)) - sum(rm.cpu_consumed_time) / 1000) / (60 * (select value 
from v$osstat where stat_name = 'NUM_CPUS')))*100 as "Non-Oracle CPU %"
        ,(((sum(rm.cpu_consumed_time) / 1000) / (60 * (select value from v$osstat where stat_name = 'NUM_CPUS'))) * 100) as "Oracle CPU %"
        , sum(rm.cpu_wait_time) / 1000 as throttled
from    gv$rsrcmgrmetric_history rm
        inner join
        gV$SYSMETRIC_HISTORY s
        on rm.begin_time = s.begin_time
where   s.metric_id = 2057
  and   s.group_id = 2
group by rm.begin_time,s.begin_time
order by rm.begin_time;
