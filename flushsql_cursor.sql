First get the address, hash_value of the sql_id

select ADDRESS, HASH_VALUE from V$SQLAREA where SQL_ID like '5qd8a442c328k';

ADDRESS          HASH_VALUE
---------------  ------------
C000007067F39FF0  4000666812

Now flush the query

SQL> exec DBMS_SHARED_POOL.PURGE ('C000007067F39FF0, 4000666812', 'C');

Note : For RAC, same need to be executed on all the nodes .
