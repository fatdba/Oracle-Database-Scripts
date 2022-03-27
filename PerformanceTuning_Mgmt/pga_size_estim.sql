set lin 200
col BYTES_PROCESSED for 999999999999999999
col ESTD_EXTRA_BYTES_RW for 9999999999999999
col ESTD_TIME for 99999999999
col PGA_TARGET_FOR_ESTIMATE for 99999999999999999
select * from V$PGA_TARGET_ADVICE;


select name,value
from v$pgastat
where name in ('aggregate PGA target parameter',
'aggregate PGA auto target',
'maximum PGA allocated',
'total PGA inuse',
'total PGA allocated',
'over allocation count',
'extra bytes read/written',
'cache hit percentage',
'process count');


select sum(OPTIMAL_EXECUTIONS) OPTIMAL,
sum(ONEPASS_EXECUTIONS) ONEPASS ,
sum(MULTIPASSES_EXECUTIONS) MULTIPASSES
from v$sql_workarea
where POLICY='AUTO'; 
