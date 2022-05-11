select 'Should be executed on standby' Note from dual ;
select 'data:'||to_char(min(mtime),'YYYY.MM.DD HH24:MI')||','||
           to_char(round((sysdate - min(mtime))*24*60,1),'999999.9')||':' as "applied_log_time(mins)"
       from (
             select min(CHECKPOINT_TIME) mtime  from v$datafile_header
             union
             select controlfile_time mtime from v$database
            ) ;
