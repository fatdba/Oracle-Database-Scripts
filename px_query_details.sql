col username for a9
col sid for a8
set lines 299
select
s.inst_id,
decode(px.qcinst_id,NULL,s.username,
' - '||lower(substr(s.program,length(s.program)-4,4) ) ) "Username",
decode(px.qcinst_id,NULL, 'QC', '(Slave)') "QC/Slave" ,
to_char( px.server_set) "Slave Set",
to_char(s.sid) "SID",
decode(px.qcinst_id, NULL ,to_char(s.sid) ,px.qcsid) "QC SID",
px.req_degree "Requested DOP",
px.degree "Actual DOP", p.spid
from
gv$px_session px,
gv$session s, gv$process p
where
px.sid=s.sid (+) and
px.serial#=s.serial# and
px.inst_id = s.inst_id
and p.inst_id = s.inst_id
and p.addr=s.paddr
order by 5 , 1 desc
/
