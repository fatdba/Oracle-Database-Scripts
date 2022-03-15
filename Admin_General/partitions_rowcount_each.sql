set serverout on size 1000000
set verify off
declare
sql_stmt varchar2(1024);
row_count number;
cursor get_tab is
select table_name,partition_name
from dba_tab_partitions
where table_owner=upper('&&TABLE_OWNER') and table_name='&&TABLE_NAME';
begin
dbms_output.put_line('Checking Record Counts for table_name');
dbms_output.put_line('Log file to numrows_part_&&TABLE_OWNER.lst ....');
dbms_output.put_line('....');
for get_tab_rec in get_tab loop
BEGIN
sql_stmt := 'select count(*) from &&TABLE_OWNER..'||get_tab_rec.table_name
||' partition ( '||get_tab_rec.partition_name||' )';

EXECUTE IMMEDIATE sql_stmt INTO row_count;
dbms_output.put_line('Table '||rpad(get_tab_rec.table_name
||'('||get_tab_rec.partition_name||')',50)
||' '||TO_CHAR(row_count)||' rows.');
exception when others then
dbms_output.put_line
('Error counting rows for table '||get_tab_rec.table_name);
END;
end loop;
end;
/
set verify on
