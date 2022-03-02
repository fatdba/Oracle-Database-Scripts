select to_char(creation_time, 'MM-RRRR') "Month", sum(bytes)/1024/1024/1024 "Growth in GB
from sys.v_$datafile
where to_char(creation_time,'RRRR')='&YEAR_IN_YYYY_FORMAT'
group by to_char(creation_time, 'MM-RRRR')
order by to_char(creation_time, 'MM-RRRR');
