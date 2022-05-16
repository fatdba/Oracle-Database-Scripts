SELECT phyrds
, phyblkrd
, ROUND((phyblkrd / phyrds),2) blocks_per_read
FROM (SELECT SUM(f.phyrds) phyrds
, SUM(f.phyblkrd) phyblkrd
FROM v$tempstat f
)
;


column name format a60

select ts.name tablespace_name, tf.name, tf.bytes/(1024*1024) mb
from v$tempfile tf, v$tablespace ts
where tf.ts# = ts.ts# order by ts.name, tf.name
;


