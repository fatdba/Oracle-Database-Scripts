PROMPT
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
PROMPT----- Script: parentchild_rel.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Cat: To identify parent child relationship in case of FKs
PROMPT----- Version: V1.1 (Date: 18-01-2013)
PROMPT-----
PROMPT-----
PROMPT-----
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

col "Child table" for a30
col "Parent table" for a20
set linesize 400 pagesize 400

select
child.owner || '.' || child.table_name "Child table", parent.owner || '.' || parent.table_name "Parent table"
from
user_constraints child, user_constraints parent
where
child.r_constraint_name = parent.constraint_name
and
child.table_name like '&TABLE_NAME' ;
