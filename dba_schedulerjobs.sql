set line 200

col start_date format a20

col owner format a10
col job_name format a20
col program_name format a20
col enabled format a3 head 'ENA|BLE' 
col start_date format a21 head 'START DATE'
col next_run_date format a21 head 'NEXT RUN DATE'
col last_start_date format a21 head 'LAST START DATE'
col repeat_interval format a15 head 'REPEAT INTERVAL' word_wrapped
col last_run_duration format a14 head 'LAST RUN|DURATION|DD:HH:MM:SS' 
col run_count format 99,999 head 'RUN|COUNT'
col retry_count format 9999 head 'RETRY|COUNT'
col max_runs format 999,999 head 'MAX|RUNS'
col job_action format a15 head 'CODE' word_wrapped

select 
	owner
	, job_name
	--, program_name
	, to_char(cast(start_date as date),'mm/dd/yy-hh24:mi:ss') 
		|| ' ' || extract (timezone_abbr from start_date ) 
		start_date
	--, state
	, case enabled
		when 'TRUE' then 'YES'
		when 'FALSE' then 'NO'
		end enabled
	-- last_run_duration is an interval
	, lpad(nvl(extract (day from last_run_duration ),'00'),2,'0')
		|| ':' || lpad(nvl(extract (hour from last_run_duration ),'00'),2,'0')
		|| ':' || lpad(nvl(extract (minute from last_run_duration ),'00'),2,'0')
		|| ':' || ltrim(to_char(nvl(extract (second from last_run_duration ),0),'09.90'))
		last_run_duration
	, to_char(cast(next_run_date as date),'mm/dd/yy-hh24:mi:ss') 
		|| ' ' || extract (timezone_abbr from next_run_date ) 
		next_run_date
	, to_char(cast(last_start_date as date),'mm/dd/yy-hh24:mi:ss') 
		|| ' ' || extract (timezone_abbr from last_start_date ) 
		last_start_date
	, run_count
	--, max_runs
	, retry_count
	, job_action
	, repeat_interval
	, state
from DBA_SCHEDULER_JOBS

order by owner
/
