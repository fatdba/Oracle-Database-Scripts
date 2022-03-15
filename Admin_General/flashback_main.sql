-- Flashback a table to point in time
ALTER TABLE DBACLASS.EMP ENABLE ROW MOVEMENT;
FLASHBACK TABLE DBACLASS.EMP TO TIMESTAMP
TO_TIMESTAMP('2017-01-10 09:00:00', `YYYY-MM-DD HH24:MI:SS');


-- recover a dropped table
Restore the dropped table with same name:

SQL>flashback table DBACLASS.EMP to before drop;

Restore the dropped table with a new name

SQL>Flashback table DBACLASS.EMP to before drop rename to EMP_BACKUP;

Note - To recover the table, table should be present in recyclebin:

select * from dba_recyclebin;



-- flashback query as of timestamp
SELECT * FROM DBACLASS.EMP AS OF TIMESTAMP
TO_TIMESTAMP('2017-01-07 10:00:00', 'YYYY-MM-DD HH:MI:SS');

SELECT * FROM DBACLASS.EMP AS OF TIMESTAMP SYSDATE -1/24;



-- enable flashback
Make sure database is in archivelog mode

alter system set db_recovery_file_dest_size=10G scope=both;
alter system set db_recovery_file_dest='/dumparea/FRA/B2BRBMT3' scope=both;
alter database flashback on;



-- create and drop GRP 
-- To create a guarantee flashback restore point;

SQL>create restore point BEFORE_UPG guarantee flashback database;

-- Check the restore_points present in database

SQL>select * from v$restore_point;

-- Drop restore point;

SQL> drop restore point BEFORE_UPG;







--- Below are the steps for flashback database to a guaranteed restore point;

1. Get the restore point name:

SQL> select NAME,time from v$restore_point;

NAME                                                            TIME
--------------------------------          -----------------------------------------------
GRP_1490100093811                         21-MAR-17 03.41.33.000000000 PM

2. Shutdown database and start db in Mount stage:

shutdown immediate;
startup mount;

3. flashback db to restore point:

flashback database to restore point GRP_1490100093811;

4. Open with resetlog:

alter database open resetlogs:








-- flashback a procedure or package

--- Like, tables ,If you have dropped or recreated a package/procedure, by using flashback ,we can get the proc code, before drop. 

get the object_id

SQL> select object_id from dba_objects where owner='DBACLASS' and object_name='VOL_DISCOUNT_INSERT';

OBJECT_ID
----------
2201943

Now get the flashback code using timestamp

select SOURCE from sys.source$ as of timestamp
to_timestamp('23-Apr-2017 10:00:20','DD-Mon-YYYY hh24:MI:SS')
where obj#=2201943 ;








--How Far Back Can We Flashback To (Time)

select to_char(oldest_flashback_time,’dd-mon-yyyy hh24:mi:ss’) “Oldest Flashback Time”
from v$flashback_database_log;

--How Far Back Can We Flashback To (SCN)

col oldest_flashback_scn format 99999999999999999999999999
select oldest_flashback_scn from v$flashback_database_log;





-- flashback a table to point in time

ALTER TABLE DBACLASS.EMP ENABLE ROW MOVEMENT;
FLASHBACK TABLE DBACLASS.EMP TO TIMESTAMP
TO_TIMESTAMP('2017-01-10 09:00:00', `YYYY-MM-DD HH24:MI:SS');
