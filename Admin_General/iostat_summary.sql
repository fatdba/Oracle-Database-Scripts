--
-- iostat summary by filesystem
--
@plusenv
col ftype	format a10		head 'File Type' trunc
col fs		format a10		head 'FileSystem'
col sr_req	format 9,999,999,999	head 'Small Read|Requests'
col lr_req	format 9,999,999,999	head 'Large Read|Requests'
col sr_svctm	format 999.9		head 'Small Read|Svc Time'
col lr_svctm	format 999.9		head 'Large Read|Svc Time'

break on ftype skip 1
select 	 filetype_name					ftype
	,substr(df.name,1,instr(df.name,'/',2)-1) 	fs
	,sum(ios.SMALL_READ_REQS)			sr_req
	,sum(ios.SMALL_READ_SERVICETIME)/sum(ios.SMALL_READ_REQS) 	sr_svctm
	,sum(ios.LARGE_READ_REQS)			lr_req
	,sum(ios.LARGE_READ_SERVICETIME)/decode(sum(ios.LARGE_READ_REQS),0,1)	lr_svctm
from 	 v$iostat_file	ios
	,v$datafile	df
where	 FILETYPE_NAME = 'Data File'
and	 df.file#	= ios.file_no
group by filetype_name
	,substr(df.name,1,instr(df.name,'/',2)-1)
union all
select 	 filetype_name					ftype
	,substr(tf.name,1,instr(tf.name,'/',2)-1) 	fs
	,sum(ios.SMALL_READ_REQS)			sr_req
	,sum(ios.SMALL_READ_SERVICETIME)/sum(ios.SMALL_READ_REQS) 	sr_svctm
	,sum(ios.LARGE_READ_REQS)			lr_req
	,sum(ios.LARGE_READ_SERVICETIME)/decode(sum(ios.LARGE_READ_REQS),0,1)	lr_svctm
from 	 v$iostat_file	ios
	,v$tempfile	tf
where	 FILETYPE_NAME = 'Temp File'
and	 tf.file#	= ios.file_no
group by filetype_name
	,substr(tf.name,1,instr(tf.name,'/',2)-1)
union all
select 	 filetype_name					ftype
	,'Redo'					 	fs
	,sum(ios.SMALL_READ_REQS)			sr_req
	,sum(ios.SMALL_READ_SERVICETIME)/sum(ios.SMALL_READ_REQS) 	sr_svctm
	,sum(ios.LARGE_READ_REQS)			lr_req
	,sum(ios.LARGE_READ_SERVICETIME)/decode(sum(ios.LARGE_READ_REQS),0,1)	lr_svctm
from 	 v$iostat_file	ios
where	 FILETYPE_NAME = 'Log File'
group by filetype_name
	,'Redo'
order by 1,4
;
