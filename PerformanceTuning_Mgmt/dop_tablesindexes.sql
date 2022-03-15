Check Script
-------------
col name format a30
col value format a20
Rem How many CPU does the system have?
Rem Default degree of parallelism is
Rem Default = parallel_threads_per_cpu * cpu_count
Rem -------------------------------------------------;
select substr(name,1,30) Name , substr(value,1,5) Value
from v$parameter
where name in ('parallel_threads_per_cpu' , 'cpu_count' );

col owner format a30
col degree format a10
col instances format a10
Rem Normally DOP := degree * Instances
Rem See the following Note for the exact formula.
Rem Note:260845.1 Old and new Syntax for setting Degree of Parallelism
Rem How many tables a user have with different DOPs
Rem -------------------------------------------------------;
select * from (
select substr(owner,1,15) Owner , ltrim(degree) Degree,
ltrim(instances) Instances,
count(*) "Num Tables" , 'Parallel'
from all_tables
where ( trim(degree) != '1' and trim(degree) != '0' ) or
( trim(instances) != '1' and trim(instances) != '0' )
group by owner, degree , instances
union
select substr(owner,1,15) owner , '1' , '1' ,
count(*) , 'Serial'
from all_tables
where ( trim(degree) = '1' or trim(degree) = '0' ) and
( trim(instances) = '1' or trim(instances) = '0' )
group by owner
)
order by owner;


Rem How many indexes a user have with different DOPs
Rem ---------------------------------------------------;
select * from (
select substr(owner,1,15) Owner ,
substr(trim(degree),1,7) Degree ,
substr(trim(instances),1,9) Instances ,
count(*) "Num Indexes",
'Parallel'
from all_indexes
where ( trim(degree) != '1' and trim(degree) != '0' ) or
( trim(instances) != '1' and trim(instances) != '0' )
group by owner, degree , instances
union
select substr(owner,1,15) owner , '1' , '1' ,
count(*) , 'Serial'
from all_indexes
where ( trim(degree) = '1' or trim(degree) = '0' ) and
( trim(instances) = '1' or trim(instances) = '0' )
group by owner
)
order by owner;


col table_name format a35
col index_name format a35
Rem Tables that have Indexes with not the same DOP
Rem !!!!! This command can take some time to execute !!!
Rem ---------------------------------------------------;
set lines 150
select substr(t.owner,1,15) Owner ,
t.table_name ,
substr(trim(t.degree),1,7) Degree ,
substr(trim(t.instances),1,9) Instances,
i.index_name ,
substr(trim(i.degree),1,7) Degree ,
substr(trim(i.instances),1,9) Instances
from all_indexes i,
all_tables t
where ( trim(i.degree) != trim(t.degree) or
trim(i.instances) != trim(t.instances) ) and
i.owner = t.owner and
i.table_name = t.table_name;
