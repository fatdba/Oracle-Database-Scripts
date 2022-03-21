@plusenv
col starttm	format a11	trunc heading 'Start Time'
col logio   	format 99999		head 'LogIOs'
col orauser    	format a06		head 'Oracle|User'	truncated
col cmnd	format a06		head 'Cmnd'		truncated 
col module	format a20 		head 'Module'	truncated
col osuser   	format a07					truncated
col sta   	format a1		head 'S'		truncated
col typ    	format a2		head 'Lk|Tp'
col ids    	format a14		head 'Id1-Id2'
col hldreq	format a3		head 'H-R'
col lmode	format 9		head 'M'
col object	format a45		head 'Locked Object'
col sidser	format a15  		head 'Sid,Serial<Blk'
col sp		format a10 		head 'Svr-Pgm'
col osuser	format a08		head 'OS User'		trunc
col event	format a18		head 'Wait Event'	trunc
col sqlid   	format a17		head 'SqlId:Child'

break on starttm on sidser on logio on sta on event on orauser on osuser on sp on sqlid on module skip 1
SELECT 	 /*+ RULE ordered */
	 to_char(to_date(t.start_time,'MM/DD/YY HH24:MI:SS'),'MMDD HH24MISS') starttm
        ,rpad(se.sid,4,' ')||','||lpad(se.serial#,5,' ')||decode(substr(se.blocking_session_status,1,1),'V','<',' ')||lpad(se.blocking_session,4,' ')	sidser
	,least(t.log_io,99999)			logio
	,se.status				sta
	,se.event				event
	,se.username 				orauser
	,se.osuser					osuser
	,lpad(pr.spid,5)||'-'||lpad(substr(nvl(pr.program,'null'),instr(pr.program,'(')+1,4),4)	sp
	,nvl(se.sql_id,se.prev_sql_id)||':'||decode(se.sql_id,null,'p',se.sql_child_number)		sqlid
	,se.module				module
	,lo.locked_mode				lmode
	,o.owner||'.'||substr(o.object_name,1,30)||decode(o.subobject_name,null,' ',':'||o.subobject_name) object
FROM     v$locked_object	lo
	,dba_objects		o
	,v$session		se
       	,v$transaction 		t
	,v$process		pr
WHERE 	 lo.session_id	= se.sid 
AND    	 lo.object_id 	= o.object_id
AND 	 se.paddr	= pr.addr
AND   	 se.taddr 	= t.addr 
ORDER BY 
	 t.start_time
	,object
	,lo.locked_mode desc
;
