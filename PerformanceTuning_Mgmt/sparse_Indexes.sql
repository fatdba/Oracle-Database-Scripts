SELECT index_owner, index_name, partition_name, leaf_blocks, pct_free, col_len, num_rows, ini_trans,
  TRUNC (leaf_blocks - ( (num_rows * (col_len + 10)) / ( (block_size - 66 - ini_trans * 24) * (1 - pct_free / 100)))) extra_blocks, 
  ROUND (100 * (1 - (leaf_blocks - ( (num_rows * (col_len + 10)) / ( (block_size - 66 - ini_trans * 24) * (1 - pct_free / 100)))) / leaf_blocks), 2) density,
  ROUND (leaf_blocks * 8 / 1024 / 1024, 2) GB,
  ROUND (TRUNC (leaf_blocks - ( (num_rows * (col_len + 10)) / ( (block_size - 66 - ini_trans * 24) * (1 - pct_free / 100)))) * 8 / 1024 / 1024, 2) extra_GB, 
  ROUND (TRUNC (leaf_blocks - ( (num_rows * (col_len + 10)) / ( (block_size - 66 - ini_trans * 24) * (1 - 0 / 100)))) * 8 / 1024 / 1024, 2) extra_GB_0_PCTFREE
FROM
  (
    SELECT ip.index_owner, ip.index_name, ip.partition_name, ip.leaf_blocks, ip.num_rows, ip.pct_free, ip.ini_trans,
      cl.col_len, ts.block_size
    FROM dba_ind_partitions ip, dba_indexes i, dba_tablespaces ts, (
        SELECT ic.index_owner, ic.index_name, tc.partition_name, SUM (tc.avg_col_len) col_len
        FROM dba_ind_columns ic, DBA_PART_COL_STATISTICS tc
        WHERE ic.table_owner = :OWNERNAME
        AND ic.table_name = :TABLENAME
        AND tc.owner = ic.table_owner
        AND tc.table_name = ic.table_name
        AND tc.column_name = ic.column_name
        GROUP BY ic.index_owner, ic.index_name, partition_name
      )
      cl
    WHERE ip.index_owner = i.owner
    AND ip.index_name = i.index_name
    AND i.table_owner = :OWNERNAME
    AND i.table_name = :TABLENAME
    AND cl.index_owner = i.owner
    AND cl.index_name = i.index_name
    AND cl.partition_name = ip.partition_name
    AND ip.tablespace_name = ts.tablespace_name
    AND ip.leaf_blocks > 0
    UNION ALL
    SELECT i.owner index_owner, i.index_name, NULL partition_name, i.leaf_blocks, i.num_rows, i.pct_free, i.ini_trans,
      cl.col_len, ts.block_size
    FROM dba_indexes i, dba_tablespaces ts, (
        SELECT ic.index_owner, ic.index_name, SUM (tc.avg_col_len) col_len
        FROM dba_ind_columns ic, DBA_TAB_COL_STATISTICS tc
        WHERE ic.table_owner = :OWNERNAME
        AND ic.table_name = :TABLENAME
        AND tc.owner = ic.table_owner
        AND tc.table_name = ic.table_name
        AND tc.column_name = ic.column_name
        GROUP BY ic.index_owner, ic.index_name
      )
      cl
    WHERE i.table_owner = :OWNERNAME
    AND i.table_name = :TABLENAME
    AND i.partitioned = 'NO'
    AND cl.index_owner = i.owner
    AND cl.index_name = i.index_name
    AND i.tablespace_name = ts.tablespace_name
    AND i.leaf_blocks > 0    
  )
ORDER BY index_owner, index_name, partition_name ;
