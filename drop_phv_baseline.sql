undef plan_hash ;
declare 
  v_sql_handle varchar2(30);
  gg binary_integer;
cursor sql_cur is select SQL_HANDLE from dba_sql_plan_baselines b ,v$sql s where b.signature=s.EXACT_MATCHING_SIGNATURE(+) and s.SQL_PLAN_BASELINE(+)=b.plan_name and to_number(decode(b.ACCEPTED,'NO',null,s.plan_hash_value))=&plan_hash;
begin 
  open sql_cur; 
  loop 
    fetch sql_cur into v_sql_handle ; 
      exit when sql_cur%NOTFOUND; 
      gg:=dbms_spm.drop_sql_plan_baseline( sql_handle => v_sql_handle);
  end loop; 
  close sql_cur; 
  commit; 
end; 
/
undef plan_hash
