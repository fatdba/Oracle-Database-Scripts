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
PROMPT----- Script: lockingmother.sql 
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: Row Locking contention - TX level details 
PROMPT----- Version: V1.1 (Date: 04-02-2019)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
SET TERMOUT OFF;
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(instance_name, 17) current_instance FROM v$instance;
alter session set nls_date_format = 'DD-MON-YYYY HH24:MI:SS';
set linesize 400 pagesize 400
SET TERMOUT ON;
PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Row Level Locking session details                           |                  |
PROMPT | This is RAC aware script and will show all instances of TX Level RLCon |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

set linesize 400 pagesize 400
select
'INST_ID .................................................: '||x.INST_ID,
'Serial ID................................................: '||x.sid,
'Serial Num...............................................: '||x.serial#,
'User Name ...............................................: '||x.username,
'Session Status ..........................................: '||x.status,
'Program.................................................................................: '||x.program,
'Module ..................................................: '||x.Module,
'Action ..................................................: '||x.action,
'Machine .................................................: '||x.machine,
'OS_USER .................................................: '||x.OSUSER,
'Process .................................................: '||x.process,
'State ..............................................................................: '||x.State,
'EVENT ...................................................: '||x.event,
'SECONDS_IN_WAIT .........................................: '||x.SECONDS_IN_WAIT,
'LAST_CALL_ET ............................................: '||x.LAST_CALL_ET,
'SQL_ID ..................................................: '||x.sql_id,
'SQL_TEXT ................................................: '||SQL_TEXT,
'Logon Time ..............................................: '||TO_CHAR(x.LOGON_TIME, 'MM-DD-YYYY HH24:MI:SS') logontime,
'RunTime .................................................: '||ltrim(to_char(floor(x.LAST_CALL_ET/3600), '09')) || ':'
 || ltrim(to_char(floor(mod(x.LAST_CALL_ET, 3600)/60), '09')) || ':'
 || ltrim(to_char(mod(x.LAST_CALL_ET, 60), '09'))    RUNT
from   gv$sqlarea sqlarea
,gv$session x
where  x.sql_hash_value = sqlarea.hash_value
and    x.sql_address    = sqlarea.address
and    x.status='ACTIVE'
and x.event like '%row lock contention%'
and x.USERNAME is not null
and x.SQL_ADDRESS    = sqlarea.ADDRESS
and x.SQL_HASH_VALUE = sqlarea.HASH_VALUE
order by runt desc;

PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Blocking Tree                                               |
PROMPT | This output helps a DBA to identify all parent lockers in a pedigree   |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
col LOCK_TREE for a10
with lk as (select blocking_instance||'.'||blocking_session blocker, inst_id||'.'||sid waiter
 from gv$session where blocking_instance is not null and blocking_session is not null and username is not null)
 select lpad(' ',2*(level-1))||waiter lock_tree from
 (select * from lk
 union all
 select distinct 'root', blocker from lk
 where blocker not in (select waiter from lk))
 connect by prior waiter=blocker start with blocker='root';





PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : TX Row Lock Contention Details                              |
PROMPT | This report or result shows some extra and  imp piece of data          |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
col LOCK_MODE for a10
col OBJECT_NAME for a30
col SID_SERIAL for a19
col OSUSER for a9
col USER_STATUS for a14

SELECT DECODE (l.BLOCK, 0, 'Waiting', 'Blocking ->') user_status
,CHR (39) || s.SID || ',' || s.serial# || CHR (39) sid_serial
,(SELECT instance_name FROM gv$instance WHERE inst_id = l.inst_id)
conn_instance
,s.SID
,s.PROGRAM
,s.inst_id
,s.osuser
,s.machine
,DECODE (l.TYPE,'RT', 'Redo Log Buffer','TD', 'Dictionary'
,'TM', 'DML','TS', 'Temp Segments','TX', 'Transaction'
,'UL', 'User','RW', 'Row Wait',l.TYPE) lock_type
--,id1
--,id2
,DECODE (l.lmode,0, 'None',1, 'Null',2, 'Row Share',3, 'Row Excl.'
,4, 'Share',5, 'S/Row Excl.',6, 'Exclusive'
,LTRIM (TO_CHAR (lmode, '990'))) lock_mode
,ctime
--,DECODE(l.BLOCK, 0, 'Not Blocking', 1, 'Blocking', 2, 'Global') lock_status
,object_name
FROM
   gv$lock l
