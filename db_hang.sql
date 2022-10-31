--
-- Author: Prashant 'The FatDBA' Dixit
--


-- Create system state dump, hanganalyze and ashdumps 
sqlplus / as sysdba
oradebug setmypid
oradebug unlimit
oradebug hanganalyze 3
oradebug dump ashdumpseconds 30
oradebug dump systemstate 266
oradebug tracefile_name


-- he ASH information can be dumped to trace file even if it cannot be collected in the database.
-- that will gather ASH from latest 30 seconds, and the trace file will even have the sqlldr ctl file to load it in an ASH like table.
oradebug dump ashdumpseconds 30

-- a  ‘preliminary connection’ that does not create a session
sqlplus -prelim / as sysdba

-- the hanganalyze information is also available online in V$WAIT_CHAINS
V$WAIT_CHAINS
