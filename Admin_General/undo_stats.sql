set head on feed off
col BeginTime 	format a20
col EndTime   	format a20
col TXCount   	format 9999999999999
col MaxQueryInSecs   format 999999
col MaxQueryInHrs   format 999.99
col MaxConc   	format 999
col sto		format 999
col nse		format 999
select TO_CHAR(MIN(Begin_Time),'DD-MON-YYYY HH24:MI:SS')
                 "BeginTime",
    TO_CHAR(MAX(End_Time),'DD-MON-YYYY HH24:MI:SS')
                 "EndTime",
    SUM(Undoblks)    "TotUndoBlocks",
    SUM(Txncount)    "TXCount",
    MAX(Maxquerylen)  "MaxQueryInSecs",
    MAX(Maxquerylen)/(60*60)  "MaxQueryInHrs",
    MAX(Maxconcurrency) "MaxConc",
    SUM(Ssolderrcnt) "ORA-1555",
    SUM(Nospaceerrcnt) "SpaceError"
from V$UNDOSTAT;
@undo-size.sql
