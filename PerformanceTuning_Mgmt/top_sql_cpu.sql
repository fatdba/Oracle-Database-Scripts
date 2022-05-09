set lines 190
col sql_id		format a15		head 'SQL Id'
col pui 		format 999		head 'UId'
col uname		format a11
col cn 			format 99		head 'CN'
col ue			format 99
col parse_usr		format a08		head 'ParsgUsr' 	trunc
col lltime		format a13		head 'Last LoadTime'
col latime		format a10		head 'Last ActvTime'
col o			format a01		head 'O'		trunc
col cpusecs		format 99999999		head 'CPU Secs'
col elapsecs		format 99999999		head 'ElapSecs'
col execk		format 9999999		head 'ExecsK'
col paprun 		format 9.9 		head 'Prs|pX'
col cprun 		format 99999999		head 'CPUns|PerEx'
col bgprun 		format 9999999 		head 'BGets|PerEx'
col drprun 		format 999999 		head 'DReads|PerEx'
col rwprun 		format 99999 		head 'RwsP|PerEx'
col awprun 		format 999.9 		head 'AppW|PerEx'
col cwprun 		format 999.9 		head 'ConW|PerEx'
col iowprun 		format 999.9 		head 'IOW|PerEx'
col phash		format 9999999999	head 'Plan Hash'
col module		format a24	trunc	head 'Module'
col o			format a01
col s			format a01	trunc
col sqltext		format a40	trunc
col er			format 999
col pgmid		format 9999999		head 'Pgm Id'
col pct			format 99.9		head 'Pct|CPU'

with totcpu as
(
select sum(cpu_time) sumcpu from v$sqlstats
where last_active_time > sysdate-30
)
select * from
(
select 	 s.sql_id
	,s.plan_hash_value				phash
	,to_char(s.last_active_time,'MMDD HH24:MI')  	latime
	,s.cpu_time/1000000				cpusecs
	,100*(s.cpu_time/tc.sumcpu)			pct
	,s.elapsed_time/1000000				elapsecs
	,least(s.executions/1000,99999999)		execk
	,rank() over(partition by 1 order by s.executions desc)	er
       	,least(s.cpu_time/s.executions,99999999)	cprun
       	,least(s.buffer_gets/s.executions,999999)	bgprun
	--,least((s.disk_reads/s.executions),999999)	drprun
       	--,least((s.rows_processed/s.executions),99999)	rwprun
	,q.module					module
	,substr(replace(s.sql_text,chr(13)),1,50)	sqltext
from 	(select * from v$sqlstats where last_active_time > sysdate-30 order by cpu_time desc) s
	,(select distinct sql_id,plan_hash_value,module from v$sql where parsing_schema_name  not in ('SYS','SYSTEM') ) q
	,totcpu	tc
where	 s.sql_id		= q.sql_id
and	 s.plan_hash_value	= q.plan_hash_value
and	 s.executions		> 0
order by s.cpu_time desc
)
where	 rownum	<31
;
