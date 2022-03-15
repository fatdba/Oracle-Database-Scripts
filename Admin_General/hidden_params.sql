set lin 200
column "Parameter" format a45
column "Session Value" format a25
column "Instance Value" format a25
col "descr" for a60
select a.ksppinm  "Parameter", b.ksppstvl "Session Value", c.ksppstvl "Instance Value",a.ksppdesc    "descr"
  from x$ksppi a, x$ksppcv b, x$ksppsv c
 where a.indx = b.indx and a.indx = c.indx
   and substr(ksppinm,1,1)='_'
   and a.ksppinm like '%&param%'
order by a.ksppinm;


-- Hidden params settings
Set lines 2000
col NAME for a45
col DESCRIPTION for a100
SELECT name,description from SYS.V$PARAMETER WHERE name LIKE '\_%' ESCAPE '\'
/
