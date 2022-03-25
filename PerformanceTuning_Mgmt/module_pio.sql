@plusenv	
@@sm
set head off
col currtime	format a08		
select 'Current Time =>', to_char(sysdate,'HH24:MI:SS') currtime, to_char(new_time(sysdate,'GMT','PDT'),'HH24:MI:SS') pdt from dual
;
set head on
col betime	format a14		head 'HH:MM:SS-MM:SS'
col lcpu        format 999.9            head 'Low|Cpu%'
col hcpu        format 999.9            head 'High|Cpu%'
col LReads	format 99999999		head 'Logical|Reads'
col module 	format a40  		head 'Module' 		trunc
col PReads	format 9999999		head '*Phys*|Reads'
col SParse	format 99999		head 'Soft|Parses'
col AvgPGAk	format 999999		head 'Avg|PGAk'
col SumPGAmb	format 999999		head 'Sum|PGA MB'
col pct		format 99.99		head 'PReads%'
col cnt		format 999		head 'Ses|Cnt'

break on betime on lcpu on hcpu

with 	 totpread as
(
select sum(physical_reads) spread from v$sessmetric
)
	,modpread as
(
select	 to_char(new_time(begin_time,'GMT','PST'),'HH24:MI:SS')||'-'||to_char(end_time,'MI:SS')		betime
	,sum(logical_reads)	LReads
	,sum(physical_reads)	PReads
	,sum(soft_parses)	SParse
	,avg(pga_memory)/1024	AvgPGAk
	,sum(pga_memory)/1024/1024	SumPGAmb
	,count(*)		cnt
	,nvl(s.module,'<'||substr(s.machine,1,instr(s.machine,'.')-1)||'>')	module
from 	 v$sessmetric	sm
	,v$session	s
where	 sm.session_id	= s.sid
and	 physical_reads > 0
group by nvl(s.module,'<'||substr(s.machine,1,instr(s.machine,'.')-1)||'>'), to_char(new_time(begin_time,'GMT','PST'),'HH24:MI:SS')||'-'||to_char(end_time,'MI:SS')
order by PReads desc
)
select * from
(
select	 betime
        ,ccpu.lcpu lcpu
        ,ccpu.hcpu hcpu
	,PReads
	,(PReads/spread)*100		pct
	,LReads
	,SParse
	,AvgPGAk
	,SumPGAmb
	,cnt
	,module
from 	 modpread
	,totpread
	,(select min(value) lcpu, max(value) hcpu from v$sysmetric where METRIC_NAME='Host CPU Utilization (%)') ccpu
)
where	 rownum <16
;
