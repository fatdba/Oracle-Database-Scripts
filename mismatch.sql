declare
  c         number;
  col_cnt   number;
  col_rec   dbms_sql.desc_tab;
  col_value varchar2(4000);
  ret_val    number;
begin
  c := dbms_sql.open_cursor;
  dbms_sql.parse(c,
      'select q.sql_text, s.*
      from v$sql_shared_cursor s, v$sql q
      where s.sql_id = q.sql_id
          and s.child_number = q.child_number
          and q.sql_id like ''&sql_id''',
      dbms_sql.native);
  dbms_sql.describe_columns(c, col_cnt, col_rec);

  for idx in 1 .. col_cnt loop
    dbms_sql.define_column(c, idx, col_value, 4000);
  end loop;

  ret_val := dbms_sql.execute(c);

  while(dbms_sql.fetch_rows(c) > 0) loop
    for idx in 1 .. col_cnt loop
      dbms_sql.column_value(c, idx, col_value);
      if col_rec(idx).col_name in ('SQL_ID', 'CHILD_NUMBER') then
        dbms_output.put_line(rpad(col_rec(idx).col_name, 30) ||
                ' = ' || col_value);
      elsif col_value = 'Y' then
        dbms_output.put_line(rpad(col_rec(idx).col_name, 30) ||
                ' = ' || col_value);
      end if;

    end loop;

    dbms_output.put_line('--------------------------------------------------');

   end loop;

  dbms_sql.close_cursor(c);

end;
/
