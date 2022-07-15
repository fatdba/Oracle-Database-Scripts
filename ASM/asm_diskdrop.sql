-----Dropping one disk from the DG

alter diskgroup data drop disk DATA_ASM0001;

-----Dropping multiple disk:
--
alter diskgroup data drop disk DATA_ASM0001,DATA_ASM00002, DATA_ASM0003 rebalance power 100;

---- Monitoring the rebalance operation:

select * from v$asm_operation;
or 
set pagesize 299
set lines 2999
select GROUP_NUMBER,OPERATION,STATE,POWER,
ACTUAL,ACTUAL,EST_MINUTES from gv$asm_operation;
