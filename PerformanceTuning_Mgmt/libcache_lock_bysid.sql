-- This script outputs all the held or requested library cahce locks for a session.
-- req_or_held : 0 - held , otherwise waiting/requesting.
-- lock_mode    : 2 - shared , 3 -exclusive , 1 - not a lock(so I excluded from o/p) 
set linesi 200
set pagesi 2000
col command	format a05		head 'Cmd'		trunc
col event  	format a30  		head 'Wait Event' 	trunc
col sql_id   	format a15	        head 'sql_id'
col child       format 99
col mach	format a10		head 'Machine'		trunc
col module 	format a24  		head 'Module' 		trunc
col orauser    	format a12		head 'Oracle|User'	trunc
col status    	format a1		head 'S'	trunc
col p1     	format 999999999999999	head 'P1'
col p2     	format 999999999999999	head 'P2'
col p3     	format 999999  		head 'P3'
col sid	   	format a05  		head 'SID'
col sqlid	format a15    	        head 'SQL Id'
col  object 	format a50  		
col wtim   	format 99999999  		head 'Wait|Time'
col blocking_session   	format 9999  		head 'blck|sess'
col last_call_et   	format 9999999  		head 'last|callet'

SELECT 	 
	/*+ RULE */
	a.kgllkhdl,
	a.kgllkreq  req_or_held
        ,a.kgllkmod  lock_mode
	,a.kglnaobj object
FROM     v$session              se
        ,x$kgllk        a
WHERE   
      se.saddr       = a.kgllkses
AND   se.sid=&sid 
and   a.kgllkmod!=1     -- this is b/c kgllkmod 1 is not a lock indeed. 2 - shared , 3 - exclusive.
ORDER BY a.kgllkreq,a.kgllkmod
;

ttitle off
set pause off
