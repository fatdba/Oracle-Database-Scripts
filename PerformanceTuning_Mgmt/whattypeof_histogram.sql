--------------------------------
-- Oracle provided script
--Modified: 6-29-16 - Added Substitution variable for table name
--Doc ID 2143577.1
---------------------------------
--Drop Table
drop table &&test_table;
--Create Table
create table &&test_table (id number, retired number);

set serveroutput on
SET LINESIZE 32000;
SET PAGESIZE 40000;
SET LONG 50000;
set echo off
set feed off

declare
 counter number;
 counter1 number;
 ndv number;
 tc number;
 n number;
 p number;
 tnv number;
 v_column_name varchar2(100);
 v_sample_size number;
 v_num_nulls number;
 v_num_distinct number;
 v_histogram varchar2(50);
 v_num_buckets number;

begin
  select &distinct_counts into ndv from dual;
  select (ndv*100)/(100-&popular_data_percentage) into tc from dual;
 for counter in 1..tc loop
   insert into &&test_table values(counter,0);
 end loop;

commit;

for counter1 in 1..ndv loop
 update &&test_table set retired=counter1 where id=counter1;
end loop;
commit;

select &num_buckets into n from dual;

-- Calculate tnv and p
select (1-(1/n))*100 into p from dual;
select ((tc-ndv)/tc)*100 into tnv from dual;

-- Create Histograms
DBMS_STATS.GATHER_TABLE_STATS(UPPER('&OWNER'),UPPER('&&test_table'), METHOD_OPT => 'FOR COLUMNS retired size '||n||', id size 1', ESTIMATE_PERCENT => DBMS_STATS.AUTO_SAMPLE_SIZE);

SELECT column_name, sample_size, num_nulls, num_distinct, histogram, num_buckets
into v_column_name, v_sample_size, v_num_nulls, v_num_distinct, v_histogram, v_num_buckets
FROM user_tab_col_statistics
WHERE table_name=UPPER('&&test_table') and column_name='RETIRED';

dbms_output.put_line('=====================================================================');
if (ndv>n) then
 if (tnv>=p) then
    dbms_output.put_line('Historgram To Be Created As Per Algoritm : TOP-FREQUENCY');
 else
    dbms_output.put_line('Historgram To Be Created As Per Algoritm : HYBRID');
 end if;
else
 if (ndv=n) then
   dbms_output.put_line('Histogram To Be Created As Per Algorithm : NOT CLEAR');
 else
    dbms_output.put_line('Historgram To Be Created As Per Algorithm : FREQUENCY');
 end if;
end if;
dbms_output.put_line('====================================================================');
dbms_output.put_line('NDV (ndv)                      : '||ndv);
dbms_output.put_line('Buckets Specified (n)          : '||n);
dbms_output.put_line('Buckets Calculated             : '||v_num_buckets);
dbms_output.put_line('Internal Threashold (p)        : '||p);
dbms_output.put_line('TOP N Frequent Values (tnv)    : '||tnv);
dbms_output.put_line('Histogram Type                 : '||v_histogram);
dbms_output.put_line('===================================================================');
end;
/
