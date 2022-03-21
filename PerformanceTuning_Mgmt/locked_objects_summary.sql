@plusenv
col oname	format a40
col objid	format 99999999999
col cnt		format 9999
select o.owner||'.'||o.object_name oname, row_wait_obj# objid, count(*) cnt
from v$session s, dba_objects o
where row_wait_obj# is not null
and s.row_wait_obj# = o.object_id
group by o.owner||'.'||o.object_name, row_wait_obj#
having count(*) >5
order by 1
;
