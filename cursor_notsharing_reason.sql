set linesi 190
col reason format a30
set pagesi 0
undef sql_id
select sql_id,child_number, 
 ''
 ||decode((                UNBOUND_CURSOR),'Y',               ' UNBOUND_CURSOR')
 ||decode((             SQL_TYPE_MISMATCH),'Y',            ' SQL_TYPE_MISMATCH')
 ||decode((            OPTIMIZER_MISMATCH),'Y',           ' OPTIMIZER_MISMATCH')
 ||decode((              OUTLINE_MISMATCH),'Y',             ' OUTLINE_MISMATCH')
 ||decode((            STATS_ROW_MISMATCH),'Y',           ' STATS_ROW_MISMATCH')
 ||decode((              LITERAL_MISMATCH),'Y',             ' LITERAL_MISMATCH')
 ||decode((           EXPLAIN_PLAN_CURSOR),'Y',          ' EXPLAIN_PLAN_CURSOR')
 ||decode((         BUFFERED_DML_MISMATCH),'Y',        ' BUFFERED_DML_MISMATCH')
 ||decode((             PDML_ENV_MISMATCH),'Y',            ' PDML_ENV_MISMATCH')
 ||decode((           INST_DRTLD_MISMATCH),'Y',          ' INST_DRTLD_MISMATCH')
 ||decode((             SLAVE_QC_MISMATCH),'Y',            ' SLAVE_QC_MISMATCH')
 ||decode((            TYPECHECK_MISMATCH),'Y',           ' TYPECHECK_MISMATCH')
 ||decode((           AUTH_CHECK_MISMATCH),'Y',          ' AUTH_CHECK_MISMATCH')
 ||decode((                 BIND_MISMATCH),'Y',                ' BIND_MISMATCH')
 ||decode((             DESCRIBE_MISMATCH),'Y',            ' DESCRIBE_MISMATCH')
 ||decode((             LANGUAGE_MISMATCH),'Y',            ' LANGUAGE_MISMATCH')
 ||decode((          TRANSLATION_MISMATCH),'Y',         ' TRANSLATION_MISMATCH')
 ||decode((        ROW_LEVEL_SEC_MISMATCH),'Y',       ' ROW_LEVEL_SEC_MISMATCH')
 ||decode((                  INSUFF_PRIVS),'Y',                 ' INSUFF_PRIVS')
 ||decode((              INSUFF_PRIVS_REM),'Y',             ' INSUFF_PRIVS_REM')
 ||decode((         REMOTE_TRANS_MISMATCH),'Y',        ' REMOTE_TRANS_MISMATCH')
 ||decode((     LOGMINER_SESSION_MISMATCH),'Y',    ' LOGMINER_SESSION_MISMATCH')
 ||decode((          INCOMP_LTRL_MISMATCH),'Y',         ' INCOMP_LTRL_MISMATCH')
 ||decode((         OVERLAP_TIME_MISMATCH),'Y',        ' OVERLAP_TIME_MISMATCH')
 ||decode((         MV_QUERY_GEN_MISMATCH),'Y',        ' MV_QUERY_GEN_MISMATCH')
 ||decode((       USER_BIND_PEEK_MISMATCH),'Y',      ' USER_BIND_PEEK_MISMATCH')
 ||decode((           TYPCHK_DEP_MISMATCH),'Y',          ' TYPCHK_DEP_MISMATCH')
 ||decode((           NO_TRIGGER_MISMATCH),'Y',          ' NO_TRIGGER_MISMATCH')
 ||decode((              FLASHBACK_CURSOR),'Y',             ' FLASHBACK_CURSOR')
 ||decode((        ANYDATA_TRANSFORMATION),'Y',       ' ANYDATA_TRANSFORMATION')
 ||decode((             INCOMPLETE_CURSOR),'Y',            ' INCOMPLETE_CURSOR')
 ||decode((          TOP_LEVEL_RPI_CURSOR),'Y',         ' TOP_LEVEL_RPI_CURSOR')
 ||decode((         DIFFERENT_LONG_LENGTH),'Y',        ' DIFFERENT_LONG_LENGTH')
 ||decode((         LOGICAL_STANDBY_APPLY),'Y',        ' LOGICAL_STANDBY_APPLY')
 ||decode((                DIFF_CALL_DURN),'Y',               ' DIFF_CALL_DURN')
 ||decode((                BIND_UACS_DIFF),'Y',               ' BIND_UACS_DIFF')
 ||decode((        PLSQL_CMP_SWITCHS_DIFF),'Y',       ' PLSQL_CMP_SWITCHS_DIFF')
 ||decode((         CURSOR_PARTS_MISMATCH),'Y',        ' CURSOR_PARTS_MISMATCH')
 ||decode((           STB_OBJECT_MISMATCH),'Y',          ' STB_OBJECT_MISMATCH')
 ||decode((             PQ_SLAVE_MISMATCH),'Y',            ' PQ_SLAVE_MISMATCH')
 ||decode((        TOP_LEVEL_DDL_MISMATCH),'Y',       ' TOP_LEVEL_DDL_MISMATCH')
 ||decode((             MULTI_PX_MISMATCH),'Y',            ' MULTI_PX_MISMATCH')
 ||decode((       BIND_PEEKED_PQ_MISMATCH),'Y',      ' BIND_PEEKED_PQ_MISMATCH')
 ||decode((           MV_REWRITE_MISMATCH),'Y',          ' MV_REWRITE_MISMATCH')
 ||decode((         ROLL_INVALID_MISMATCH),'Y',        ' ROLL_INVALID_MISMATCH')
 ||decode((       OPTIMIZER_MODE_MISMATCH),'Y',      ' OPTIMIZER_MODE_MISMATCH')
 ||decode((                   PX_MISMATCH),'Y',                  ' PX_MISMATCH')
 ||decode((          MV_STALEOBJ_MISMATCH),'Y',         ' MV_STALEOBJ_MISMATCH')
 ||decode((      FLASHBACK_TABLE_MISMATCH),'Y',     ' FLASHBACK_TABLE_MISMATCH')
 ||decode((          LITREP_COMP_MISMATCH),'Y',         ' LITREP_COMP_MISMATCH')
 reason
from 
   v$sql_shared_cursor 
where sql_id='&sql_id'
;
undef sql_id
