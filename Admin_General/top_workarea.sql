-- ADDRESS                                                                                                                          RAW(8)
-- HASH_VALUE                                                                                                                       NUMBER
-- SQL_ID                                                                                                                           VARCHAR2(13)
-- CHILD_NUMBER                                                                                                                     NUMBER
-- WORKAREA_ADDRESS                                                                                                                 RAW(8)
-- OPERATION_TYPE                                                                                                                   VARCHAR2(60)
-- OPERATION_ID                                                                                                                     NUMBER
-- POLICY                                                                                                                           VARCHAR2(30)
-- ESTIMATED_OPTIMAL_SIZE                                                                                                           NUMBER
-- ESTIMATED_ONEPASS_SIZE                                                                                                           NUMBER
-- LAST_MEMORY_USED                                                                                                                 NUMBER
-- LAST_EXECUTION                                                                                                                   VARCHAR2(30)
-- LAST_DEGREE                                                                                                                      NUMBER
-- TOTAL_EXECUTIONS                                                                                                                 NUMBER
-- OPTIMAL_EXECUTIONS                                                                                                               NUMBER
-- ONEPASS_EXECUTIONS                                                                                                               NUMBER
-- MULTIPASSES_EXECUTIONS                                                                                                           NUMBER
-- ACTIVE_TIME                                                                                                                      NUMBER
-- MAX_TEMPSEG_SIZE                                                                                                                 NUMBER
-- LAST_TEMPSEG_SIZE                                                                                                                NUMBER
@plusenv
col opid	format 999
col optype	format a20
col policy	format a04
col last_degree format 99	head 'Par'
col e_opt	format 999999999	head 'Opt Est'
col max_tmp	format 999999999	head 'Max Temp'
col last_tmp	format 999999999	head 'Last Temp'
col acttime	format 99999		head 'Active|Time'
SELECT *
FROM   ( SELECT sql_id, workarea_address, OPERATION_ID opid, operation_type optype, policy, active_time acttime, LAST_DEGREE, estimated_optimal_size e_opt ,MAX_TEMPSEG_SIZE max_tmp,LAST_TEMPSEG_SIZE last_tmp
         FROM V$SQL_WORKAREA
        ORDER BY estimated_optimal_size )
 WHERE ROWNUM <= 10;
