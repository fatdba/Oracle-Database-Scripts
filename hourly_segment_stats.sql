--
-- Hourly segment statistics for the last 4 hours from AWR
--
--
-- Author : Prashant Dixit
@big_job
@plusenv

col objid	format 9999999
col sname	format a45		head 'Segment Name'			word_wrapped
col stype	format a06		head 'SegTyp'				trunc
col lread	format 99999999999	head 'Logical Reads|Latest'
col pread	format 99999999999	head 'Phys Reads|Latest'
col bbw3	format 9999999		head 'BBW|3Hours|Ago'
col bbw2	format 9999999		head 'BBW|2Hours|Agp'
col bbw1	format 9999999		head 'BBW|1Hour |Ago'
col bbw		format 9999999		head 'BBW|Latest'
col itlw3	format 9999		head 'ITLW|3Hours|Ago'
col itlw2	format 9999		head 'ITLW|2Hours|Ago'
col itlw1	format 9999		head 'ITLW|1Hour |Ago'
col itlw	format 9999		head 'ITLW|Latest'
col rowlk3	format 9999999		head 'ROWLW|3Hours|Ago'
col rowlk2	format 9999999		head 'ROWLW|2Hours|Ago'
col rowlk1	format 9999999		head 'ROWLW|1Hour|Ago'
col rowlk	format 9999999		head 'ROWLW|Latest'
col pct_lread	format 99		head 'L%'
col pct_pread	format 99		head 'P%'

with	 SEGSTAT3 as
(
select	 * from
(
select	 o.owner||'.'||object_name||decode(subobject_name,null,' ',': '||subobject_name)			sname
	,decode(o.object_type,	 'TABLE','TAB'
				,'TABLE PARTITION','TABPART'
				,'TABLE SUBPARTITION','TABSUBP'
				,'INDEX','IDX'
				,'INDEX PARTITION','IDXPART'
				,'INDEX SUBPARTITION','IDXSUB'
				,o.object_type)					stype
	,sum(LOGICAL_READS_DELTA)			lread
	,100*ratio_to_report(sum(LOGICAL_READS_DELTA)) over()	pct_lread
	,sum(PHYSICAL_READS_DELTA)			pread
	,100*ratio_to_report(sum(PHYSICAL_READS_DELTA)) over()	pct_pread
	,sum(BUFFER_BUSY_WAITS_DELTA)			bbw
	,sum(ITL_WAITS_DELTA)				itlw
	,sum(ROW_LOCK_WAITS_DELTA)			rowlk
from 	 dba_hist_seg_stat	s
	,dba_hist_snapshot	sn
	,dba_objects		o
where	 BEGIN_INTERVAL_TIME		between sysdate-4/24 and sysdate-3/24
and	 o.owner			not in ('SYS')
and	 sn.snap_id			= s.snap_id
and	 s.obj#				= o.object_id
group by o.owner||'.'||object_name||decode(subobject_name,null,' ',': '||subobject_name)			
	,decode(o.object_type,	 'TABLE','TAB'
				,'TABLE PARTITION','TABPART'
				,'TABLE SUBPARTITION','TABSUBP'
				,'INDEX','IDX'
				,'INDEX PARTITION','IDXPART'
				,'INDEX SUBPARTITION','IDXSUB'
				,o.object_type)					
order by sum(LOGICAL_READS_DELTA) desc
)
where	 rownum 	<=100
)
	,SEGSTAT2 as
(
select	 * from
(
select	 o.owner||'.'||object_name||decode(subobject_name,null,' ',': '||subobject_name)			sname
	,decode(o.object_type,	 'TABLE','TAB'
				,'TABLE PARTITION','TABPART'
				,'TABLE SUBPARTITION','TABSUBP'
				,'INDEX','IDX'
				,'INDEX PARTITION','IDXPART'
				,'INDEX SUBPARTITION','IDXSUB'
				,o.object_type)					stype
	,sum(LOGICAL_READS_DELTA)			lread
	,100*ratio_to_report(sum(LOGICAL_READS_DELTA)) over()	pct_lread
	,sum(PHYSICAL_READS_DELTA)			pread
	,100*ratio_to_report(sum(PHYSICAL_READS_DELTA)) over()	pct_pread
	,sum(BUFFER_BUSY_WAITS_DELTA)			bbw
	,sum(ITL_WAITS_DELTA)				itlw
	,sum(ROW_LOCK_WAITS_DELTA)			rowlk
from 	 dba_hist_seg_stat	s
	,dba_hist_snapshot	sn
	,dba_objects		o
where	 BEGIN_INTERVAL_TIME		between sysdate-3/24 and sysdate-2/24
and	 o.owner			not in ('SYS')
and	 sn.snap_id			= s.snap_id
and	 s.obj#				= o.object_id
group by o.owner||'.'||object_name||decode(subobject_name,null,' ',': '||subobject_name)			
	,decode(o.object_type,	 'TABLE','TAB'
				,'TABLE PARTITION','TABPART'
				,'TABLE SUBPARTITION','TABSUBP'
				,'INDEX','IDX'
				,'INDEX PARTITION','IDXPART'
				,'INDEX SUBPARTITION','IDXSUB'
				,o.object_type)					
order by sum(LOGICAL_READS_DELTA) desc
)
where	 rownum 	<=100
)
	,SEGSTAT1 as
