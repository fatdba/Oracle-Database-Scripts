undef sql_id
undef bsnap
undef esnap
-- run latest_awr_snaps.sql to obtain snap_id's
@plusenv
col	sql_id		format a13
col 	name		format a12	trunc
col	pos		format 999
col	dtyp		format 99999
col	dtyps		format a15
col	lcap		format a17
col	value_string	format a40
col	snapid		format 999999
select 	 sql_id
	,snap_id		snapid
	,to_char(last_captured,'YYMMDD HH24:MI:SS') lcap
	,name
	,position		pos
	,datatype		dtyp
	,datatype_string	dtyps
	,value_string
from 	 DBA_HIST_SQLBIND 
where 	 SQL_ID			='&&sql_id'
and 	 SNAP_ID 		between &&bsnap and &&esnap
order by snap_id, last_captured, position
;
