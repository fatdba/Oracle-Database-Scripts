-- librarycache_locks.sql is the script name
-- Not written by me but through MetaLink article 169139.1
--
-- session a: exec dbms_lock.sleep(600)
-- session b: grant execute on dbms_lock to scott
-- 
-- session b will hang, providing data for this query

@clears

variable v_address varchar2(20)

col to_name format a30 head 'LOCKED OBJECT'
col to_owner format a30 head 'OBJECT OWNER'
col address new_value v_address 

select /*+ ordered */ 
/*
KGLLKUSE session address
KGLLKHDL Pin/Lock handle
KGLLKMOD/KGLLKREQ Holding/requested mode
  0 no lock/pin held
  1 null mode
  2 share mode
  3 exclusive mode
KGLLKTYPE Pin/Lock 
*/
	w1.sid waiting_session
	, h1.sid holding_session
	, w.kgllktype lock_or_pin
	, w.kgllkhdl address
	, decode(h.kgllkmod, 0, 'None', 1, 'Null', 2, 'Share', 3, 'Exclusive', 'Unknown') mode_held
	, decode(w.kgllkreq, 0, 'None', 1, 'Null', 2, 'Share', 3, 'Exclusive', 'Unknown') mode_requested
from 
	dba_kgllock w
	, dba_kgllock h
	, v$session w1
	, v$session h1
where 
(
	(
		(h.kgllkmod != 0) 
		and (h.kgllkmod != 1)
		and ((h.kgllkreq = 0) or (h.kgllkreq = 1))
	)
	and
	(
		(
			(w.kgllkmod = 0) 
			or (w.kgllkmod= 1)
	)
	and (
		(
			w.kgllkreq != 0) 
			and (w.kgllkreq != 1)
		)
	)
)
and w.kgllktype = h.kgllktype
and w.kgllkhdl = h.kgllkhdl
and w.kgllkuse = w1.saddr
and h.kgllkuse = h1.saddr
/ 

-- locate the locked objects
prompt The following SQL will locate locked objects:
prompt
prompt select to_owner,to_name from v$object_dependency where to_address = '&&v_address'
prompt
prompt ! See MetaLink article 169139.1 for more information !
prompt