(
select	 * from
(
select	 o.owner||'.'||object_name||decode(subobject_name,null,' ',': '||subobject_name)			sname
	,decode(o.object_type,	 'TABLE','TAB'
				,'TABLE PARTITION','TABPART'
				,'TABLE SUBPARTITION','TABSUBP'
				,'INDEX','IDX'
				,'INDEX PARTITION','IDXPART'
				,'INDEX SUBPARTITION','IDXSUB'
				,o.object_type)					stype
	,sum(LOGICAL_READS_DELTA)			lread
	,100*ratio_to_report(sum(LOGICAL_READS_DELTA)) over()	pct_lread
	,sum(PHYSICAL_READS_DELTA)			pread
	,100*ratio_to_report(sum(PHYSICAL_READS_DELTA)) over()	pct_pread
	,sum(BUFFER_BUSY_WAITS_DELTA)			bbw
	,sum(ITL_WAITS_DELTA)				itlw
	,sum(ROW_LOCK_WAITS_DELTA)			rowlk
from 	 dba_hist_seg_stat	s
	,dba_hist_snapshot	sn
	,dba_objects		o
where	 BEGIN_INTERVAL_TIME		between sysdate-2/24 and sysdate-1/24
and	 o.owner			not in ('SYS')
and	 sn.snap_id			= s.snap_id
and	 s.obj#				= o.object_id
group by o.owner||'.'||object_name||decode(subobject_name,null,' ',': '||subobject_name)			
	,decode(o.object_type,	 'TABLE','TAB'
				,'TABLE PARTITION','TABPART'
				,'TABLE SUBPARTITION','TABSUBP'
				,'INDEX','IDX'
				,'INDEX PARTITION','IDXPART'
				,'INDEX SUBPARTITION','IDXSUB'
				,o.object_type)					
order by sum(LOGICAL_READS_DELTA) desc
)
where	 rownum 	<=100
)
	,SEGSTAT0 as
(
select	 * from
(
select	 o.owner||'.'||object_name||decode(subobject_name,null,' ',': '||subobject_name)			sname
	,decode(o.object_type,	 'TABLE','TAB'
				,'TABLE PARTITION','TABPART'
				,'TABLE SUBPARTITION','TABSUBP'
				,'INDEX','IDX'
				,'INDEX PARTITION','IDXPART'
				,'INDEX SUBPARTITION','IDXSUB'
				,o.object_type)					stype
	,sum(LOGICAL_READS_DELTA)			lread
	,100*ratio_to_report(sum(LOGICAL_READS_DELTA)) over()	pct_lread
	,sum(PHYSICAL_READS_DELTA)			pread
	,100*ratio_to_report(sum(PHYSICAL_READS_DELTA)) over()	pct_pread
	,sum(BUFFER_BUSY_WAITS_DELTA)			bbw
	,sum(ITL_WAITS_DELTA)				itlw
	,sum(ROW_LOCK_WAITS_DELTA)			rowlk
from 	 dba_hist_seg_stat	s
	,dba_hist_snapshot	sn
	,dba_objects		o
where	 BEGIN_INTERVAL_TIME		between sysdate-1/24 and sysdate
and	 o.owner			not in ('SYS')
and	 sn.snap_id			= s.snap_id
and	 s.obj#				= o.object_id
group by o.owner||'.'||object_name||decode(subobject_name,null,' ',': '||subobject_name)			
	,decode(o.object_type,	 'TABLE','TAB'
				,'TABLE PARTITION','TABPART'
				,'TABLE SUBPARTITION','TABSUBP'
				,'INDEX','IDX'
				,'INDEX PARTITION','IDXPART'
				,'INDEX SUBPARTITION','IDXSUB'
				,o.object_type)					
order by sum(LOGICAL_READS_DELTA) desc
)
where	 rownum 	<=20
)
SELECT	 s0.sname
	,s0.stype
	,'|'
	--,s3.lread
	,s3.pct_lread
	--,s3.pread
	,s3.pct_pread
	,s3.bbw		bbw3
	,s3.itlw	itlw3
	,s3.rowlk	rowlk3
	,'|'
	--,s2.lread
	,s2.pct_lread
	--,s2.pread
	,s2.pct_pread
	,s2.bbw		bbw2
	,s2.itlw	itlw2
	,s2.rowlk	rowlk2
	,'|'
	--,s1.lread
	,s1.pct_lread
	--,s1.pread
	,s1.pct_pread
	,s1.bbw		bbw1
	,s1.itlw	itlw1
	,s1.rowlk	rowlk1
	,'|'
	,s0.lread
	,s0.pct_lread
	,s0.pread
	,s0.pct_pread
	,s0.bbw		bbw
	,s0.itlw	itlw
	,s0.rowlk	rowlk
from	 segstat0	s0
	,segstat1	s1
	,segstat2	s2
	,segstat3	s3
where	 s0.sname	= s1.sname (+)
and	 s0.sname	= s2.sname (+)
and	 s0.sname	= s3.sname (+)
order by s0.pct_lread desc
;
@big_job_off
