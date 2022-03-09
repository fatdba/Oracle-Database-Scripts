undef object_string
@plusenv
col oname	format a40
col subobj	format a30
col objtype	format a10		trunc
col sta		format a03		trunc
col syn		format a44
col created	format a15
col lastddl	format a15
col objid	format 9999999999
col ar		format a02 head '=>'
break on syn

select	 decode(s.synonym_name,null,'   ',s.owner||'.'||s.synonym_name) syn
	,decode(s.synonym_name,null,'  ','=>') ar
        ,o.owner||'.'||o.object_name	oname
	,subobject_name	subobj
	,object_type	objtype
	,status		sta
	,object_id	objid
	,to_char(created,'YYMMDD HH24:MI:SS')		created
	,to_char(last_ddl_time,'YYMMDD HH24:MI:SS')	lastddl
from 	 dba_objects	o
	,dba_synonyms	s
where 	(o.object_name 	like upper('%&&object_string%')
      or s.synonym_name like upper('%&&object_string%'))
and	 o.owner	= s.table_owner (+)
and	 o.object_name	= s.table_name  (+)
and	 object_type	not like '%PARTITION%'
and	 object_type	not in ('SYNONYM')
order by o.owner||'.'||o.object_name
	,s.owner||'.'||s.synonym_name
	,object_type
;
