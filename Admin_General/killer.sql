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

