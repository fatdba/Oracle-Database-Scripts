undef sql_id
undef plan_hash
set lines 170 pages 50000 long 20000 longc 20000  termout on

--------------------------------------------------------------------------------
-- Display plan_hash_value for current cursors as well as those from awr
--------------------------------------------------------------------------------

--@@sqlid_info

accept sql_id prompt 'Enter the sql id: '
accept plan_hash prompt 'Enter the desired plan hash: '
--------------------------------------------------------------------------------
-- Use input to capture required data for execution
--------------------------------------------------------------------------------
variable v_outline_xml clob;
variable v_sql_text clob;
variable v_exists number;

set feedback off
begin
  select   sql_text into :v_sql_text from (
    select sql_text from dba_hist_sqltext where sql_id = '&&sql_id'
    union all
    select s.sql_fulltext from v$sql s left outer join dba_hist_sqltext h
    on s.sql_id = h.sql_id where h.sql_id is null and s.sql_id = '&&sql_id'
    and s.child_number = ( select min(child_number) from v$sql where sql_id = '&&sql_id')
  ) where rownum<=1;
  --
  select other_xml into :v_outline_xml from (
    select other_xml from dba_hist_sql_plan where plan_hash_value = '&&plan_hash' and other_xml is not null
    union all 
    select other_xml from v$sql_plan where plan_hash_value = '&&plan_hash' and other_xml is not null) where  rownum<=1 ;
  --
  -- Check to see if this plan has ever been used for this sql.  If not, notify the user.
  select sign(sum(plan_count)) into :v_exists from (
    select count(*) as plan_count from dba_hist_sql_plan
    where sql_id = '&&sql_id' and plan_hash_value = '&&plan_hash'
    union all
    select count(*) as plan_count from v$sql_plan
    where sql_id = '&&sql_id' and plan_hash_value = '&&plan_hash'
  );
  --
  if (:v_exists < 1)
  then
    dbms_output.put_line(chr(10)||
      'WARNING: The plan &&plan_hash has never been applied to this sql &&sql_id.'
    );
  end if;
end;
/
set feedback on

--------------------------------------------------------------------------------
-- Make sure the user wants to continue and do the import
--------------------------------------------------------------------------------
accept do_it default 'N' prompt 'Pin the above sql to this plan? [N] '

declare
  v_profile sys.sqlprof_attr;
begin
  if (
    (:v_sql_text is null)
    or
    (:v_outline_xml is null)
  )
  then
    dbms_output.put_line(chr(10)||'FATAL: Missing required data.  Unable to prcceed for sql: &&sql_id, plan: &&plan_hash'||chr(10));
    --
  elsif (
    upper('&&do_it') in ('Y', 'YES')
  )
  then
    --
    -- Extract hint data from xml
    select substr(extractvalue(value(d), '/hint'),1,4000)
      bulk collect into v_profile from table( xmlsequence(extract(xmltype(:v_outline_xml), '/*/outline_data/hint'))) d;
    --
    -- Add the header and footer records
    v_profile.extend;
    for i in reverse 2..v_profile.count
    loop
      v_profile(i) := v_profile(i-1);
    end loop;
    v_profile(1)                := 'BEGIN_OUTLINE_DATA';
    v_profile.extend;
    v_profile(v_profile.count)  := 'END_OUTLINE_DATA';
    --
    -- Import the profile
    dbms_output.put_line(chr(10)||'Creating SQL Profile for sql: &&sql_id, plan: &&plan_hash'||chr(10));
    DBMS_SQLTUNE.IMPORT_SQL_PROFILE(
      sql_text => :v_sql_text,
      profile => v_profile,
      name => 'PROFILE_&&sql_id'
    );
    --
  else
    dbms_output.put_line(chr(10)||'Cancelling at user request.'||chr(10));
  end if;
end;
/
