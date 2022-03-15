--
-- Show top_x_rows in terms of physical I/O - breakdown by 1 day interval
--

accept start_date	prompt 'Start Date (MM/DD) : ' 
accept end_date		prompt 'End   Date (MM/DD) : ' 
accept   top_x_rows 	prompt 'Top x rows (between 3 and 10)     : '

@plusenv
@big_job
col sql_id	format a13
col module 	format a30 trunc
col stime	format a05	head 'Date
col pct_dreads	format 99.9
col pct_iowait	format 99.9
col rowrank	noprint

break on stime skip 1

select   * 
from
(
select 	 to_char(sn.begin_interval_time, 'MM/DD')			stime
	,sqs.module							module
	,sqs.sql_id							sql_id
	,sum(DISK_READS_DELTA)						dreads
	,100*ratio_to_report(sum(DISK_READS_DELTA)) over ()		pct_dreads
	,sum(IOWAIT_DELTA)						iowait
	,100*ratio_to_report(sum(IOWAIT_DELTA)) over ()			pct_iowait
	,row_number() over (partition by  to_char(sn.begin_interval_time, 'MM/DD') order by sum(DISK_READS_DELTA) desc) rowrank
from 	 dba_hist_sqlstat 	sqs
	,dba_hist_snapshot	sn
where	 sqs.snap_id		= sn.snap_id
and	 sqs.dbid		= sn.dbid
and	 sqs.instance_number	= sn.instance_number
and 	 to_char(sn.begin_interval_time,'MM/DD') 	between '&&start_date'
						            and '&&end_date'
group by to_char(sn.begin_interval_time, 'MM/DD')
	,sqs.module
	,sqs.sql_id
)
where	 rowrank 		<= &&top_x_rows
order by stime
	,rowrank
;
@big_job_off
