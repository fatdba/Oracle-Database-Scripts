-- Create Table with same structure as ALL_TABLES from Oracle Dictionary
-- This one I took from Tom Kyte AskTOM
--
-- easy method to test asa
--
--
--

create table bigtab
as
select rownum id, a.*
  from all_objects a
 where 1=0;
alter table bigtab nologging;

-- Fill 1'000'000 Rows into the Table
declare
    l_cnt  number;
    l_rows number := 1000000;
begin
    -- Copy ALL_OBJECTS
    insert /*+ append */
    into bigtab
    select rownum, a.*
      from all_objects a;
    l_cnt := sql%rowcount;
    commit;

    -- Generate Rows
    while (l_cnt < l_rows)
    loop
        insert /*+ APPEND */ into bigtab
        select rownum+l_cnt,
               OWNER, OBJECT_NAME, SUBOBJECT_NAME,
               OBJECT_ID, DATA_OBJECT_ID,
               OBJECT_TYPE, CREATED, LAST_DDL_TIME,
               TIMESTAMP, STATUS, TEMPORARY,
               GENERATED, SECONDARY
          from bigtab
         where rownum <= l_rows-l_cnt;
        l_cnt := l_cnt + sql%rowcount;
        commit;
    end loop;
end;
/

alter table bigtab add constraint
bigtab_pk primary key(id);

A Table with Random Data and same Size as ALL_OBJECTS
CREATE TABLE bigtab (
   id         NUMBER,
   weight     NUMBER,
   adate      DATE
);

INSERT INTO bigtab (id, weight, adate)
SELECT MOD(ROWNUM,1000),
       DBMS_RANDOM.RANDOM,
       SYSDATE-1000+DBMS_RANDOM.VALUE(0,1000)
 FROM all_objects
/
51502 rows created.

A Table which can be used for Partition Tests
The ID of the table can be used for Range Partitioning

create table bigtab (
    id      number(12,6),
    v1      varchar2(10),
    padding varchar2(50)
)
nologging   -- just to save a bit of time
/

insert /*+ append ordered full(s1) use_nl(s2) */
into bigtab
select
        3000 + trunc((rownum-1)/500,6),
        to_char(rownum),
        rpad('x',50,'x')
from
        all_objects s1,      -- you’ll need the privilege
        all_objects s2
where
        rownum <= 1000000
/
commit;

        ID V1         PADDING
---------- ---------- --------------------------------------------------
      3000 1          xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  3000.002 2          xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  3000.004 3          xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  3000.006 4          xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  3000.008 5          xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   3000.01 6          xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  3000.012 7          xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  3000.014 8          xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  3000.016 9          xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

A Table with Date's which can be used for Partition Tests
This code is from http://www.oracle-base.com

CREATE TABLE bigtab (
  id            NUMBER(10),
  created_date  DATE,
  lookup_id     NUMBER(10),
  data          VARCHAR2(50)
);

DECLARE
  l_lookup_id    NUMBER(10);
  l_create_date  DATE;
BEGIN
  FOR i IN 1 .. 1000000 LOOP
    IF MOD(i, 3) = 0 THEN
      l_create_date := ADD_MONTHS(SYSDATE, -24);
      l_lookup_id   := 2;
    ELSIF MOD(i, 2) = 0 THEN
      l_create_date := ADD_MONTHS(SYSDATE, -12);
      l_lookup_id   := 1;
    ELSE
      l_create_date := SYSDATE;
      l_lookup_id   := 3;
    END IF;

    INSERT INTO bigtab (id, created_date, lookup_id, data)
    VALUES (i, l_create_date, l_lookup_id, 'This is some data for ' || i);
  END LOOP;
  COMMIT;
END;
/

SQL> select id,to_char(created_date,'DD.MM.YYYY'),
            lookup_id, data
       from bigtab where rownum < 10;

        ID TO_CHAR(CR  LOOKUP_ID DATA
---------- ---------- ---------- -----------------------------
         1 21.08.2007          3 This is some data for 1
         2 21.08.2006          1 This is some data for 2
         3 21.08.2005          2 This is some data for 3
         4 21.08.2006          1 This is some data for 4
         5 21.08.2007          3 This is some data for 5
         6 21.08.2005          2 This is some data for 6
         7 21.08.2007          3 This is some data for 7
         8 21.08.2006          1 This is some data for 8
         9 21.08.2005          2 This is some data for 9
