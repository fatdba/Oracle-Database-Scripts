undef sql_id
set serveroutput on
set verify off
accept sql_id prompt 'Enter sql_id :'
accept a prompt 'YOU SURE WANNA DROP THIS SQL PROFILE?[N]: '
begin
if('&&a'='Y') then
dbms_output.put_line(CHR(10)||'Deleting this profile.....');
DBMS_SQLTUNE.drop_sql_profile ( name   => 'PROFILE_&sql_id', ignore => FALSE); 
else
dbms_output.put_line(CHR(10)||'You chose not to delete. exiting..');
end if;
end;
/
undef sql_id
undef a
