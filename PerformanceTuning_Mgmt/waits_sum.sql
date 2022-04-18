--  #DESC:	show wait events for sessions - order by session id

set pagesi 2000
col cnt	   format 99999  		heading "Cnt"
col event  format a32  			heading "Wait Event" trunc

SELECT 	 event, count(*) cnt
FROM   	 v$session_wait
WHERE  	 event not in ('SQL*Net message from client'
		      ,'Null event'
		      ,'rdbms ipc message'
		      ,'rdbms ipc reply'
		      ,'pmon timer'
		      )
group by event
ORDER BY cnt desc
;
ttitle off
