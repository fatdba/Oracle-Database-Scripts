col module	format a40					trunc
col secnt	format 999		head 'Ses|Cnt'
col a_leafs	format 99999		head 'Avg|Leaf|Split'
col s_leafs	format 9999999		head 'Sum|Leaf|Split'
col a_leafs90	format 9999		head 'Avg|Leaf|Splt90'
col s_leafs90	format 999999		head 'Sum|Leaf|Splt90'
col a_brnchs	format 999		head 'Avg|Br|Sp'
col s_brnchs	format 9999		head 'Sum|Br|Sp'
col acmin 	format 999999		head 'Avg|Conn|Mins'

break on module on hash
SELECT
	 decode(se.module,null,'N/A',se.module)		module
	,count(*)					secnt
	,avg((sysdate - se.logon_time)*(24*60))		acmin
	,sum(s318.value)				s_leafs
	,avg(s318.value)				a_leafs
	,sum(s319.value)				s_leafs90
	,avg(s319.value)				a_leafs90
	,sum(s320.value)				s_brnchs
	,avg(s320.value)				a_brnchs
FROM 	 
	 v$sesstat 		s318
	,v$sesstat 		s319
	,v$sesstat		s320
	,v$session 		se
WHERE 	 se.sid 		= s318.sid
AND	 se.sid			= s319.sid
AND	 se.sid			= s320.sid
AND   	 s318.statistic#	= 318	/* leaf node splits			*/
AND   	 s319.statistic#	= 319	/* leaf node 90-10 splits		*/
AND   	 s320.statistic#	= 320	/* branch node splits			*/
AND	 s319.value		> 50
GROUP BY se.module
ORDER BY sum(s318.value)
;
