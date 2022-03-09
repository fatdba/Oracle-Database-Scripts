- 
-- Given a sql_id show sql performance statistics betwwen 2 timestamps in PDT
-- 
@plusenv
accept sql_id prompt 'Enter sql_id : '
accept start_time_PDT   prompt 'Start Time in PDT (MM/DD HH24:MI) : '
accept   end_time_PDT   prompt 'End   Time in PDT (MM/DD HH24:MI) : '

col apwpx 		format 99999.999 	head 'AppWms|PerX'
col bgpx 		format 999999999	head 'BGets|PerX'
col conw		format 99999.999	head 'Conwms|PerX'
col cpx 		format 99999999.999 	head 'CPUms|PerX'
col drpx 		format 9999999.99	head 'DReads|PerX'
col fetchx 		format 99999 		head 'Fetchs|PerX'
col sortx 		format 999 		head 'Sorts|PerX'
col elpx 		format 99999999.999 	head 'Elapms|PerX'
col exec		format 999999999999	head 'Execs'
col iowpx 		format 99999999.999 	head 'IOWms|PerX'
col latime		format a11		head 'Last Active'
col lltime		format a09		head 'Last Load'
col maxsnapid		format 999999		head 'Max|SnapId'
col m			format a01	trunc
col snap_id		format 999999		
col phash 		format 9999999999	head 'PlanHash'
col rwpx 		format 999999.99	head 'RwsP|PerX'
col sql_id		format a15		head 'SQL Id'
col ue			format 999
col cpct		format 999		head 'CPU|Pct'		trunc
col ipct		format 999		head 'IO|Pct'		trunc
col btime		format a11		head 'Begin Time'

prompt
prompt	===== from dba_hist_sqlstat =====
select	 plan_hash_value						phash
	,ss.snap_id							snap_id
	,to_char(sn.begin_interval_time,'MM/DD HH24:MI')		btime
	,to_char(new_time(sn.begin_interval_time,'GMT','PDT'),'MM/DD HH24:MI')			btime_PDT
	,sum(decode(executions_delta,0,1,executions_delta))					exec
	,sum(decode(PARSE_CALLS_DELTA,0,1,PARSE_CALLS_DELTA))					parses
	,sum(decode(LOADS_DELTA,0,1,LOADS_DELTA))						loads
	,sum(decode(INVALIDATIONS_DELTA,0,1,INVALIDATIONS_DELTA))				invals
       	,sum(cpu_time_delta)/sum(decode(executions_delta,0,1,executions_delta))/1000		cpx
	,sum(elapsed_time_delta)/sum(decode(executions_delta,0,1,executions_delta))/1000	elpx
       	,(sum(cpu_time_delta)/sum(decode(elapsed_time_delta,0,1,elapsed_time_delta)))*100	cpct
       	,sum(buffer_gets_delta)/sum(decode(executions_delta,0,1,executions_delta))		bgpx
	,sum(iowait_delta)/sum(decode(executions_delta,0,1,executions_delta))/1000		iowpx
       	,(sum(iowait_delta)/sum(decode(elapsed_time_delta,0,1,elapsed_time_delta)))*100		ipct
	,sum(disk_reads_delta)/sum(decode(executions_delta,0,1,executions_delta))		drpx
	,sum(apwait_delta)/sum(decode(executions_delta,0,1,executions_delta))/1000		apwpx
	,sum(ccwait_delta)/sum(decode(executions_delta,0,1,executions_delta))/1000		conw
	,sum(rows_processed_delta)/sum(decode(executions_delta,0,1,executions_delta)) 		rwpx
	,sum(sorts_delta)/sum(decode(executions_delta,0,1,executions_delta)) 			sortx
	,sum(end_of_fetch_count_delta)/sum(decode(executions_delta,0,1,executions_delta)) 	fetchx
from 	 dba_hist_sqlstat	ss
	,dba_hist_snapshot	sn
where	 sql_id	= '&&sql_id'
and	 ss.snap_id		= sn.snap_id
and	 to_char(new_time(sn.begin_interval_time,'GMT','PDT'),'MM/DD HH24:MI') between '&&start_time_PDT' and '&&end_time_PDT'
and	 EXECUTIONS_DELTA	>0
group by sql_id
	,plan_hash_value
	,ss.snap_id
	,to_char(sn.begin_interval_time,'MM/DD HH24:MI')
	,to_char(new_time(sn.begin_interval_time,'GMT','PDT'),'MM/DD HH24:MI')
order by min(ss.snap_id)
;
--@sqlid_inf0.sql
