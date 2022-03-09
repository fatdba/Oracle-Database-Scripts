--
-- Given a string, find all SQLs referencing that string in sql_text (from v$sql) - ordered by physical reads
--
@plusenv
undef sql_string
col sql_id	format a13
col execs	format 99999999999
col bgets	format 99999999999
col bgetspx	format 99999999.9
col dreadspx	format 99999999.9
col cpusecs	format 9999999
col sqltext	format a50			trunc
col frclause	format a50			trunc
col module	format a23			trunc
col puser	format a10			trunc	head 'ParsingU'
col pctdread	format 99.9				head 'PRead|Pct'
col cnt		format 999
select 	 sql_id			sql_id
	,sum(executions)	execs
	,sum(buffer_gets)	bgets
	,sum(buffer_gets)/sum(executions)	bgetspx
	,sum(disk_reads)/sum(executions)	dreadspx
	,sum(cpu_time)/1000000	cpusecs
	,100*ratio_to_report(sum(disk_reads)) over () pctdread
	,module			module
	,parsing_schema_name	puser
	,count(*)		cnt
	,dbms_lob.substr(sql_fulltext,50,1)			sqltext
	,dbms_lob.substr(sql_fulltext,50,instr(lower(sql_text),'from ')) frclause
from 	 v$sql		s
where 	 lower(replace(sql_text,chr(13))) 	like lower('%&sql_string%')
and	 lower(replace(sql_text,chr(13)))		not like ('%v$sql%')
and	 executions		>0
group by sql_id
	,module
	,parsing_schema_name
	,dbms_lob.substr(sql_fulltext,50,1)			
	,dbms_lob.substr(sql_fulltext,50,instr(lower(sql_text),'from ')) 
order by sum(disk_reads)
;
