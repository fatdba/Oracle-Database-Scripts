REM ------------------------------------------------------------------------------------------------
REM #DESC      : Tablespace free space summary
REM Usage      : 
REM Description: 
REM ------------------------------------------------------------------------------------------------

@plusenv

col flag	format a01		head 'F'
col tsname	format a30		head 'Tablespace Name'
col alloc 	format 999,999,999	head 'Allocated'
col freesp 	format 999,999,999	head 'Tot Free'
col largestf	format 99,999		head 'Largest|Free'
col pctu	format 999.9		head 'Pct|Usd'
col lnext	format 999.9		head 'Largest|Next'

break on report
compute sum of alloc 	on report
compute sum of freesp 	on report

SELECT 	 
	 sum(df.bytes)/(1024*1024) 		alloc
	,decode(sign(90 - 100*(sum(df.bytes)/(1024*1024)-fs.fspace)/(sum(df.bytes)/(1024*1024))),-1,'x',' ') flag
	,df.tablespace_name			tsname
	,fs.fspace				freesp
	,fs.mspace				largestf
	,seg.lnext				lnext
	,100*(sum(df.bytes)/(1024*1024)-fs.fspace)/(sum(df.bytes)/(1024*1024))		pctu
FROM 	 
	 (SELECT 	 tablespace_name 			tsname
	 		,sum(bytes)/(1024*1024) 		fspace 
	 		,max(bytes)/(1024*1024) 		mspace 
	  FROM 		 dba_free_space 
	  GROUP BY 	 tablespace_name
	 ) 					fs
	,(SELECT 	 tablespace_name 			tsname
	 		,max(next_extent)/(1024*1024) 		lnext
	  FROM 		 dba_segments
	  GROUP BY 	 tablespace_name
	 ) 					seg
	,dba_data_files				df
WHERE	 df.tablespace_name			= fs.tsname (+)
AND	 df.tablespace_name			= seg.tsname (+)
GROUP BY df.tablespace_name
	,fs.mspace
	,fs.fspace
	,seg.lnext
ORDER BY df.tablespace_name
;

SELECT 	 tablespace_name			tsname
	,sum(bytes)/(1024*1024)			alloc
FROM	 dba_temp_files
GROUP BY tablespace_name
;
