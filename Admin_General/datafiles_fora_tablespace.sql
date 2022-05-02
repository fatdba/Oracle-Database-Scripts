REM ------------------------------------------------------------------------------------------------
REM #DESC      : List all data files for a given tablespace pattern
REM Usage      : Input parameter: ts_pattern
REM Description: 
REM ------------------------------------------------------------------------------------------------

@plusenv

col tsname 	format a30	head 'Tablespace Name'
col fid 	format 999	head 'FID'
col crtime	format a14	head 'Creation Date'
col urtime	format a14	head 'Unrecoverable|Date'
col fname 	format a66	head 'File Name'
col MB 		format 999999

clear breaks
clear computes

break on 	tsname skip 1
break on 	report on tsname
compute sum of 	MB on report

SELECT	 ddf.tablespace_name		tsname
	,ddf.file_id 			fid
	,vdf.bytes/(1024*1024)		MB
	,to_char(vdf.creation_time,'YYYYMMDD HH24MI') crtime
	,to_char(vdf.unrecoverable_time,'YYYYMMDD HH24MI') urtime
	,ddf.file_name 			fname 
FROM 	 dba_data_files			ddf
	,v$datafile			vdf
WHERE	 ddf.tablespace_name		like upper('%&ts_pattern')
AND	 ddf.file_id			= vdf.file#
ORDER BY tsname,to_number(regexp_replace(substr(fname,instr(fname,'-',-1)+1),'\D',null))
	,fid
;
