--This script outputs all the held/requested library cache pins of a session. 
--REQ_OR_HELD : 0 - held , otherwise waiting/requesting. 
--REQ_MODE for held pins: 2 - shared , 3 - exclusive.  

set linesi 200
set verify off
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
col  object 	format a30  		
col wtim   	format 99999999  		head 'Wait|Time'
col blocking_session   	format 9999  		head 'blck|sess'
col last_call_et   	format 9999999  		head 'last|callet'

SELECT 	 
	/*+ RULE */
	a.kglpnhdl    pinhandle
	,a.kglpnreq    req_or_held
	,a.kglpnmod  pin_mode
	,se.event
	,se.last_call_et
FROM     v$session              se
        ,x$kglpn        a
WHERE   
      se.saddr       = a.kglpnses
AND      se.sid=&sid
ORDER BY a.kglpnreq,a.kglpnmod
;

ttitle off
set pause off
