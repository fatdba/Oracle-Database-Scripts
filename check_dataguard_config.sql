-- Not my script 
-- Written by Ludovico Caldara
-- Purpose   : Checks the health of a Data Guard configuration on ONE database
-- Run as    : SYSDBA , to execute on each DB in the config 
--             it does not check ALL the DBs in the configuration but only the current one
--             You can use a wrapper to check all the DBs in the configuration 
--             or all the standby instances on a server
-- Limitations: Does not work on RAC environments yet
--              Does not work on 11g databases (tested on 19c)
set serveroutput on
set lines 200
DECLARE
	v_dgconfig BINARY_INTEGER;
	v_num_errors BINARY_INTEGER;
	v_num_warnings BINARY_INTEGER;
	v_apply_lag INTERVAL DAY TO SECOND;
	v_transport_lag INTERVAL DAY TO SECOND;
	v_apply_th INTERVAL DAY TO SECOND;
	v_transport_th INTERVAL DAY TO SECOND;
	v_delay INTERVAL DAY TO SECOND;
	v_delaymins BINARY_INTEGER;
	v_flashback v$database.flashback_on%type;

	CURSOR c_dgconfig IS SELECT piv.*, obj.status FROM (
		SELECT object_id, attribute, value FROM x$drc
			WHERE object_id IN ( SELECT object_id FROM x$drc WHERE attribute = 'DATABASE')
	) drc PIVOT ( MAX ( value ) FOR attribute
		IN (
		'DATABASE' DATABASE ,
		'intended_state' intended_state ,
		'connect_string' connect_string ,
		'enabled' enabled ,
		'role' role ,
		'receive_from' receive_from ,
		'ship_to' ship_to ,
		'FSFOTargetValidity' FSFOTargetValidity
		)
	) piv JOIN x$drc obj ON ( obj.object_id = piv.object_id AND obj.attribute = 'DATABASE' )
	WHERE upper(piv.database)=sys_context('USERENV','DB_UNIQUE_NAME');

	CURSOR c_priconfig IS SELECT piv.*, obj.status FROM (
		SELECT object_id, attribute, value FROM x$drc
			WHERE object_id IN ( SELECT object_id FROM x$drc WHERE attribute = 'DATABASE')
	) drc PIVOT ( MAX ( value ) FOR attribute
		IN (
		'DATABASE' DATABASE ,
		'intended_state' intended_state ,
		'connect_string' connect_string ,
		'enabled' enabled ,
		'role' role ,
		'receive_from' receive_from ,
		'ship_to' ship_to ,
		'FSFOTargetValidity' FSFOTargetValidity
		)
	) piv JOIN x$drc obj ON ( obj.object_id = piv.object_id AND obj.attribute = 'DATABASE' )
	WHERE piv.role='PRIMARY';

	r_dgconfig c_dgconfig%ROWTYPE;
	r_priconfig c_priconfig%ROWTYPE;

	v_open_mode v$database.open_mode%TYPE;

	-- variables for the dbms_drs.do_control
	v_indoc VARCHAR2 ( 4000 );
	v_outdoc VARCHAR2 ( 4000 );
	v_rid NUMBER;
	v_context VARCHAR2(100);
	v_pieceno NUMBER ;
	/* xmltype does not work on mounted databases 
	v_y CLOB;
	v_z XMLTYPE;
	v_xml XMLTYPE;
	*/
	v_status VARCHAR2(100);
	v_error VARCHAR2(100);
	v_p_connect BINARY_INTEGER;
	v_s_connect BINARY_INTEGER;
	v_offline_datafiles BINARY_INTEGER;
	
