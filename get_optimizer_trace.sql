--
-- given a sql_id and child number, generate an optimizer trace
--
set echo off feed off head off

undef sql_id
undef child_number

BEGIN
	DBMS_SQLDIAG.DUMP_TRACE(p_sql_id 	=> '&&sql_id',
				p_child_number	=> &&child_number,
				p_component	=> 'Compiler',
				p_file_id	=> 'Optimizer_Trace'
				);
END;
/

prompt  -- Look for the following trace file on DB Server --;

select	 '*** '||i.host_name||':'||p.value||'/'||i.instance_name||'_ora_'||pr.spid||'_Optimizer_Trace'||'.trc ***'
from	 v$instance 	i
	,v$parameter	p
	,v$process	pr
where	 p.name		='user_dump_dest'
and	 pr.addr	in (select paddr from v$session where sid = userenv('SID'))
;
