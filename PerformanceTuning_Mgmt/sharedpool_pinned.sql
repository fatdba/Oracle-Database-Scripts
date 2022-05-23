set linesi 190
set pagesi 50
col name format a50
select 	NAME,
	TYPE,
	KEPT
from 	v$db_object_cache
where 	KEPT = 'YES';
