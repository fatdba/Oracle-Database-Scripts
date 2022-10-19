--
--
--
SELECT s.sql_id, s.sql_text
FROM gv$sqlarea s JOIN dba_objects o ON s.program_id = o.object_id
and o.object_name = '&procedure_name';
