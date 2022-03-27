set lin 180
column "Parameter" format a45
column "Instance Value" format a50
col "descr" for a60  trunc
select a.ksppinm  "Parameter", c.ksppstvl "Instance Value",a.ksppdesc    "descr"
  from x$ksppi a, x$ksppsv c
 where  a.indx = c.indx
   and a.ksppinm like '%&param%'
order by a.ksppinm;
