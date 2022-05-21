prompt
prompt
prompt === session waits (snap-session-waits.sql) ===;

col command	format a05		head 'Cmnd'		trunc
col event  	format a16  		head 'Wait Event' 	trunc
col hash   	format 9999999999	head 'Hash|Value'
col mach	format a10		head 'Machine'		trunc
col module 	format a24  		head 'Module' 		trunc
col orauser    	format a06		head 'Oracle|User'	trunc
col p1     	format 99999999999999999999	head 'P1'
col p2     	format 99999999999999999999	head 'P2'
col p1txt  	format a07					trunc
col p2txt  	format a07					trunc
col p3     	format 999  		head 'P3'
col p3txt  	format a07					trunc
col clpid   	format a05  		head 'ClPID'
col sid	   	format a05  		head 'SesId'
col sqlh	format 9999999999	head 'SQL Hash|Value'
col state  	format a07  		head 'Wait|State' 	trunc
col wtim   	format 999  		head 'Wt|Tm'

SELECT 	 
	/*+ RULE */
	 lpad(sw.sid,5,' ')					sid
	,se.process						clpid
	,se.username 						orauser
	,sw.event
	,decode(se.module,null,'. '||substr(se.username,1,6),se.module)	module
       	,decode (se.command
	       , 0, '      '
	       , 1, 'CR TB'
               , 2, 'ISRT'
	       , 3, 'SEL'
	       , 4, 'CR CL'
	       , 5, 'AL CL'
	       , 6, 'UPDT'
	       , 7, 'DEL'
	       , 8, 'DR'
	       , 9, 'CR IX'
	       ,10, 'DR IX'
	       ,11, 'AL IX'
	       ,12, 'DR TB'
	       ,15, 'AL TB'
	       ,17, 'GRANT'
	       ,18, 'REVOK'
	       ,19, 'CRSYN'
	       ,20, 'DRSYN'
	       ,21, 'CR VW'
	       ,22, 'DR VW'
	       ,26, 'LK TB'
	       ,27, 'NO OP'
	       ,28, 'RENM'
	       ,29, 'CMNT'
	       ,30, 'AUDIT'
	       ,31, 'NOAUD'
	       ,32, 'CR DBL'
	       ,33, 'DR DBL'
	       ,34, 'CR DB'
	       ,35, 'AL DB'
	       ,36, 'CR RBS'
	       ,37, 'AL RBS'
	       ,38, 'DR RBS'
	       ,39, 'CR TS'
	       ,40, 'AL TS'
	       ,41, 'DR TS'
	       ,42, 'AL SES'
	       ,43, 'AL USR'
	       ,44, 'COMMIT'
	       ,45, 'ROLLBK'
	       ,46, 'SAVEPT'
	       ,47, 'PL/SQL'
	       ,62, 'AN TB'
	       ,63, 'AN IX'
	       ,64, 'AN CL'
	       ,85, 'TR TB'
	       ,    to_char(se.command)
	       )               	command
	,se.sql_hash_value	hash
       	,sw.p1              	p1 
       	,sw.p2              	p2 
       	,sw.p3              	p3 
       	,sw.state
       	,sw.wait_time 		wtim
FROM   	 v$session		se
        ,v$session_wait		sw
WHERE  	 sw.event not in ('SQL*Net message from client'
		      ,'Null event'
		      ,'queue messages'
		      ,'rdbms ipc message'
		      ,'rdbms ipc reply'
		      ,'pmon timer'
		      ,'smon timer'
		      ,'PL/SQL lock timer'
		      )
AND	 sw.sid		= se.sid (+)
ORDER BY sw.event desc, p1 
;
ttitle off
