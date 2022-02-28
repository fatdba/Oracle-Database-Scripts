SELECT SUBSTR(t.name,1,50) AS file_name,
f.phyblkrd AS blocks_read,
f.phyblkwrt AS blocks_written,
f.phyblkrd + f.phyblkwrt AS total_io
FROM v$tempstat f,v$tempfile t
WHERE t.file# = f.file#
ORDER BY f.phyblkrd + f.phyblkwrt DESC;

 

select * from (SELECT u.tablespace, s.username, s.sid, s.serial#, s.logon_time, program, u.extents, ((u.blocks*8)/1024) as MB,
i.inst_id,i.host_name
FROM gv$session s, gv$sort_usage u ,gv$instance i
WHERE s.saddr=u.session_addr and u.inst_id=i.inst_id order by MB DESC) a where rownum<10;
