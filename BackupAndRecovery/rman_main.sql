-- delete archivelog older than 1 day
DELETE ARCHIVELOG ALL COMPLETED BEFORE 'sysdate-1';
CROSSCHECK ARCHIVELOG ALL;
DELETE EXPIRED ARCHIVELOG ALL;






- backup archivelogs
Backup all archivelogs known to controlfile

backup archivelog all;

Backup all archivelogs known to controlfile and delete them once backed up

backup archivelog all delete input ;

Backup archivlogs known to controlfile and the logs which haven't backed up once also

backup archivelog all not backed up 1 times;






--- Copy archive log from ASM to regular mount point using RMAN:
--- Connect to RMAN in RAC db

RMAN> copy archivelog '+B2BSTARC/thread_2_seq_34.933' to '/data/thread_2_seq_34.933';







-- For taking backup of archivelog between seq number 1000 to 1050

RMAN> backup format '/archive/%d_%s_%p_%c_%t.arc.bkp'
archivelog from sequence 1000 until sequence 1050;

-- For RAC ,need to mention the thread number also

RMAN> backup format '/archive/%d_%s_%p_%c_%t.arc.bkp'
archivelog from sequence 1000 until sequence 1050 thread 2;







-- To diagnose rman script, use trace as below.

spool trace to '/tmp/rman_trace.out';
report schema;
list backup summary;
list backup of datafile 1;
list copy of datafile 1;
spool trace off;






-- Recover dropped table with RMAN 12c
RMAN>recover table SCOTT.SALGRADE until time “to_date(’08/09/2016 18:49:40′,’mm/dd/yyyy hh24:mi:ss’)”
auxiliary destination ‘/u03/arch/TEST/BACKUP’
datapump destination ‘/u03/arch/TEST/BACKUP';

 

auxiliary destination – Location where all the related files for auxiliary instance will be placed
datapump destination – Location where the export dump of the table will be placed
NOTE - This feature is available only in oracle 12c and later.










-- Enable block change tracking

alter database enable block change tracking using file
'/export/home/oracle/RMAN/TESTDB/TRACKING_FILE/block_change_TESTDB.log';

-- Check status:

select filename,status from v$block_change_tracking;







-- restore archivelogs from RMAN Tape mediums 
-----Below  script will restore the archive sequences from 7630 to 7640 to /dumparea location

connect target sys/******@CRM_DB
connect catalog RMAN_tst/*****@catdb

run
{
allocate channel t1 type SBT_TAPE parms ‘ENV=(NSR_SERVER=nwwerpw,NSR_CLIENT=tsc_test01,NSR_DATA_VOLUME_POOL=DD086A1)’connect sys/****@CRM_DB;
set archivelog destination to ‘/dumparea/';
restore archivelog from sequence 7630 until sequence 7640;
release channel t1;
}






--- check the syntax of RMAN commands interactively without actually executing the commands

$ rman checksyntax

Recovery Manager: Release 12.1.0.2.0 - Production on Sun Jan 29 12:04:24 2017

Copyright (c) 1982, 2014, Oracle and/or its affiliates. All rights reserved.

-- Now put the command for checking syntax

RMAN> backup database;

The command has no syntax errors
