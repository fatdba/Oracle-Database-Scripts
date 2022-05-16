
set lines 170 pages 1000 feed off echo off

--------------------------------------------------
prompt
prompt -- shared pool allocation --;
--------------------------------------------------
col name 	format a33
col value 	format a18
SELECT	 name
	,value
FROM	 v$parameter
WHERE	 name in
	('shared_pool_size'
	,'shared_pool_reserved_size'
	,'large_pool_size'
	)
OR	 name 	like '%shared_pool%'
;

--------------------------------------------------
prompt
prompt -- shared pool usage and free space --;
--------------------------------------------------

col name 	format a30
col bytes 	format 9,999,999,999
col mb		format 9,9999.99

SELECT	  
       	 pool
	,round(bytes/(1024*1024),2)	mb
	,bytes
	,name 
FROM 	 v$sgastat
WHERE 	 name 	in 	('free memory'
			,'session heap'
			,'sql area'
			,'library cache'
			,'dictionary cache'
			)
;

--------------------------------------------------
prompt
prompt -- reserve pool statistics --;
--------------------------------------------------

col	fs		format	9999999999999	head 'Free|Spc'
col	afs		format	99999999	head 'Free|Avg'
col	fc		format	999999		head 'Free|Cnt'
col	mfs		format	9999999999	head 'Free|Max'
col	us		format	9999999999	head 'Used|Spc'
col	aus		format	999999		head 'Used|Avg'
col	uc		format	999999		head 'Used|Cnt'
col	mus		format	99999999999	head 'Used|Max'
col	r		format	9999999999	head 'Requests'
col	rm		format	999		head 'Miss|Req'
col	lms		format  999999		head 'Miss|Last'
col	mms		format  999999		head 'Miss|Max'
col	f		format	9999999999	head 'Request|Faiures'
col	lfs		format  999999999	head 'Last|Failure|Size'
col	art		format  999999999999	head 'Aborted|Req|Threshld'
col	ar		format	999999		head 'Ab|Rq'
col	las		format  999999		head 'Last|Abort|Size'

SELECT	 free_space			fs
	,avg_free_size			afs
	,free_count			fc
	,max_free_size			mfs
	,used_space			us
	,avg_used_size			aus
	,used_count			uc
	,max_used_size			mus
	,requests			r
	,request_failures		f
	,last_failure_size		lfs
	,aborted_request_threshold	art
	,last_aborted_size		las
FROM	 v$shared_pool_reserved
;
----------------------------------------------------
--prompt 
--prompt -- newly loaded SQLs - last 3 minutes --;
----------------------------------------------------
--
--col	ltime	format a14	head "First Load Time"	trunc
--col	mem	format 999,999
--col	exe	format 999
--col	par	format 999
--col	ld	format 999
--col	module	format a20	trunc
--col	sqltext	format a74	word_wrapped
--
--SELECT	 /* check-shared-pool */
--       	 substr(first_load_time,3,14) 	ltime
--	,sharable_mem		mem
--	,executions		exe
--	,loads			ld
--	,module			module
--	,hash_value 
--	,sql_text		sqltext
--FROM 	 v$sqlarea
--WHERE    to_date(first_load_time,'YYYY-MM-DD/HH24:MI:SS') > (sysdate - 3/(24*60))
--AND	 sql_text		not like '%check-shared-pool%'
--ORDER BY 1,2 desc
--;
--
----------------------------------------------------
--prompt 
--prompt -- suspicious SQLs (without bind variables) --;
----------------------------------------------------
--
--col sqltext	format a60
--col avgexec	format 999,999,999
--col count	format 999,999
--
--SELECT	 /* check-shared-pool */
--       	 substr(sql_text,1,60)	sqltext
--	,avg(executions) 	avgexec
--	,count(*) 		count
--FROM 	 v$sqlarea
--GROUP BY substr(sql_text,1,60) 
--HAVING   count(*) > 50
--ORDER BY count(*) desc
--;
--
----------------------------------------------------
--prompt 
--prompt -- version count > 50 --;
----------------------------------------------------
--
--col hash    	format 9999999999
--col sqltext	format a90
--col exec	format 999,999,999
--col vcount	format 999,999
--
--SELECT	 /* check-shared-pool */
--       	 hash_value		hash
--	,executions 		exec
--	,version_count		vcount
--       	,sql_text		sqltext
--FROM 	 v$sqlarea
--WHERE    version_count		> 50
--ORDER BY version_count
--;
--
----------------------------------------------------
--prompt 
--prompt -- hash chain > 5 --;
----------------------------------------------------
--
--col hash    	format 9999999999
--col hashcnt	format 99,999
--
--SELECT	 /* check-shared-pool */
--       	 hash_value		hash
--       	,count(*)		hashcnt
--FROM 	 v$sqlarea
--GROUP BY hash_value
--HAVING	 count(*)		> 5
--;
--
--------------------------------------------------
prompt 
prompt -- LRU statistics --;
--------------------------------------------------
col addr	noprint
col inst_id	noprint
col indx	noprint
col ksmlrsiz    format 99999999
col ksmlrnum    format 9999999
col KGHLUIDX	format 999	head 'UIDX'
col KGHLUDUR	format 999	head 'UDUR'
col KGHLUFSH	format 9999999999	head 'Flushes'
col KGHLUOPS	format 99999999999 head 'Pins|Releases'
col KGHLURCR	format 9999999 head 'Recurr'
col KGHLUTRN	format 9999999 head 'Trsnt'
col KGHLUMXA	format 9999999999
col KGHLUMES	format 999999
col KGHLUMER	format 999999
col KGHLURCN	format 999999999
col KGHLURMI	format 99999999
col KGHLURMZ	format 9999999
col KGHLUSHRPOOL format 999	head 'Pool'
col KGHLURMX	format 9999999
col KGHLUNFU	format 9999999	head '04031|Errors'
col KGHLUNFS	format 999999	head 'Error|Size'

SELECT   *
FROM     x$kghlu
;
--------------------------------------------------
prompt 
prompt -- latest LRU flushes --;
--------------------------------------------------

col objname     format a32      trunc
col alloctype   format a30      trunc
col objsize     format 999999
col flushes     format 99999
col sid         format 99999
col module      format a30      trunc
col hashvalue   format 999999999999
col orauser     format a08	trunc

SELECT	 
         a.ksmlrhon             objname
        ,a.ksmlrcom             alloctype
        ,a.ksmlrsiz             objsize
        ,a.ksmlrnum             flushes
        ,b.sid
        ,b.username             orauser
        ,b.module
        ,b.sql_hash_value       hashvalue
FROM     x$ksmlru a
        ,v$session b
WHERE    ksmlrsiz > 0
AND      a.ksmlrses = b.saddr
;


----------------------------------------------------
--prompt
--prompt -- memory chunks in shared pool reserve --;
----------------------------------------------------
--
--SELECT 	 ksmchcom
--	,count(*)
--	,min(ksmchsiz)
--	,round(avg(ksmchsiz))
--	,max(ksmchsiz)
--	,sum(ksmchsiz) 
--FROM 	 x$ksmspr 
--GROUP BY ksmchcom
--;
--
----------------------------------------------------
--prompt
--prompt -- memory chunks in shared pool --;
----------------------------------------------------
--
--SELECT 	 ksmchcom
--	,count(*)
--	,min(ksmchsiz)
--	,round(avg(ksmchsiz))
--	,max(ksmchsiz)
--	,sum(ksmchsiz) 
--FROM 	 x$ksmsp
--GROUP BY ksmchcom
--;
