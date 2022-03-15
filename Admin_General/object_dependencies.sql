-- This scripts prints all the dependencies(NOT dependents :) ) of a object. 
-- For instance, if we enter a view, it displays all the sub views, tables etc.. that are involved in that view directly or indeirectly.
set linesi 190
col refr format a170
set pagesi 0
select lpad(' ',(LEVEL-1)*10)||referenced_owner||'.'||referenced_name||' ('||decode(referenced_type,
'EVALUATION CONTXT', 'EVALCTXT', 'NON-EXISTENT CONTXT','NO-EXIST',
'PACKAGE BODY','PKGBDY', 'CUBE.DIMENSION','CUBE.DIM', referenced_type)||')'||(case when referenced_type='TABLE' then (select ' <---> '||owner||'.'||name||'(SNAP)'||'<--->'||to_char(LAST_REFRESH,'DD-MON-YYYY HH24:MI:SS') from dba_snapshots where owner=b.referenced_owner and table_name=b.referenced_name) else '' end) refr
from dba_dependencies b
start with lower(name)=lower('&object_name') and lower(owner)=lower('&object_owner') and lower(type)=lower('&object_type')
connect by prior referenced_name=name and prior referenced_owner=owner and prior referenced_type=type;
