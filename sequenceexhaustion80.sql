SELECT 
       ROUND(100 * (s.last_number - s.min_value) / GREATEST((s.max_value - s.min_value), 1), 1) percent_used, /* requested by Mike Moehlman */
       s.*
from dba_sequences s
where
   s.sequence_owner not in ('ANONYMOUS','APEX_030200','APEX_040000','APEX_SSO','APPQOSSYS','CTXSYS','DBSNMP','DIP','EXFSYS','FLOWS_FILES','MDSYS','OLAPSYS','ORACLE_OCM','ORDDATA','ORDPLUGINS','ORDSYS','OUTLN','OWBSYS')
and s.sequence_owner not in ('SI_INFORMTN_SCHEMA','SQLTXADMIN','SQLTXPLAIN','SYS','SYSMAN','SYSTEM','TRCANLZR','WMSYS','XDB','XS$NULL','PERFSTAT','STDBYPERF','MGDSYS','OJVMSYS')
and s.max_value > 0
and ROUND(100 * (s.last_number - s.min_value) / GREATEST((s.max_value - s.min_value), 1), 1) > 80
order by
ROUND(100 * (s.last_number - s.min_value) / GREATEST((s.max_value - s.min_value), 1), 1) DESC, /* requested by Mike Moehlman */
s.sequence_owner, s.sequence_name;
