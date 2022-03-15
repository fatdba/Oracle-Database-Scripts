set pages 200
undef tab_owner
undef tab_name
  WITH        in_plan_objects AS
  (
    SELECT      sql_id, object_name
    FROM        v$sql_plan
    WHERE       object_owner not in ('SYS','SYSTEM')
    group by sql_id, object_name
    )
       ,all_sql AS
    (
   SELECT      sql_id
      ,sum(executions) execs
      ,round(sum(buffer_gets)/sum(executions)) bgetspx
   FROM        v$sql
   WHERE       executions     >0
   group by sql_id
   )
   select      decode(object_name,null,'NO','YES')    in_use
      ,i.table_owner||'.'||i.table_name       tab_name
      ,p.sql_id                               sqlid
      ,s.execs                                execs
      ,least(s.bgetspx,999999)                bgetspx
      ,decode(substr(index_name,1,3),'PK_','  '||i.owner||'.'||i.index_name,owner||'.'||index_name) iname
   FROM        dba_indexes            i
      ,in_plan_objects        p
      ,all_sql                s
   WHERE       i.index_name   = p.object_name (+)
   and         p.sql_id       = s.sql_id (+)
   and         table_name     = upper('&&tab_name')
   and         table_owner    = nvl(upper('&&tab_owner'),'BOOKER')
   order by in_use
      ,i.table_owner||'.'||i.table_name
      ,i.index_name
      ,s.execs
;
