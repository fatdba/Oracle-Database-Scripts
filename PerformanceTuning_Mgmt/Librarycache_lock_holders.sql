set pagesize 40
select x$kglpn.inst_id,sid Holder ,KGLPNUSE Sesion , KGLPNMOD Held, KGLPNREQ Req
from x$kglpn , gv$session
where KGLPNHDL in (select p1raw from gv$session_wait
where wait_time=0 and event like ‘library cache%’)
and KGLPNMOD <> 0
and gv$session.saddr=x$kglpn.kglpnuse ;
PROMPT Detect Library Cache holders that sessions are waiting for

-- Detect sessions waiting for a Library Cache Locks

select sid Waiter, p1raw,
substr(rawtohex(p1),1,30) Handle,
substr(rawtohex(p2),1,30) Pin_addr
from gv$session_wait where wait_time=0 and event like ‘library cache%’;
