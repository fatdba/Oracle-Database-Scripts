WITH 
rac AS (SELECT COUNT(*) instances, CASE COUNT(*) WHEN 1 THEN 'Single-instance' ELSE COUNT(*)||'-node RAC cluster' END db_type FROM gv$instance),
mem AS (SELECT SUM(value) target FROM gv$system_parameter2 WHERE name = 'memory_target'),
sga AS (SELECT SUM(value) target FROM gv$system_parameter2 WHERE name = 'sga_target'),
pga AS (SELECT SUM(value) target FROM gv$system_parameter2 WHERE name = 'pga_aggregate_target'),
db_block AS (SELECT value bytes FROM v$system_parameter2 WHERE name = 'db_block_size'),
db AS (SELECT name, platform_name FROM v$database),
 pdbs AS (SELECT * FROM v$pdbs), 
inst AS (SELECT  host_name, version db_version FROM v$instance),
data AS (SELECT  SUM(bytes) bytes, COUNT(*) files, COUNT(DISTINCT ts#) tablespaces FROM v$datafile),
temp AS (SELECT  SUM(bytes) bytes FROM v$tempfile),
log AS (SELECT SUM(bytes) * MAX(members) bytes FROM v$log),
control AS (SELECT  SUM(block_size * file_size_blks) bytes FROM v$controlfile),
 cell AS (SELECT COUNT(DISTINCT cell_name) cnt FROM v$cell_state),
core AS (SELECT  SUM(value) cnt FROM gv$osstat WHERE stat_name = 'NUM_CPU_CORES'),
cpu AS (SELECT  SUM(value) cnt FROM gv$osstat WHERE stat_name = 'NUM_CPUS'),
pmem AS (SELECT SUM(value) bytes FROM gv$osstat WHERE stat_name = 'PHYSICAL_MEMORY_BYTES')
SELECT 
       'Database name:' system_item, db.name system_value FROM db
UNION ALL
 SELECT '    pdb:'||name, 'Open Mode:'||open_mode FROM pdbs -- need 12c flag
  UNION ALL
SELECT 'Oracle Database version:', inst.db_version FROM inst
 UNION ALL
SELECT 'Database block size:', TRIM(TO_CHAR(db_block.bytes / POWER(2,10), '90'))||' KB' FROM db_block
 UNION ALL
SELECT 'Database size:', TRIM(TO_CHAR(ROUND((data.bytes + temp.bytes + log.bytes + control.bytes) / POWER(10,12), 3), '999,999,990.000'))||' TB'
  FROM db, data, temp, log, control
 UNION ALL
SELECT 'Datafiles:', data.files||' (on '||data.tablespaces||' tablespaces)' FROM data
 UNION ALL
SELECT 'Database configuration:', rac.db_type FROM rac
 UNION ALL
SELECT 'Database memory:',
CASE WHEN mem.target > 0 THEN 'MEMORY '||TRIM(TO_CHAR(ROUND(mem.target / POWER(2,30), 1), '999,990.0'))||' GB, ' END||
CASE WHEN sga.target > 0 THEN 'SGA '   ||TRIM(TO_CHAR(ROUND(sga.target / POWER(2,30), 1), '999,990.0'))||' GB, ' END||
CASE WHEN pga.target > 0 THEN 'PGA '   ||TRIM(TO_CHAR(ROUND(pga.target / POWER(2,30), 1), '999,990.0'))||' GB, ' END||
CASE WHEN mem.target > 0 THEN 'AMM' ELSE CASE WHEN sga.target > 0 THEN 'ASMM' ELSE 'MANUAL' END END
  FROM mem, sga, pga
 UNION ALL
 SELECT 'Hardware:', CASE WHEN cell.cnt > 0 THEN 'Engineered System '||
 CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%5675%' THEN 'X2-2 ' END||
 CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%2690%' THEN 'X3-2 ' END||
 CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%2697%' THEN 'X4-2 ' END||
 CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%2699%' THEN 'X5-2 or X-6 ' END||
 CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%8160%' THEN 'X7-2 ' END||
 CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%8870%' THEN 'X3-8 ' END||
 CASE WHEN 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' LIKE '%8895%' THEN 'X4-8 or X5-8 ' END||
 'with '||cell.cnt||' storage servers'
 ELSE 'Unknown' END FROM cell
  UNION ALL
SELECT 'Processor:', 'Intel(R) Xeon(R) CPU E5-2640 v3 @ 2.60GHz' FROM DUAL
 UNION ALL
SELECT 'Physical CPUs:', core.cnt||' cores'||CASE WHEN rac.instances > 0 THEN ', on '||rac.db_type END FROM rac, core
 UNION ALL
SELECT 'Oracle CPUs:', cpu.cnt||' CPUs (threads)'||CASE WHEN rac.instances > 0 THEN ', on '||rac.db_type END FROM rac, cpu
 UNION ALL
SELECT 'Physical RAM:', TRIM(TO_CHAR(ROUND(pmem.bytes / POWER(2,30), 1), '999,990.0'))||' GB'||CASE WHEN rac.instances > 0 THEN ', on '||rac.db_type END FROM rac, pmem
 UNION ALL
SELECT 'Operating system:', db.platform_name FROM db;
