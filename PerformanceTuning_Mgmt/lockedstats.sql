@plusenv

col	 lana		format a14	head 'Last Analyzed'
col	 l		format a01	head 'L'
col	 n		format a01	head 'N'
col	 s		format a01	head 'S'
col	 tname		format a40	head 'Tablee Name'

with	 lstats as
(
select	 distinct
	 decode(STATTYPE_LOCKED,null,'','x')  	lstat
	,decode(stale_stats,'YES','x')		sstat
	,owner||'.'||table_name			tname
	,to_char(last_analyzed,'YYYYMMDD HH24:MI') lana
from 	 dba_tab_statistics  	
where 	 owner 			not in ('SYS','SYSTEM')
and	 object_type		= 'TABLE'
and	(STATTYPE_LOCKED 	is not null
      or stale_stats		= 'YES')
)
	,nstats as
(
select   decode(last_analyzed,null,'x')		nstat
	,owner||'.'||table_name                 tname
from 	 dba_tables
where    owner                  not in ('SYS','SYSTEM')
)
select 	 nstats.nstat	n
	,lstats.lstat	l
	,lstats.sstat	s
	,lstats.lana	lana
	,lstats.tname	tname
from 	 lstats, nstats
where	 lstats.tname	= nstats.tname (+)
order by 1,2,3,5
;
