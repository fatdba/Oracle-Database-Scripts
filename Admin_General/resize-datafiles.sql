set verify off
set echo off
set linesi 250
set pagesi 10000
undef tablespace_name
undef limit_size
accept tablespace_name prompt "tablespace_name : "
accept limit_size      prompt "limit_size_in_mb : "
SET SERVEROUTPUT ON FORMAT WRAPPED
declare
sql_stmt varchar2(2000);
   cursor c_resize is select file_name,ceil((nvl(hwm,5)*par.value)/1024/1024)+&limit_size hwm,CEIL(BLOCKS*par.VALUE/1024/1024) CURRSIZE from dba_data_files a , v$parameter par , ( select file_id, max(block_id+blocks-1) hwm from dba_extents where tablespace_name='&tablespace_name' group by file_id ) b where a.file_id = b.file_id(+) and par.name = 'db_block_size' and tablespace_name='&tablespace_name' and (ceil((nvl(blocks,1)*8192)/1024/1024))-(ceil((nvl(hwm,1)*8192)/1024/1024))>&limit_size;
begin
   for r_resize in c_resize 
   loop
   dbms_output.new_line;
   sql_stmt:='alter database datafile '''||r_resize.file_name||''' resize '||r_resize.hwm||'m';
   dbms_output.put_line('--Resizing '||r_resize.file_name||' from '||r_resize.currsize||'M to '||r_resize.hwm||'M.');
   execute immediate sql_stmt;
   dbms_output.put_line('--Done.');
   end loop;
end;
/
undef tablespace_name
