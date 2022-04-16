@plusenv
set linesi 190
col sidser	format a14  		head 'Sid,Serial'
col bsid 	format 9999 		head 'Blkd|by'
col event	format a25 		head 'Wait Event'	trunc
col w		format a01		head 'x'
col sqlid	format a13		head 'Sql Id'
col sp          format a10              head ' Svr - Pgm'
col orauser     format a08              head 'Oracle|User'      trunc
col osuser      format a08              head 'OS User'          trunc
col wobj        format 9999999          head 'Object#'
col p1          format 9999999999       head 'P1'
col p2          format 999999           head 'P2'
col p3          format 99               head 'P3'
col module	format a26		head 'Module'		trunc
col sqlid   	format a17		head 'SqlId:Child'
col elaps	format 999		head 'LCl|Ela'
col command	format a04		head 'Cmnd'		trunc

prompt === Wait Chains ===
SELECT 	/*+ rule */
	 rpad(rpad('+', level ,'-'),4,' ')||lpad(wc.sid,4,' ')||','||lpad(wc.sess_serial#,5,' ') sidser
       	,wc.blocker_sid		bsid
	,se.username           	orauser
	,se.osuser              osuser
	,lpad(wc.osid,5)||'-'||lpad(substr(nvl(se.program,'null'),instr(se.program,'(')+1,4),4) sp
	,decode(wc.num_waiters,0,' ','x')	w
	,wc.wait_event_text	event
        ,least(se.p1,9999999999)      p1
        ,least(se.p2,999999)    p2
        ,least(se.p3,99)        p3
        ,wc.row_wait_obj#       wobj
	,nvl(se.module,'<'||substr(se.machine,1,instr(se.machine,'.')-1)||'>')	module
	,least(se.last_call_et,999)	elaps
       	,decode (se.command
	       , 0, ' 0  '
	       , 1, 'CRTB'
               , 2, 'ISRT'
	       , 3, 'SEL'
	       , 4, 'CRCL'
	       , 5, 'ALCL'
	       , 6, 'UPDT'
	       , 7, 'DEL'
	       , 8, 'DR'
	       , 9, 'CRIX'
	       ,10, 'DRIX'
	       ,11, 'ALIX'
	       ,12, 'DRTB'
	       ,15, 'ALTB'
	       ,17, 'GRNT'
	       ,18, 'REVK'
	       ,19, 'CSYN'
	       ,20, 'DSYN'
	       ,21, 'CRVW'
	       ,22, 'DRVW'
	       ,26, 'LKTB'
	       ,27, 'NOOP'
	       ,28, 'RENM'
	       ,29, 'CMNT'
	       ,30, 'AUDT'
	       ,31, 'NAUD'
	       ,32, 'CRLN'
	       ,33, 'DRLN'
	       ,34, 'CRDB'
	       ,35, 'ALDB'
	       ,36, 'CRRB'
	       ,37, 'ALRB'
	       ,38, 'DRRB'
	       ,39, 'CRTS'
	       ,40, 'ALTS'
	       ,41, 'DRTS'
	       ,42, 'ALSE'
	       ,43, 'ALUS'
	       ,44, 'COMT'
	       ,45, 'RLBK'
	       ,46, 'SVPT'
	       ,47, 'PLSQ'
	       ,62, 'ANTB'
	       ,63, 'ANIX'
	       ,64, 'ANCL'
	       ,85, 'TRTB'
	       ,    to_char(se.command)
	       )               	command
	,nvl(se.sql_id,se.prev_sql_id)||':'||decode(se.sql_id,null,'p',se.sql_child_number)		sqlid
FROM     v$wait_chains 	wc
	,v$session	se
where	 wc.sid			= se.sid
and	 wc.sess_serial#	= se.serial#
CONNECT BY  PRIOR wc.sid 	= wc.blocker_sid
AND 	 PRIOR wc.sess_serial# 	= wc.blocker_sess_serial#
AND 	 PRIOR wc.INSTANCE 	= wc.blocker_instance
START WITH wc.blocker_is_valid 	= 'FALSE'
;