BEGIN

	v_num_errors := 0;
	v_num_warnings := 0;
	v_p_connect := 0;
	v_s_connect := 0;

	dbms_output.put_line('Checking Data Guard Configuration for '||sys_context('USERENV','DB_UNIQUE_NAME'));
	dbms_output.put_line('--------------------------------------');
	-- get open_mode
	SELECT open_mode INTO v_open_mode FROM v$database;

	-- check if the configuration exists
	SELECT count(*) INTO v_dgconfig FROM x$drc;
	IF v_dgconfig = 0 THEN
		dbms_output.put_line('ERROR: Current database does not have a Data Guard config.');
		v_num_errors := v_num_errors + 1;
		GOTO stop_checks;
	else
		dbms_output.put_line('___OK: Current database has a Data Guard config.');
	END IF;

	-- fetch the current DB config in record
	OPEN c_dgconfig;
	BEGIN
		FETCH c_dgconfig INTO r_dgconfig;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN 
			dbms_output.put_line('ERROR: Current database does not have a Data Guard config.');
			v_num_errors := v_num_errors + 1;
			GOTO stop_checks;
	END;

	-- fetch the primary DB config in record
	OPEN c_priconfig;
	BEGIN
		FETCH c_priconfig INTO r_priconfig;
	EXCEPTION
		WHEN NO_DATA_FOUND THEN 
			dbms_output.put_line('ERROR: There is no primary database in the config?');
			v_num_errors := v_num_errors + 1;
			GOTO stop_checks;
	END;

	-- enabled?
	IF r_dgconfig.enabled = 'YES' THEN
		dbms_output.put_line('___OK: Current database is enabled in Data Guard.');
	ELSE
		dbms_output.put_line('ERROR: Current database is not enabled in Data Guard.');
		v_num_errors := v_num_errors + 1;
	END IF;

	-- status SUCCESS?
	IF r_dgconfig.status = 'SUCCESS' THEN
		dbms_output.put_line('___OK: Data Guard status for the database is: '||r_dgconfig.status);
	ELSE
		dbms_output.put_line('ERROR: Data Guard status for the database is: '||r_dgconfig.status);
		v_num_errors := v_num_errors + 1;
	END IF;

	-- reachability of the primary
	BEGIN
		dbms_drs.CHECK_CONNECT (r_priconfig.database ,r_priconfig.database);
		dbms_output.put_line('___OK: Primary ('||r_priconfig.database||') is reachable.');
		v_p_connect := 1;
	EXCEPTION
		WHEN OTHERS THEN
		dbms_output.put_line('ERROR: Primary ('||r_priconfig.database||') unreachable. Error code ' || SQLCODE || ': ' || SQLERRM);
		v_num_errors := v_num_errors + 1;
	END;

	-- if we are not on the primary, check the current database connectivity as well through the broker
	IF r_priconfig.object_id <> r_dgconfig.object_id THEN
		BEGIN
			dbms_drs.CHECK_CONNECT (r_dgconfig.database ,r_dgconfig.database);
			dbms_output.put_line('___OK: current DB ('||r_dgconfig.database||') is reachable.');
			v_s_connect := 1;
		EXCEPTION
			WHEN OTHERS THEN
			dbms_output.put_line('ERROR: current DB ('||r_dgconfig.database||') unreachable. Error code ' || SQLCODE || ': ' || SQLERRM);
			v_num_errors := v_num_errors + 1;
		END;
	END IF;


	-- we check primary transport only if reachable
	IF v_p_connect = 1 THEN
		-- primary logxpt?
		v_indoc := '<DO_MONITOR version="19.1"><PROPERTY name="LogXptStatus" object_id="'||r_priconfig.object_id||'"/></DO_MONITOR>';
		v_pieceno  := 1;
		dbms_drs.do_control(v_indoc, v_outdoc, v_rid, v_pieceno, v_context);
	
		select regexp_substr(v_outdoc, '(<TD >)([[:alnum:]].*?)(</TD>)',1,3,'i',2) into v_status from dual;

		/* does not work on MOUNTED databases 
		v_y := TO_CLOB ( v_outdoc );
		v_z := XMLType ( v_y );

		select xt.status , xt.error into v_status, v_error from xmltable  ('/TABLE/TR' passing v_z columns 
			status varchar2(100) PATH 'TD[3]',
			error varchar2(100) PATH 'TD[4]'
		) xt ;
		*/

		IF v_status = 'VALID' THEN
			dbms_output.put_line('___OK: LogXptStatus of primary is VALID.');
		ELSE
			dbms_output.put_line('ERROR: LogXptStatus of primary is '||nvl(v_status,'NULL'));
			v_num_errors := v_num_errors + 1;
		END IF;
	END IF;

	-- flashback?
	SELECT flashback_on into v_flashback
	FROM v$database;
	IF v_flashback = 'YES' THEN
		dbms_output.put_line('___OK: Flashback Logging is enabled.');
	ELSE
		dbms_output.put_line('_WARN: Flashback Logging is disabled.');
		v_num_warnings := v_num_warnings + 1;
	END IF;

	-- role?
	IF r_dgconfig.ROLE = 'PRIMARY' THEN
		dbms_output.put_line('___OK: The database is PRIMARY, skipping standby checks.');
		GOTO stop_checks;
	ELSE
		dbms_output.put_line('___OK: The database is STANDBY, executing standby checks.');
	END IF;

	-- intended state?
	IF r_dgconfig.intended_state = 'PHYSICAL-APPLY-ON' THEN
		dbms_output.put_line('___OK: The database intended state is APPLY-ON.');
	ELSIF r_dgconfig.intended_state = 'PHYSICAL-APPLY-READY' THEN
		dbms_output.put_line('_WARN: The database intended state is APPLY-OFF.');
		v_num_warnings := v_num_warnings + 1;
	ELSE
		dbms_output.put_line('ERROR: The database intended state is '||r_dgconfig.intended_state);
		v_num_errors := v_num_errors + 1;
	END IF;

	-- real time apply?
	IF v_open_mode = 'READ ONLY WITH APPLY' THEN
		dbms_output.put_line('_WARN: Real Time Apply is used.');
		v_num_warnings := v_num_warnings + 1;
	ELSIF v_open_mode = 'MOUNTED' THEN
		dbms_output.put_line('___OK: The standby database is mounted.');
	ELSE
		dbms_output.put_line('ERROR: The database open_mode is '||v_open_mode);
		v_num_errors := v_num_errors + 1;
	END IF;
	

	-- offline datafiles?
	BEGIN
		select count(distinct con_id) into v_offline_datafiles from v$recover_file where online_status='OFFLINE' group by con_id;
		dbms_output.put_line('ERROR: There are '||v_offline_datafiles||' OFFLINE datafiles');
		v_num_errors := v_num_errors + 1;
	EXCEPTION WHEN NO_DATA_FOUND THEN
		dbms_output.put_line('___OK: There are no PDBs with OFFLINE datafiles');
	END;

	-- we get the delay as well, so that we can compute the apply threshold in a more intelligent way than the broker...
	v_delaymins := dbms_drs.get_property_obj(r_dgconfig.object_id,'DelayMins');
	v_delay := numtodsinterval(v_delaymins,'minute');

	IF v_delaymins > 0 THEN
		dbms_output.put_line('_WARN: Standby delayed by '||v_delaymins||' minutes.');
		v_num_warnings := v_num_warnings + 1;
	END IF;

	-- apply lag?
	v_apply_th := numtodsinterval(dbms_drs.get_property_obj(r_dgconfig.object_id,'ApplyLagThreshold'),'second');
	BEGIN
		SELECT TO_DSINTERVAL(value) into v_apply_lag FROM v$dataguard_stats WHERE name='apply lag';
		IF v_apply_lag > ( v_apply_th + v_delay ) THEN
			dbms_output.put_line('ERROR: apply lag is '||v_apply_lag);
			v_num_errors := v_num_errors + 1;
		ELSE
			dbms_output.put_line('___OK: apply lag is '||v_apply_lag);
		END IF;
	EXCEPTION WHEN OTHERS THEN
		dbms_output.put_line('ERROR: cannot determine apply lag.');
		v_num_errors := v_num_errors + 1;
	END;


	-- transport lag?
	v_transport_lag := numtodsinterval(dbms_drs.get_property_obj(r_dgconfig.object_id,'TransportLagThreshold'),'second');
	BEGIN
		SELECT TO_DSINTERVAL(value) into v_transport_lag FROM v$dataguard_stats WHERE name='transport lag';
		IF v_transport_lag > v_transport_th THEN
			dbms_output.put_line('ERROR: transport lag is '||v_transport_lag);
			v_num_errors := v_num_errors + 1;
		ELSE
			dbms_output.put_line('___OK: transport lag is '||v_transport_lag);
		END IF;
	EXCEPTION WHEN OTHERS THEN
		dbms_output.put_line('_WARN: cannot determine transport lag.');
		v_num_warnings := v_num_warnings + 1;
	END;
	

	<<stop_checks>>
	
	dbms_output.put_line('--------------------------------------');
	IF v_num_errors > 0 THEN
		dbms_output.put_line('RESULT: ERROR: '||to_char(v_num_errors)||' errors - '||to_char(v_num_warnings)||' warnings');
	ELSIF v_num_warnings > 0 THEN
		dbms_output.put_line('RESULT: _WARN: '||to_char(v_num_errors)||' errors - '||to_char(v_num_warnings)||' warnings');
	ELSE
		dbms_output.put_line('RESULT: ___OK: '||to_char(v_num_errors)||' errors - '||to_char(v_num_warnings)||' warnings');
	END IF;
END;
/
