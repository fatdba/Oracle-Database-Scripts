-- To identify objects that have incremental statistics either use dbms_stats.get_prefs or use the following select:
SELECT owner,  object_name
FROM dba_objects
WHERE object_id IN
  (SELECT DISTINCT(obj#)
  FROM optstat_user_prefs$
  WHERE PNAME='INCREMENTAL'
  AND VALCHAR='TRUE'
  ); 


-- To list objects that have synopses:
col owner format a20;
col object_name format a20;
with tabpart as (SELECT OBJ#,DATAOBJ#, synop.bo#
  FROM sys.tabpart$ tap, (SELECT DISTINCT(bo#) FROM SYS.WRI$_OPTSTAT_SYNOPSIS$) synop
  WHERE tap.bo#(+) = synop.bo# ) select DISTINCT(owner),  nvl(object_name,'**ORPHANED') as object_name,  bo#,COUNT(*)
FROM dba_objects do, tabpart tp
WHERE do.object_id(+) = tp.OBJ#
and   do.data_object_id(+) = dataobj#
group by owner, object_name, bo#
;
