@plusenv
col c1 	format a35		head 'Workarea Profile' 
col c2 	format 9,999,999,999 	head 'Count'
col c3 	format 999.99		head 'Pct'
select name c1,count c2,decode(total, 0, 0, count*100/total) c3
from
(
select name,value count,(sum(value) over ()) total
from
v$sysstat
where
name like 'workarea exec%'
);
