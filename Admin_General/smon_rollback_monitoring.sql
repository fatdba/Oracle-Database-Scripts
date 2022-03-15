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
PROMPT----- Script: smon_rollback_monitoring.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Version: V1.5 (Date: 04-02-2010)
PROMPT-----
PROMPT-----
PROMPT-----

spool SMON_RollBack_Progress.lst
Prompt
Prompt Script will run for 10 minutes and checks rollback status from x$ktuxe every 2 mins
Prompt -----------------------------------------------------------------------------------
Prompt
set lines 120
col useg format a30
alter session set nls_date_format='dd-mon-yyyy hh24:mi:ss';

select sysdate,b.name useg, b.inst# instid, b.status$ status, a.ktuxeusn
xid_usn, a.ktuxeslt xid_slot, a.ktuxesqn xid_seq, a.ktuxesiz undoblocks
from x$ktuxe a, undo$ b
where a.ktuxesta = 'ACTIVE' and a.ktuxecfl like '%DEAD%'
and a.ktuxeusn = b.us#;

Prompt
Prompt ------------------------------------------------------------------------------------

Prompt sleeping for 2 mins ....
exec dbms_lock.sleep(120);

select sysdate,b.name useg, b.inst# instid, b.status$ status, a.ktuxeusn
xid_usn, a.ktuxeslt xid_slot, a.ktuxesqn xid_seq, a.ktuxesiz undoblocks
from x$ktuxe a, undo$ b
where a.ktuxesta = 'ACTIVE' and a.ktuxecfl like '%DEAD%'
and a.ktuxeusn = b.us#;

Prompt
Prompt ------------------------------------------------------------------------------------

Prompt sleeping for 2 mins ....
exec dbms_lock.sleep(120);

select sysdate,b.name useg, b.inst# instid, b.status$ status, a.ktuxeusn
xid_usn, a.ktuxeslt xid_slot, a.ktuxesqn xid_seq, a.ktuxesiz undoblocks
from x$ktuxe a, undo$ b
where a.ktuxesta = 'ACTIVE' and a.ktuxecfl like '%DEAD%'
and a.ktuxeusn = b.us#;

Prompt
Prompt ------------------------------------------------------------------------------------

Prompt sleeping for 2 mins ....
exec dbms_lock.sleep(120);

select sysdate,b.name useg, b.inst# instid, b.status$ status, a.ktuxeusn
xid_usn, a.ktuxeslt xid_slot, a.ktuxesqn xid_seq, a.ktuxesiz undoblocks
from x$ktuxe a, undo$ b
where a.ktuxesta = 'ACTIVE' and a.ktuxecfl like '%DEAD%'
and a.ktuxeusn = b.us#;

Prompt
Prompt ------------------------------------------------------------------------------------


Prompt sleeping for 2 mins ....
exec dbms_lock.sleep(120);

select sysdate,b.name useg, b.inst# instid, b.status$ status, a.ktuxeusn
xid_usn, a.ktuxeslt xid_slot, a.ktuxesqn xid_seq, a.ktuxesiz undoblocks
from x$ktuxe a, undo$ b
where a.ktuxesta = 'ACTIVE' and a.ktuxecfl like '%DEAD%'
and a.ktuxeusn = b.us#;

Prompt ** END OF SCRIPT **
spool off
