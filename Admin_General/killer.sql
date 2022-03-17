declare
tsql varchar2(300);
cursor c is select sid,serial# from v$session where event like 'latch: cache buffers chains%' and lower(module)='gpiservice';
begin
for c_rec in c loop
tsql:='alter system kill session '''||c_rec.sid||','||c_rec.serial#||''' immediate';
execute immediate tsql;
end loop;
end;
/


-- kill user
set line 200 pages 2000
select 'alter system kill session '''||sid||','||serial#||''' immediate;' from v$session where username='&USER';

-- kill SQL ID
select 'alter system kill session '||''''||sid||','||serial#||''''||' immediate ;' from v$session where sql_id = '&sql_id' ;


-- Kill SID
undef sid
select 'alter system kill session ''' || sid || ',' || serial# || ''' immediate;' from v$session where
sid = &sid
/


-- Kill Module
select 'alter system kill session '||''''||sid||','||serial#||''''||' immediate ;' from v$session where module ='&module';


