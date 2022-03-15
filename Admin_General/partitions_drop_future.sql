SET SERVEROUTPUT ON SIZE 1000000
SET ECHO ON

DECLARE

rows_found  number  :=1;
v_sql_to_run    varchar(4000);

cursor fd_part_cursor IS
select    partition_name,table_owner,table_name
from      all_tab_partitions
where   table_owner in ('BOOKER') and
                table_name='FULFILLMENT_DEMANDS' and
                partition_name >= 'FULFILLMENT_DEMANDS_20130518' order by partition_name;


BEGIN

FOR part_rec in fd_part_cursor LOOP
   rows_found:=1;  -- This is not needed. I am just paranoid :)
   v_sql_to_run := 'select    count(*)   '||
                     'from      booker.'||part_rec.table_name||' partition ('||part_rec.partition_name||') fd ';
   execute immediate v_sql_to_run into rows_found;
   dbms_output.put_line('--partition = '||part_rec.table_owner||'.'||part_rec.partition_name||', rows_found = '||rows_found);
   if(rows_found=0) then
   dbms_output.put_line('alter table booker.'||part_rec.table_name||' drop partition '||part_rec.partition_name||' update global indexes;');
   end if;
END LOOP; 
END;  
/

SET ECHO OFF
