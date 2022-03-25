REM ------------------------------------------------------------------------------------------------
REM $Id: mysid.sql,v 1.1 2002/04/01 22:52:49 hien Exp $
REM #DESC      : Show all session related information for my sid 
REM Usage      : Input parameter: none
REM Description: 
REM ------------------------------------------------------------------------------------------------

@plusenv

set lines 120 pages 0
col colx newline just left  format a120
col coly newline just left  word_wrapped format a120

SELECT	/*+ ORDERED */
         ' '                                    			colx
        ,'Session id ...........:'||s.sid       			colx
        ,'Serial # .............:'||s.serial#   			colx
        ,'Oracle PID ...........:'||p.pid   				colx
        ,'SADDR ................:'||s.saddr 				colx
        ,'Oracle logon id ......:'||s.username  			colx
        ,'Logon time ...........:'||to_char(logon_time,'YYYY-MM-DD/HH24:MI:SS')	colx
        ,'Current time .........:'||to_char(sysdate,'YYYY-MM-DD/HH24:MI:SS')	colx
        ,'Session status .......:'||s.status    			colx
        ,'Server type ..........:'||s.server    			colx
        ,'Process type .........:'||substr(p.program,instr(p.program,'('),12) 	colx
        ,' '                                    			colx
        ,'Logical reads ........:'||(i.block_gets+i.consistent_gets)    colx
        ,'Physical reads .......:'||i.physical_reads                    colx
        ,'Block Changes ........:'||i.block_changes                    	colx
        ,'Consistent Changes ...:'||i.consistent_changes                colx
        ,'Last call elapsed min :'||round(s.last_call_et/60)            colx
        ,' '                                    			colx
        ,'OS logon id ..........:'||s.osuser    			colx
        ,'OS server PID ........:'||p.spid      			colx
        ,'OS parent PID ........:'||s.process   			colx
        ,'OS machine ...........:'||s.machine   			colx
        ,' '                                    			colx
        ,'Module ...............:'||s.module    			colx
        ,'Program ..............:'||s.program   			colx
        ,'SQL Id  ..............:'||s.sql_id              		colx
        ,'SQL child number......:'||s.sql_child_number  		colx
        ,'Prev SQL hash value ..:'||s.prev_hash_value    		colx
	,'First load time ......:'||sq.first_load_time			colx
        ,' '                                    			colx
        ,'Executions ...........:'||sq.executions       		colx
	,'Parse calls ..........:'||sq.parse_calls			colx
        ,'Sorts ................:'||sq.sorts    			colx
        ,'Version count ........:'||sq.version_count   			colx
        ,'Buffer gets per SQL ..:'||round(sq.buffer_gets/decode(sq.executions,0,1,sq.executions)) colx
        ,'Disk reads per SQL ...:'||round(sq.disk_reads/decode(sq.executions,0,1,sq.executions))  colx
        ,' '                                    			colx
        ,'Waiting for lock .....:'||decode(s.lockwait,null,'NO','YES')  colx
        ,'Wait Obj-File-Blk-Row :'||row_wait_obj#||'-'||row_wait_file#||'-'||row_wait_file#||'-'||row_wait_row# colx
        ,' '                                    			colx
        ,'SQL text .............:'              			colx
        ,sq.sql_text                                    		coly
FROM
         v$session     	s
        ,v$process     	p
        ,v$sess_io     	i
        ,v$sqlarea     	sq
WHERE
         s.audsid	= userenv('SESSIONID')
AND      s.paddr	= p.addr (+)
AND      s.sid          = i.sid (+)
AND      s.sql_address  = sq.address (+)
AND      decode(sign(s.sql_hash_value),-1,s.sql_hash_value+power(2,32),sql_hash_value) = sq.hash_value (+)
;
