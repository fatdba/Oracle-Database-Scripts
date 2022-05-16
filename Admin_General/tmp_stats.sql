SELECT phyrds
, phyblkrd
, ROUND((phyblkrd / phyrds),2) blocks_per_read
FROM (SELECT SUM(f.phyrds) phyrds
, SUM(f.phyblkrd) phyblkrd
FROM v$tempstat f
)
;