JOIN
   gv$session s
ON (l.inst_id = s.inst_id
AND l.SID = s.SID)
JOIN gv$locked_object o
ON (o.inst_id = s.inst_id
AND s.SID = o.session_id)
JOIN dba_objects d
ON (d.object_id = o.object_id)
WHERE (l.id1, l.id2, l.TYPE) IN (SELECT id1, id2, TYPE
FROM gv$lock
WHERE request > 0)
ORDER BY id1, id2, ctime DESC;





PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : What is blocking what .....                                 |
PROMPT | This is that old and popular simple output that everybody knows        |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
select l1.sid, ' IS BLOCKING ', l2.sid
from gv$lock l1, gv$lock l2 where l1.block =1 and l2.request > 0
and l1.id1=l2.id1
and l1.id2=l2.id2;




PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Some more on locking                                        |
PROMPT | Little more formatted data that abive output                           |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
col BLOCKING_STATUS for a120
select s2.inst_id,s1.username || '@' || s1.machine
 || ' ( SID=' || s1.sid || ' )  is blocking '
 || s2.username || '@' || s2.machine || ' ( SID=' || s2.sid || ' ) ' AS blocking_status
  from gv$lock l1, gv$session s1, gv$lock l2, gv$session s2
  where s1.sid=l1.sid and s2.sid=l2.sid and s1.inst_id=l1.inst_id and s2.inst_id=l2.inst_id
  and l1.BLOCK=1 and l2.request > 0
  and l1.id1 = l2.id1
  and l2.id2 = l2.id2
order by s1.inst_id;


PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : More on locks to read and analyze                           |
PROMPT | Thidata you can use for your deep drill downs                         |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+
col BLOCKER for a8
col WAITER for a10
col LMODE for a14
col REQUEST for a15

SELECT sid,
                                TYPE,
                                DECODE( block, 0, 'NO', 'YES' ) BLOCKER,
        DECODE( request, 0, 'NO', 'YES' ) WAITER,
        decode(LMODE,1,'    ',2,'RS',3,'RX',4,'S',5,'SRX',6,'X','NONE') lmode,
                                 decode(REQUEST,1,'    ',2,'RS',3,'RX',4,'S',5,'SRX',6,'X','NONE') request,
                                TRUNC(CTIME/60) MIN ,
                                ID1,
                                ID2,
        block
                        FROM  gv$lock
      where request > 0 OR block =1;



PROMPT
PROMPT +------------------------------------------------------------------------+
PROMPT | Report   : Some more on locks to read and analyze                      |
PROMPT | Thidata you can use for your deep drill downs                         |
PROMPT | Instance : &current_instance                                           |
PROMPT +------------------------------------------------------------------------+

select	sn.USERNAME,
	m.SID,
	sn.SERIAL#,
	m.TYPE,
	decode(LMODE,
		0, 'None',
		1, 'Null',
		2, 'Row-S (SS)',
		3, 'Row-X (SX)',
		4, 'Share',
		5, 'S/Row-X (SSX)',
		6, 'Exclusive') lock_type,
	decode(REQUEST,
		0, 'None', 
		1, 'Null',
		2, 'Row-S (SS)',
		3, 'Row-X (SX)', 
		4, 'Share', 
		5, 'S/Row-X (SSX)',
		6, 'Exclusive') lock_requested,
	m.ID1,
	m.ID2,
	t.SQL_TEXT
from 	v$session sn, 
	v$lock m , 
	v$sqltext t
where 	t.ADDRESS = sn.SQL_ADDRESS 
and 	t.HASH_VALUE = sn.SQL_HASH_VALUE 
and 	((sn.SID = m.SID and m.REQUEST != 0) 
or 	(sn.SID = m.SID and m.REQUEST = 0 and LMODE != 4 and (ID1, ID2) in
        (select s.ID1, s.ID2 
         from 	gv$lock S 
         where 	REQUEST != 0 
         and 	s.ID1 = m.ID1 
         and 	s.ID2 = m.ID2)))
order by sn.USERNAME, sn.SID, t.PIECE;
