PROMPT
PROMPT
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT------                 /)  (\
PROMPT------            .-._((,~~.))_.-,
PROMPT------             `-.   @@   ,-'
PROMPT------               / ,o--o. \
PROMPT------              ( ( .__. ) )
PROMPT------               ) `----' (
PROMPT------              /          \
PROMPT------             /            \
PROMPT------            /              \
PROMPT------    "The Silly Cow"
PROMPT----- Script: showlock.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Performance Management and Issue Identification
PROMPT----- Version: V1.2 (Date: 13-10-2018)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~set linesize 155
set pagesize 60
column osuser heading 'OS|Username' format a7 truncate
column process heading 'OS|Process' format a7 truncate
column machine heading 'OS|Machine' format a10 truncate
column program heading 'OS|Program' format a25 truncate
column object heading 'Database|Object' format a25 truncate
column lock_type heading 'Lock|Type' format a4 truncate
column mode_held heading 'Mode|Held' format a15 truncate
column mode_requested heading 'Mode|Requested' format a10 truncate
column sid heading 'SID' format 999
column username heading 'Oracle|Username' format a7 truncate
column image heading 'Active Image' format a20 truncate
column sid format 99999
col waiting_session head 'WAITER' format 9999
col holding_session head 'BLOCKER' format 9999

select /*+ ordered */
	--b.kaddr,
	c.sid, c.inst_id,
	lock_waiter.waiting_session,
	lock_blocker.holding_session,
	c.program,
	c.osuser,
	c.machine,
	c.process,
	decode(u.name,
		null,'',
		u.name||'.'||o.name
	) object,
	c.username,
	decode
	(
		b.type,
		'BL', 'Buffer hash table instance lock',
		'CF', 'Control file schema global enqueue lock',
		'CI', 'Cross-instance function invocation instance lock',
		'CU', 'Cursor bind lock',
		'DF', 'Data file instance lock',
		'DL', 'direct loader parallel index create lock',
		'DM', 'Mount/startup db primary/secondary instance lock',
		'DR', 'Distributed recovery process lock',
		'DX', 'Distributed transaction entry lock',
		'FS', 'File set lock',
		'IN', 'Instance number lock',
		'IR', 'Instance recovery serialization global enqueue lock',
		'IS', 'Instance state lock',
		'IV', 'Library cache invalidation instance lock',
		'JQ', 'Job queue lock',
		'KK', 'Thread kick lock',
		'LA','Library cache lock instance lock (A..P=namespace);',
		'LB','Library cache lock instance lock (A..P=namespace);',
		'LC','Library cache lock instance lock (A..P=namespace);',
		'LD','Library cache lock instance lock (A..P=namespace);',
		'LE','Library cache lock instance lock (A..P=namespace);',
		'LF','Library cache lock instance lock (A..P=namespace);',
		'LG','Library cache lock instance lock (A..P=namespace);',
		'LH','Library cache lock instance lock (A..P=namespace);',
		'LI','Library cache lock instance lock (A..P=namespace);',
		'LJ','Library cache lock instance lock (A..P=namespace);',
		'LK','Library cache lock instance lock (A..P=namespace);',
		'LL','Library cache lock instance lock (A..P=namespace);',
		'LM','Library cache lock instance lock (A..P=namespace);',
		'LN','Library cache lock instance lock (A..P=namespace);',
		'LO','Library cache lock instance lock (A..P=namespace);',
		'LP','Library cache lock instance lock (A..P=namespace);',
		'MM', 'Mount definition global enqueue lock',
		'MR', 'Media recovery lock',
		'NA', 'Library cache pin instance lock (A..Z=namespace)',
		'NB', 'Library cache pin instance lock (A..Z=namespace)',
		'NC', 'Library cache pin instance lock (A..Z=namespace)',
		'ND', 'Library cache pin instance lock (A..Z=namespace)',
		'NE', 'Library cache pin instance lock (A..Z=namespace)',
		'NF', 'Library cache pin instance lock (A..Z=namespace)',
		'NG', 'Library cache pin instance lock (A..Z=namespace)',
		'NH', 'Library cache pin instance lock (A..Z=namespace)',
		'NI', 'Library cache pin instance lock (A..Z=namespace)',
		'NJ', 'Library cache pin instance lock (A..Z=namespace)',
		'NK', 'Library cache pin instance lock (A..Z=namespace)',
		'NL', 'Library cache pin instance lock (A..Z=namespace)',
		'NM', 'Library cache pin instance lock (A..Z=namespace)',
		'NN', 'Library cache pin instance lock (A..Z=namespace)',
		'NO', 'Library cache pin instance lock (A..Z=namespace)',
		'NP', 'Library cache pin instance lock (A..Z=namespace)',
		'NQ', 'Library cache pin instance lock (A..Z=namespace)',
		'NR', 'Library cache pin instance lock (A..Z=namespace)',
		'NS', 'Library cache pin instance lock (A..Z=namespace)',
		'NT', 'Library cache pin instance lock (A..Z=namespace)',
		'NU', 'Library cache pin instance lock (A..Z=namespace)',
		'NV', 'Library cache pin instance lock (A..Z=namespace)',
		'NW', 'Library cache pin instance lock (A..Z=namespace)',
		'NX', 'Library cache pin instance lock (A..Z=namespace)',
		'NY', 'Library cache pin instance lock (A..Z=namespace)',
		'NZ', 'Library cache pin instance lock (A..Z=namespace)',
		'PF', 'Password File lock',
		'PI', 'Parallel operation locks',
		'PS', 'Parallel operation locks',
		'PR', 'Process startup lock',
		'QA','Row cache instance lock (A..Z=cache)',
		'QB','Row cache instance lock (A..Z=cache)',
		'QC','Row cache instance lock (A..Z=cache)',
		'QD','Row cache instance lock (A..Z=cache)',
		'QE','Row cache instance lock (A..Z=cache)',
		'QF','Row cache instance lock (A..Z=cache)',
		'QG','Row cache instance lock (A..Z=cache)',
		'QH','Row cache instance lock (A..Z=cache)',
		'QI','Row cache instance lock (A..Z=cache)',
		'QJ','Row cache instance lock (A..Z=cache)',
		'QK','Row cache instance lock (A..Z=cache)',
		'QL','Row cache instance lock (A..Z=cache)',
		'QM','Row cache instance lock (A..Z=cache)',
		'QN','Row cache instance lock (A..Z=cache)',
		'QP','Row cache instance lock (A..Z=cache)',
		'QQ','Row cache instance lock (A..Z=cache)',
		'QR','Row cache instance lock (A..Z=cache)',
		'QS','Row cache instance lock (A..Z=cache)',
		'QT','Row cache instance lock (A..Z=cache)',
		'QU','Row cache instance lock (A..Z=cache)',
		'QV','Row cache instance lock (A..Z=cache)',
		'QW','Row cache instance lock (A..Z=cache)',
		'QX','Row cache instance lock (A..Z=cache)',
		'QY','Row cache instance lock (A..Z=cache)',
		'QZ','Row cache instance lock (A..Z=cache)',
		'RT', 'Redo thread global enqueue lock',
		'SC', 'System commit number instance lock',
		'SM', 'SMON lock',
		'SN', 'Sequence number instance lock',
		'SQ', 'Sequence number enqueue lock',
		'SS', 'Sort segment locks',
		'ST', 'Space transaction enqueue lock',
		'SV', 'Sequence number value lock',
		'TA', 'Generic enqueue lock',
		'TS', 'Temporary segment enqueue lock (ID2=0)',
		'TS', 'New block allocation enqueue lock (ID2=1)',
		'TT', 'Temporary table enqueue lock',
		'UN', 'User name lock',
		'US', 'Undo segment DDL lock',
		'WL', 'Being-written redo log instance lock',
		b.type
	) lock_type,
	decode
	(
		b.lmode,
		0, 'None',           /* Mon Lock equivalent */
		1, 'Null',           /* N */
		2, 'Row-S (SS)',     /* L */
		3, 'Row-X (SX)',     /* R */
		4, 'Share',          /* S */
		5, 'S/Row-X (SRX)',  /* C */
		6, 'Exclusive',      /* X */
		to_char(b.lmode)
	) mode_held,
	decode
	(
		b.request,
		0, 'None',           /* Mon Lock equivalent */
		1, 'Null',           /* N */
		2, 'Row-S (SS)',     /* L */
		3, 'Row-X (SX)',     /* R */
		4, 'Share',          /* S */
		5, 'S/Row-X (SSX)',  /* C */
		6, 'Exclusive',      /* X */
		to_char(b.request)
	) mode_requested
from
	GV$lock b
	,GV$session c
	,sys.user$ u
	,sys.obj$ o
	,( select * from sys.dba_waiters) lock_blocker
	,( select * from sys.dba_waiters) lock_waiter
where
b.sid = c.sid
and u.user# = c.user#
and o.obj#(+) = b.id1
and lock_blocker.waiting_session(+) = c.sid
and lock_waiter.holding_session(+) = c.sid
and c.username != 'SYS'
order by kaddr, lockwait
/
