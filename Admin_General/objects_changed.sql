--
-- List all objects that were either created or modified or analyzed in the last_x_hours
-- Objects which were affected in the last 2 hours will be flagged
-- This script is used primarily to correlate cursor invalidations with object modifications
--
@plusenv
undef last_x_hours

col oname	format a42		head 'Object Name'
col objtype	format a10		head 'Obj Type'			trunc
col sta		format a03		head 'Sta'			trunc
col syn		format a40		head 'Synonym'
col created_pdt	format a14		head 'Creation PDT'
col lastddl_pdt	format a14		head 'Last DDL PDT'
col tlastana_pdt format a14		head 'Table|Last Ana PDT'
col ilastana_pdt format a14		head 'Index|Last Ana PDT'
col objid	format 99999999		head 'Object Id'
col ar		format a02 head '=>'
col cf		format a01		head 'x'
col df		format a01		head 'x'
col tf		format a01		head 'x'
col if		format a01		head 'x'
col sep		format a01		head '|'

select	 decode(s.synonym_name,null,'   ',s.owner||'.'||s.synonym_name) syn
	,decode(s.synonym_name,null,'  ','=>') 				ar
        ,o.owner||'.'||o.object_name					oname
	,o.object_type							objtype
	,o.status							sta
	,o.object_id							objid
	,'|'								sep
	,to_char(new_time(o.created,'GMT','PDT'),'YY/MM/DD HH24:MI')	created_pdt
	,decode(sign(sysdate-(o.created+2/24)),-1,'x',' ')		cf
	,'|'								sep
	,to_char(new_time(o.last_ddl_time,'GMT','PDT'),'YY/MM/DD HH24:MI')	lastddl_pdt
	,decode(sign(sysdate-(o.last_ddl_time+2/24)),-1,'x',' ')	df
	,'|'								sep
	,to_char(new_time(t.last_analyzed,'GMT','PDT'),'YY/MM/DD HH24:MI')	tlastana_pdt
	,decode(sign(sysdate-(t.last_analyzed+2/24)),-1,'x',' ')	tf
	,'|'								sep
	,to_char(new_time(i.last_analyzed,'GMT','PDT'),'YY/MM/DD HH24:MI')	ilastana_pdt
	,decode(sign(sysdate-(i.last_analyzed+2/24)),-1,'x',' ')	if
	,'|'								sep
from 	 dba_objects	o
	,dba_synonyms	s
	,dba_tables	t
	,dba_indexes	i
where 	(
	 o.last_ddl_time	>= sysdate - &&last_x_hours/24
      or o.created		>= sysdate - &&last_x_hours/24
      or t.last_analyzed	>= sysdate - &&last_x_hours/24
      or i.last_analyzed	>= sysdate - &&last_x_hours/24
	)
and	 o.owner	not in ('SYS','SYSTEM')
and	 o.owner	= s.table_owner (+)
and	 o.object_name	= s.table_name  (+)
and	 o.object_type	not like '%PARTITION%'
and	 o.owner	= t.owner (+)
and	 o.object_name	= t.table_name (+)
and	 o.owner	= i.owner (+)
and	 o.object_name	= i.index_name (+)
order by o.owner||'.'||o.object_name
;
