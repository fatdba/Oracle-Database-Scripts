PROMPT
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT------                 /)  (\
PROMPT------            .-._((,~~.))_.-,
PROMPT------             `-.   @@   ,-'
PROMPT------               / ,o--o. \
PROMPT------              ( ( .__. ) )
PROMPT------               ) `----' (
PROMPT------              /          \
PROMPT------             /            \
PROMPT------            /              \
PROMPT------    "The Silly Cow"
PROMPT----- Script: ddl-objects.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Version: V1.3 (Date: 04-12-2014)
PROMPT-----
PROMPT-----
PROMPT-----

SELECT 'SELECT dbms_metadata.get_ddl(''DB_LINK'',''' || db_link || ''',''' || owner || ''') FROM dual;' 
FROM dba_db_links WHERE db_link  IN ('DB_LINK1', 'DB_LINK2','DB_LINK3');

select dbms_metadata.get_ddl('TABLE','&Table_Name','&Schema') from dual;
select dbms_metadata.get_ddl('INDEX','&Index_Name','&Schema') from dual;

SELECT DBMS_METADATA.get_ddl('CONSTRAINT', '&constraint_name', '&owner') from dual;


SELECT dbms_metadata.get_ddl('PROCOBJ', '&job_name', '&owner') FROM DUAL;
SELECT dbms_metadata.get_ddl('PROCOBJ', '&program_name', '&owner') FROM DUAL;
SELECT dbms_metadata.get_ddl('TABLE', '&table_name', '&owner') FROM DUAL;
SELECT dbms_metadata.get_ddl('VIEW', '&view_name', '&owner') FROM DUAL;
SELECT dbms_metadata.get_ddl('MATERIALIZED_VIEW', '&MVIEW_NAME', '&OWNER_NAME')  FROM DUAL;

SELECT dbms_metadata.get_ddl('PACKAGE', '&pkg_name', '&owner') FROM DUAL; 
SELECT dbms_metadata.get_ddl('PROCEDURE', '&proc_name', '&owner') FROM DUAL; 

SELECT dbms_metadata.get_ddl('TYPE', 'type_name', '&owner') FROM DUAL;
