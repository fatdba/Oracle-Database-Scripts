set linesi 190
set verify off
set feedback off
set pagesi 0
accept new prompt "Enter New Username : ";
accept old prompt "Enter Old Username : ";
prompt --;
prompt --System privileges:;
select 'grant '||privilege||' to &new ;' from dba_sys_privs where grantee=upper('&old');
prompt --;
prompt --Object privileges:;
select 'grant '||privilege||' on '||owner||'.'||table_name||' to &new ;'  from dba_tab_privs where grantee=upper('&old') order by table_name;
prompt --;
prompt --Roles granted:;
select 'grant '||granted_role||' to &new ;' from dba_role_privs where grantee=upper('&old');
prompt --;
undef new
undef old
set feedback on
