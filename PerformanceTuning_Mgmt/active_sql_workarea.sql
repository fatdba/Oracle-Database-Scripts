@plusenv
col sidser	format a10  		head 'Sid,Serial'
col operid	format 999		head 'Oper|Id'
col oper	format a14  		head 'Oper Type'	trunc
col esizek	format 9,999,999  	head 'EstSizeK '	
col csizek	format 99,999,999  	head 'CurSizeK '
col msizek	format 9,999,999  	head 'MaxSizeK'
col p		format 9		
col tsizem	format 999,999		head 'TempSizeM'
col sqlid_c	format a17		head 'SqlId:Child'
col qcsid	format 9999		head 'QC'
col sexecs	format a05		head 'Start'
col minago	format 999		head 'Min|Ago'
col module	format a30		head 'Module'		trunc
col event	format a30		head 'Event'		trunc
col ts		format a08		head 'TempTS'		trunc

break on module on sql_id on qcsid skip 1 on sidser on report
compute sum of csizek on module
compute sum of csizek on report
compute sum of tsizem on report

select	 se.module			module
	,wa.sql_id||':'||se.sql_child_number			sqlid_c
	,wa.qcsid			qcsid
	,lpad(se.sid,4,' ')||','||lpad(se.serial#,5,' ')	sidser
	,to_char(wa.sql_exec_start,'HH24:MI')			sexecs
	,(sysdate - wa.sql_exec_start)*24*60			minago
	,se.event
       	,trunc(ACTUAL_MEM_USED/1024) 	csizeK
	,operation_id			operid
       	,operation_type 		oper
       	,trunc(EXPECTED_SIZE/1024) 	esizeK
       	,trunc(MAX_MEM_USED/1024) 	msizeK
       	,NUMBER_PASSES 			p
	,tablespace			ts
       	,trunc(TEMPSEG_SIZE/1024/1024) 	tsizeM
FROM 	 V$SQL_WORKAREA_ACTIVE 	wa
	,v$session		se
where	 wa.sid		= se.sid
ORDER BY module
	,sqlid_c
	,operid
	,oper
	,sidser
;
