set serveroutput on
declare
 procedure print_all(s varchar2) is begin null;
  dbms_output.put_line(s);
 end;
 procedure print_ddl(s varchar2) is begin null;
  dbms_output.put_line(s);
 end;
begin
 dbms_metadata.set_transform_param(dbms_metadata.session_transform,'SEGMENT_ATTRIBUTES',false);
 for a in (
        select count(*) samples,
        event,p1,p2,o.owner c_owner,o.object_name c_object_name,p.object_owner p_owner,p.object_name p_object_name,id,operation,min(p1-1414332420+4) lock_mode,min(sample_time) min_time,max(sample_time) max_time,ceil(10*count(distinct sample_id)/60) minutes
        from dba_hist_active_sess_history left outer join dba_hist_sql_plan p using(dbid,sql_id) left outer join dba_objects o on object_id=p2 left outer join dba_objects po on po.object_id=current_obj#
        where event like 'enq: TM%' and p1>=1414332420 and sample_time>sysdate-15 and p.id=1 and operation in('DELETE','UPDATE','MERGE')
        group by
        event,p1,p2,o.owner,o.object_name,p.object_owner,p.object_name,po.owner,po.object_name,id,operation
        order by count(*) desc
 ) loop
  print_ddl('--  '||a.operation||' on '||a.p_owner||'.'||a.p_object_name||' has locked '||a.c_owner||'.'||a.c_object_name||' in mode '||a.lock_mode||' for '||a.minutes||' minutes between '||to_char(a.min_time,'dd-mon hh24:mi')||' and '||to_char(a.max_time,'dd-mon hh24:mi'));
  for s in (
   select distinct regexp_replace(cast(substr(sql_text,1,2000) as varchar2(60)),'[^a-zA-Z ]',' ') sql_text
   from dba_hist_active_sess_history join dba_hist_sqltext t using(dbid,sql_id)
   where event like 'enq: TM%' and p2=a.p2 and sample_time>sysdate-90
  ) loop
   print_all('--      '||'blocked statement: '||s.sql_text);
  end loop;
  for c in (
    with
      c as (
      select p.owner p_owner,p.table_name p_table_name,c.owner c_owner,c.table_name c_table_name,c.delete_rule,c.constraint_name
      from dba_constraints p
      join dba_constraints c on (c.r_owner=p.owner and c.r_constraint_name=p.constraint_name)
      where p.constraint_type in ('P','U') and c.constraint_type='R'
    )
    select c_owner owner,constraint_name,c_table_name,connect_by_root(p_owner||'.'||p_table_name)||sys_connect_by_path(decode(delete_rule,'CASCADE','(cascade delete)','SET NULL','(cascade set null)',' ')||' '||c_owner||'"."'||c_table_name,' referenced by') foreign_keys
    from c
    where level<=10 and c_owner=a.c_owner and c_table_name=a.c_object_name
    connect by nocycle p_owner=prior c_owner and p_table_name=prior c_table_name and ( level=1 or prior delete_rule in ('CASCADE','SET NULL') )
    start with p_owner=a.p_owner and p_table_name=a.p_object_name
  ) loop
   print_all('--      '||'FK chain: '||c.foreign_keys||' ('||c.owner||'.'||c.constraint_name||')'||' unindexed');
   for l in (select * from dba_cons_columns where owner=c.owner and constraint_name=c.constraint_name) loop
    print_all('--         FK column '||l.column_name);
   end loop;
   print_ddl('--      Suggested index: '||regexp_replace(translate(dbms_metadata.get_ddl('REF_CONSTRAINT',c.constraint_name,c.owner),chr(10)||chr(13),'  '),'ALTER TABLE ("[^"]+"[.]"[^"]+") ADD CONSTRAINT ("[^"]+") FOREIGN KEY ([(].*[)]).* REFERENCES ".*','CREATE INDEX ON \1 \3;'));
   for x in (
     select rtrim(translate(dbms_metadata.get_ddl('INDEX',index_name,index_owner),chr(10)||chr(13),'  ')) ddl
     from dba_ind_columns where (index_owner,index_name) in (select owner,index_name from dba_indexes where owner=c.owner and table_name=c.c_table_name)
     and column_name in (select column_name from dba_cons_columns where owner=c.owner and constraint_name=c.constraint_name)
     )
   loop
    print_ddl('--      Existing candidate indexes '||x.ddl);
   end loop;
   for x in (
     select rtrim(translate(dbms_metadata.get_ddl('INDEX',index_name,index_owner),chr(10)||chr(13),'  ')) ddl
     from dba_ind_columns where (index_owner,index_name) in (select owner,index_name from dba_indexes where owner=c.owner and table_name=c.c_table_name)
     )
   loop
    print_all('--       Other existing Indexes: '||x.ddl);
   end loop;
  end loop;
 end loop;
end;
/
