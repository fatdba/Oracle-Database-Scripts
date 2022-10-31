--
-- Author: Prashant 'The FatDBA' Dixit
--
col dbid format 999999999999
col interval_minutes format 99999 head 'INTERVAL|MINUTES'
col retention_days format 999999 head 'RETENTION|DAYS'
col topnsql format a20


select
	dbid
	, (extract ( hour from snap_interval) * 60 )
	  + (extract ( minute from snap_interval) ) interval_minutes
	, extract( day from retention) retention_days
	, topnsql
from dba_hist_wr_control
/
