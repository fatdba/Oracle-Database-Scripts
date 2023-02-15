col command	format a06					trunc
col hash	format 9999999999	head 'SQL Hash'
col logontm   	format a09	     	head 'Logon|Time'	trunc
col mach	format a10 		head 'Machine'		trunc
col module	format a22					trunc
col orauser    	format a08					trunc
col osuser   	format a08					trunc
col parent   	format a5					trunc
col phash	format 9999999999	head 'Prev Hash'
col rb		format 99
col secnt 	format 9999		head 'Sess|Count'
col shadow   	format a5    
col sidser 	format a10  		head 'Sess-Ser#'
col svr   	format a1 		head 'S'		trunc
col lfsplts	format 9999		head 'Leaf|Splt'
col lfsplts9	format 9999		head 'Leaf|Splt9'
col brsplts	format 99		head 'Br|Sp'

SELECT
	 lpad(se.sid,4,' ')||'-'||lpad(se.serial#,5,' ')	sidser
	,se.username 						orauser
	,substr(se.machine,1,instr(se.machine,'.')-1)    	mach
	,se.module						module
	,se.osuser   						osuser
        ,to_char(se.logon_time,'MMDD HH24MI')			logontm
	,se.prev_hash_value 					phash
	,se.sql_hash_value 					hash
	,s318.value					lfsplts
	,s319.value					lfsplts9
	,s320.value					brsplts
FROM 	 v$sesstat 		s318
	,v$sesstat		s319
	,v$sesstat		s320
	,v$session 		se
WHERE 	 se.sid 		= s318.sid;
AND	 se.sid			= s319.sid
AND	 se.sid			= s320.sid
AND   	 s318.statistic#	= 318	
AND   	 s318.statistic#	= 319	
AND   	 s320.statistic#	= 320	
ORDER BY s318.value
;
