-- This is Oracle provided script
-- - - - - - - - - - - - - - Script begins here - - - - - - - - - - - - - - 
--  NAME:  DBUPGDIAG.SQL  
--  Version: 1.2
--  Executed as SYS as sysdba
-- ------------------------------------------------------------------------ 
-- AUTHOR:  
--    Raja Ganesh and Agrim Pandit - Oracle Support Services - DataServer Group
--    Copyright 2008, Oracle Corporation      
-- ------------------------------------------------------------------------ 
-- PURPOSE: 
-- This script is intended to provide a user friendly output to diagonise 
-- the status of the database before (or) after upgrade. The script will 
-- create a file called db_upg_diag_<sid>_<timestamp>.log in your local 
-- working directory. This does not make any DDL / DML modifications.
-- 
-- This script will work in both Windows and Unix platforms from database 
-- version 9.2 or higher.
-- ------------------------------------------------------------------------ 
-- DISCLAIMER: 
--    This script is provided for educational purposes only. It is NOT  
--    supported by Oracle World Wide Technical Support. 
--    The script has been tested and appears to work as intended. 
--    You should always run new scripts on a test instance initially. 
-- ------------------------------------------------------------------------ 
--
-- 
col TODAY	NEW_VALUE	_DATE	
col VERSION NEW_VALUE _VERSION
set termout off
select to_char(SYSDATE,'fmMonth DD, YYYY') TODAY from DUAL;
select version from v$instance;
set termout on
set echo off
set feedback off
set head off
set verify off
Prompt
PROMPT Enter location for Spooled output:
Prompt
DEFINE log_path = &1
column timecol new_value timestamp
column spool_extension new_value suffix
SELECT to_char(sysdate,'dd_Mon_yyyy_hhmi') timecol,'.log' spool_extension FROM 
sys.dual;
column output new_value dbname
SELECT value || '_' output FROM v$parameter WHERE name = 'db_name';
spool &log_path/db_upg_diag_&&dbname&&timestamp&&suffix
set linesize 150
set pages 100
set trim on
set trims on
col Compatible for a35
col comp_id for a12
col comp_name for a40
col org_version for a11
col prv_version for a11
col owner for a12
col object_name for a40
col object_type for a40
col Wordsize for a25
col Metadata for a8
col 'Initial DB Creation Info' for a35
col 'Total Invalid JAVA objects' for a45
col 'Role' for a30
col 'User Existence' for a27
col "JAVAVM TESTING" for a15
Prompt
Prompt
set feedback off head off
select LPAD('*** Start of LogFile ***',50) from dual;
select LPAD('Oracle Database Upgrade Diagnostic Utility',44)||
       LPAD(TO_CHAR(SYSDATE, 'MM-DD-YYYY HH24:MI:SS'),26) from dual;
Prompt
Prompt ===============
Prompt Hostname
Prompt ===============
select host_name from v$instance;
Prompt
Prompt ===============
Prompt Database Name
Prompt ===============
select name from v$database;
Prompt
Prompt ===============
Prompt Database Uptime
Prompt ===============
SELECT to_char(startup_time, 'HH24:MI DD-MON-YY') "Startup Time" 
FROM v$instance;
Prompt
Prompt =================
Prompt Database Wordsize
Prompt =================
SELECT distinct('This is a ' || (length(addr)*4) || '-bit database') "WordSize" 
FROM v$process;
Prompt
Prompt ================
Prompt Software Version
Prompt ================
SELECT * FROM v$version;
Prompt
Prompt =============
Prompt Compatibility
Prompt =============
SELECT 'Compatibility is set as '||value Compatible 
FROM v$parameter WHERE name ='compatible';
Prompt
Prompt ================
Prompt Archive Log Mode
Prompt ================
Prompt
archive log list
Prompt
Prompt ================
Prompt Auditing Check
Prompt ================
Prompt
set head on
show parameter audit
Prompt
Prompt ================
Prompt Cluster Check
Prompt ================
show parameter cluster_database
Prompt
DOC
################################################################

 If CLUSTER_DATABASE is set to TRUE, change it to FALSE before
 upgrading the database 

################################################################
#
Prompt
Prompt ===========================================
Prompt Tablespace and the owner of the aud$ table  ( IF Oracle Label Security and Oracle Database Vault are installed then aud$ will be in SYSTEM.AUD$)
Prompt ===========================================
select owner,tablespace_name from dba_extents where segment_name='AUD$' group by owner,tablespace_name;
Prompt
Prompt ============================================================================
Prompt count of records in the sys.aud$ table where dbid is null- Standard Auditing
Prompt ============================================================================
Prompt
set head off
select count(*) as Records  from sys.aud$ where dbid is null;
Prompt
Prompt
Prompt ============================================================================================
Prompt count of records in the system.aud$ when dbid is null, Std Auditing with OLS or DV installed
Prompt ============================================================================================
set head off
select count(*) from system.aud$ where dbid is null;
Prompt
Prompt
Prompt =============================================================================
Prompt count of records in the sys.fga_log$ when dbid is null, Fine Grained Auditing
Prompt =============================================================================
set head off
select count(*) from sys.fga_log$ where dbid is null;
Prompt
Prompt
prompt
Prompt ==========================================
Prompt Oracle Label Security is installed or not 
Prompt ==========================================
set head off
SELECT case count(schema)
WHEN 0 THEN 'Oracle Label Security is NOT installed at database level'
ELSE 'Oracle Label Security is installed '
END  "Oracle Label Security Check"
FROM dba_registry
WHERE schema='LBACSYS';
Prompt
Prompt ================
Prompt Number of AQ Records in Message Queue Tables
Prompt ================
Prompt
SET SERVEROUTPUT ON SIZE 100000
declare
   V_COUNT NUMBER;
     cursor c1 is
         select owner,queue_table from dba_queue_tables where owner in ('SYS', 'SYSTEM', 'SYSMAN', 'DBSNMP','WMSYS');
 begin
    for c in c1
     loop
        execute immediate 'select count(1) from ' || c.owner || '.'  || c.queue_table into v_count;
        dbms_output.put_line(c.owner || ' - ' || c.queue_table  || ' - ' || v_count);
     end loop;
 END;
/
Prompt
Prompt ================
Prompt Time Zone version 
Prompt ================
Prompt
SELECT version from v$timezone_file;
Prompt
Prompt ================
Prompt Local Listener
Prompt ================
Prompt
select substr(value,1,50) "Local Listener" from v$parameter where name='local_listener';
Prompt
Prompt ================
Prompt Default and Temporary Tablespaces By User
Prompt ================
Prompt
set head on
COLUMN USERNAME FORMAT A28
COLUMN TEMPORARY_TABLESPACE FORMAT A22
COLUMN DEFAULT_TABLESPACE FORMAT A22
SELECT username, temporary_tablespace,default_tablespace FROM DBA_USERS;
Prompt
Prompt
Prompt ================
Prompt Component Status
Prompt ================
Prompt
SET SERVEROUTPUT ON;
DECLARE

ORG_VERSION varchar2(12);
PRV_VERSION varchar2(12);
P_VERSION VARCHAR2(10);

BEGIN 

SELECT version INTO p_version 
FROM registry$ WHERE cid='CATPROC' ;

IF SUBSTR(p_version,1,5) = '9.2.0' THEN

DBMS_OUTPUT.PUT_LINE(RPAD('Comp ID', 8) ||RPAD('Component',35)|| 
   RPAD('Status',10) ||RPAD('Version', 15));

DBMS_OUTPUT.PUT_LINE(RPAD(' ',8,'-') ||RPAD(' ',35,'-')|| 
   RPAD(' ',10,'-') ||RPAD(' ',15,'-'));

FOR x in (SELECT SUBSTR(dr.comp_id,1,8) comp_id,
 SUBSTR(dr.comp_name,1,35) comp_name, 
 dr.status Status,SUBSTR(dr.version,1,15) version
 FROM dba_registry dr,registry$ r
 WHERE dr.comp_id=r.cid and dr.comp_name=r.cname
 ORDER BY 1)

LOOP

DBMS_OUTPUT.PUT_LINE(RPAD(SUBSTR(x.comp_id,1,8),8) || 
   RPAD(SUBSTR(x.comp_name,1,35),35)||
   RPAD(x.status,10) || RPAD(x.version, 15));
END LOOP;

ELSIF SUBSTR(p_version,1,5) != '9.2.0' THEN

DBMS_OUTPUT.PUT_LINE(RPAD('Comp ID', 8) ||RPAD('Component',35)||  
   RPAD('Status',10) ||RPAD('Version', 15)||
   RPAD('Org_Version',15)||RPAD('Prv_Version',15));

DBMS_OUTPUT.PUT_LINE(RPAD(' ',8,'-') ||RPAD(' ',35,'-')|| 
   RPAD(' ',10,'-')||RPAD(' ',15,'-')||RPAD(' ',15,'-')||
   RPAD(' ',15,'-'));

FOR y in (SELECT SUBSTR(dr.comp_id,1,8) comp_id,
 SUBSTR(dr.comp_name,1,35) comp_name, dr.status Status, 
 SUBSTR(dr.version,1,11) version,org_version,prv_version
 FROM dba_registry dr,registry$ r
 WHERE dr.comp_id=r.cid and dr.comp_name=r.cname
 ORDER BY 1)

LOOP

DBMS_OUTPUT.PUT_LINE(RPAD(substr(y.comp_id,1,8), 8) || 
    RPAD(substr(y.comp_name,1,35),35)||RPAD(y.status,10) ||
    RPAD(y.version, 15)||RPAD(y.org_version,15)||RPAD(y.prv_version,15));

END LOOP;

END IF;
END;
/
SET SERVEROUTPUT OFF
Prompt
Prompt
Prompt
Prompt ======================================================
Prompt List of Invalid Database Objects Owned by SYS / SYSTEM
Prompt ======================================================
Prompt
set head on
SELECT case count(object_name)
WHEN 0 THEN 'There are no Invalid Objects'
ELSE 'There are '||count(object_name)||' Invalid objects'
END "Number of Invalid Objects"
FROM dba_objects 
WHERE status='INVALID'
AND owner in ('SYS','SYSTEM');
Prompt
DOC 
################################################################

 If there are no Invalid objects below will result in zero rows.

################################################################
#
Prompt
set feedback on
SELECT owner,object_name,object_type 
FROM dba_objects 
WHERE status='INVALID' 
AND owner in ('SYS','SYSTEM')
ORDER BY owner,object_type;
set feedback off
Prompt
Prompt ================================
Prompt List of Invalid Database Objects
Prompt ================================
Prompt
set head on
SELECT case count(object_name)
WHEN 0 THEN 'There are no Invalid Objects'
ELSE 'There are '||count(object_name)||' Invalid objects'
END "Number of Invalid Objects"
FROM dba_objects 
WHERE status='INVALID'
AND owner  in 
('SYSMAN','CTXSYS','ORDSYS','MDSYS','EXFSYS','WKSYS','WKPROXY','WK_TEST','OLAPSYS','OUTLIN','TSMSYS',
'FLOWS_FILES','SI_INFORMTN_SCHEMA','ORACLE_OCM','ORDPLUGINS','ORDDATA','DBSNMP');
Prompt
DOC
################################################################

 If there are no Invalid objects below will result in zero rows.

################################################################
#
Prompt
set feedback on
SELECT owner,object_name,object_type 
FROM dba_objects 
WHERE status='INVALID' 
AND owner in ('SYSMAN','CTXSYS','ORDSYS','MDSYS','EXFSYS','WKSYS','WKPROXY','WK_TEST','OLAPSYS','OUTLIN','TSMSYS',
'FLOWS_FILES','SI_INFORMTN_SCHEMA','ORACLE_OCM','ORDPLUGINS','ORDDATA','DBSNMP')
ORDER BY owner,object_type;
set feedback off
Prompt
Prompt ======================================================
Prompt Count of Invalids by Schema
Prompt ======================================================
Prompt
select owner,object_type,count(*) from dba_objects where status='INVALID'
group by owner,object_type order by owner,object_type ;
Prompt ==============================================================
Prompt Identifying whether a database was created as 32-bit or 64-bit
Prompt ==============================================================
Prompt
DOC 
###########################################################################

 Result referencing the string 'B023' ==> Database was created as 32-bit
 Result referencing the string 'B047' ==> Database was created as 64-bit
 When String results in 'B023' and when upgrading database to 10.2.0.3.0 
 (64-bit) , For known issue refer below articles
  
 Note 412271.1 ORA-600 [22635] and ORA-600 [KOKEIIX1] Reported While 
               Upgrading Or Patching Databases To 10.2.0.3
 Note 579523.1 ORA-600 [22635], ORA-600 [KOKEIIX1], ORA-7445 [KOPESIZ] and 
              OCI-21500 [KOXSIHREAD1] Reported While Upgrading To 11.1.0.6

###########################################################################
#
Prompt
SELECT SUBSTR(metadata,109,4) "Metadata",
CASE SUBSTR(metadata,109,4)
WHEN 'B023' THEN 'Database was created as 32-bit'
WHEN 'B047' THEN 'Database was created as 64-bit'
ELSE 'Metadata not Matching'
END "Initial DB Creation Info"
FROM sys.kopm$;
Prompt
Prompt ===================================================
Prompt Number of Duplicate Objects Owned by SYS and SYSTEM
Prompt ===================================================
Prompt
Prompt Counting duplicate objects ....
Prompt
SELECT count(1) 
FROM dba_objects 
WHERE object_name||object_type in 
   (SELECT object_name||object_type  
    from dba_objects 
    where owner = 'SYS')
AND owner = 'SYSTEM'
AND object_name NOT in ('AQ$_SCHEDULES','AQ$_SCHEDULES_PRIMARY','DBMS_REPCAT_AUTH','DBMS_REPCAT_AUTH') ;
Prompt
Prompt =========================================
Prompt Duplicate Objects Owned by SYS and SYSTEM
Prompt =========================================
Prompt
Prompt Querying duplicate objects ....
Prompt
SELECT object_name, object_type, subobject_name, object_id 
FROM dba_objects 
WHERE object_name||object_type in 
   (SELECT object_name||object_type  
    FROM dba_objects 
    WHERE owner = 'SYS')
AND owner = 'SYSTEM'
AND object_name NOT in ('AQ$_SCHEDULES','AQ$_SCHEDULES_PRIMARY','DBMS_REPCAT_AUTH','DBMS_REPCAT_AUTH') ; 
Prompt
DOC

################################################################################
Below are expected and required duplicates objects and OMITTED in the report .

Without replication installed:
INDEX           AQ$_SCHEDULES_PRIMARY
TABLE           AQ$_SCHEDULES

If replication is installed by running catrep.sql:
INDEX           AQ$_SCHEDULES_PRIMARY
PACKAGE         DBMS_REPCAT_AUTH
PACKAGE BODY    DBMS_REPCAT_AUTH
TABLE           AQ$_SCHEDULES

If any objects found please follow below article.
Note 1030426.6 How to Clean Up Duplicate Objects Owned by SYS and SYSTEM schema
Read the Exceptions carefully before taking actions.

################################################################################
#
Prompt
Prompt ========================
Prompt Password protected roles
Prompt ========================
Prompt
DOC

################################################################################

 In version 11.2 password protected roles are no longer enabled by default so if 
 an application relies on such roles being enabled by default and no action is
 performed to allow the user to enter the password with the set role command, it 
 is recommended to remove the password from those roles (to allow for existing 
 privileges to remain available). For more information see:

 Note 745407.1 : What Roles Can Be Set as Default for a User?

################################################################################
#
Prompt
Prompt Querying for password protected roles ....
Prompt
break on "Password protected Role"
select r.ROLE "Password protected Role",
p.grantee "Assigned by default to user"
from dba_roles r, dba_role_privs p
where r.PASSWORD_REQUIRED = 'YES' and p.GRANTED_ROLE = r.role
and p.default_role = 'YES'
and p.grantee <> 'SYS' and r.role not in
(select role from dba_application_roles);

Prompt
Prompt ================
Prompt JVM Verification
Prompt ================
Prompt
SET SERVEROUTPUT ON
DECLARE

V_CT NUMBER;
P_VERSION VARCHAR2(10);

BEGIN

-- If so, get the version of the JAVAM component
EXECUTE IMMEDIATE 'SELECT version FROM registry$ WHERE cid=''JAVAVM'' 
		   AND status <> 99' INTO p_version;

SELECT count(*) INTO v_ct FROM dba_objects
WHERE object_type LIKE '%JAVA%' AND owner='SYS';

IF SUBSTR(p_version,1,5) = '8.1.7' THEN
	IF v_ct>=6787 THEN
	DBMS_OUTPUT.PUT_LINE('JAVAVM - Installed properly');
	ELSE
	DBMS_OUTPUT.PUT_LINE('JAVAVM - Not Installed properly');
	END IF;
ELSIF SUBSTR(p_version,1,5) = '9.0.1' THEN
	IF v_ct>=8585 THEN
	DBMS_OUTPUT.PUT_LINE('JAVAVM - Installed properly');
	ELSE
	DBMS_OUTPUT.PUT_LINE('JAVAVM - Not Installed properly');
	END IF;
ELSIF SUBSTR(p_version,1,5) = '9.2.0' THEN
	IF v_ct>=8585 THEN
	DBMS_OUTPUT.PUT_LINE('JAVAVM - Installed properly');
	ELSE
	DBMS_OUTPUT.PUT_LINE('JAVAVM - Not Installed properly');
	END IF;
ELSIF SUBSTR(p_version,1,6) = '10.1.0' THEN
	IF v_ct>=13866 THEN
	DBMS_OUTPUT.PUT_LINE('JAVAVM - Installed properly');
	ELSE
	DBMS_OUTPUT.PUT_LINE('JAVAVM - Not Installed properly');
	END IF;
ELSIF SUBSTR(p_version,1,6) = '10.2.0' THEN
	IF v_ct>=14113 THEN
	DBMS_OUTPUT.PUT_LINE('JAVAVM - Installed properly');
	ELSE
	DBMS_OUTPUT.PUT_LINE('JAVAVM - Not Installed properly');
	END IF;
END IF;

EXCEPTION WHEN NO_DATA_FOUND THEN
	DBMS_OUTPUT.PUT_LINE('JAVAVM - NOT Installed. Below results can be ignored');

END;
/
SET SERVEROUTPUT OFF
Prompt
Prompt ================================================
Prompt Checking Existence of Java-Based Users and Roles
Prompt ================================================
Prompt
DOC

################################################################################

 There should not be any Java Based users for database version 9.0.1 and above.
 If any users found, it is faulty JVM.

################################################################################
#

Prompt
SELECT CASE count(username)
WHEN 0 THEN 'No Java Based Users'
ELSE 'There are '||count(*)||' JAVA based users'
END "User Existence"
FROM dba_users WHERE username LIKE '%AURORA%' AND username LIKE '%OSE%';
Prompt
DOC

###############################################################

 Healthy JVM Should contain Six Roles. For 12.2 Seven Roles 
 If there are more or less than six role, JVM is inconsistent.

###############################################################
#

Prompt
SELECT CASE count(role)
WHEN 0 THEN 'No JAVA related Roles'
ELSE 'There are '||count(role)||' JAVA related roles'
END "Role"
FROM dba_roles 
WHERE role LIKE '%JAVA%';
Prompt
Prompt Roles
Prompt
SELECT role FROM dba_roles WHERE role LIKE '%JAVA%';
set head off
Prompt
Prompt =========================================
Prompt List of Invalid Java Objects owned by SYS
Prompt =========================================
SELECT CASE count(*) 
       WHEN 0 THEN 'There are no SYS owned invalid JAVA objects'
       ELSE 'There are '||count(*)||' SYS owned invalid JAVA objects'
       END "Total Invalid JAVA objects"
FROM dba_objects 
WHERE object_type LIKE '%JAVA%' 
AND status='INVALID' 
AND owner='SYS';
Prompt
DOC

#################################################################

 Check the status of the main JVM interface packages DBMS_JAVA 
 and INITJVMAUX and make sure it is VALID.

 If there are no Invalid objects below will result in zero rows.

#################################################################
#
Prompt
set feedback on
SELECT owner,object_name,object_type
FROM dba_objects 
WHERE object_type LIKE '%JAVA%' 
AND status='INVALID' 
AND owner='SYS';
set feedback off
Prompt
DOC

#################################################################

 If the JAVAVM component is not installed in the database (for 
 example, after creating the database with custom scripts), the 
 next query will report the following error:

   select dbms_java.longname('foo') "JAVAVM TESTING" from dual
   *
   ERROR at line 1:
   ORA-00904: "DBMS_JAVA"."LONGNAME": invalid identifier

 If the JAVAVM component is installed, the query should succeed 
 with 'foo' as result.

#################################################################
#
Prompt
set heading on
select dbms_java.longname('foo') "JAVAVM TESTING" from dual;
set heading off
Prompt 
SET FEEDBACK ON HEAD ON serveroutput on
Prompt ===================================
Prompt Oracle Multimedia/InterMedia status
Prompt ===================================
Prompt

DECLARE
   v_count            NUMBER;
   v_version          varchar2(200);
   v_user_count       number;
   v_status           VARCHAR2(200);
   v_xdb_installed    NUMBER;
   v_xdk_installed    NUMBER;
   v_javavm_installed NUMBER;
   TYPE string_tt IS TABLE OF VARCHAR2 (100)
      INDEX BY BINARY_INTEGER;
   v_user             string_tt;

 BEGIN

 v_count            := 0;
 v_version          := '';
 v_user_count       := 0;
 v_status           := '';
 v_xdb_installed    := 0;
 v_xdk_installed    := 0;
 v_javavm_installed := 0;

 SELECT 1,version,status
 INTO   v_count, v_version, v_status
 FROM dba_registry
 WHERE comp_id='ORDIM';
 
                                                       
 IF v_count > 0 then
  DBMS_OUTPUT.PUT_LINE ('.');
  DBMS_OUTPUT.PUT_LINE ('Oracle Multimedia/interMedia is installed and listed with the following version: '||v_version||' and status: '||v_status);
  DBMS_OUTPUT.PUT_LINE ('.');

/* check if all users are installed.*/

 v_user(1) := 'ORDSYS';
 v_user(2) := 'ORDPLUGINS';
 v_user(3) := 'MDSYS';
 v_user(4) := 'SI_INFORMTN_SCHEMA';
 v_user(5) := 'ORDDATA';

 DBMS_OUTPUT.PUT_LINE('Checking for installed Database Schemas...');

   FOR i IN v_user.first .. v_user.last LOOP
   SELECT COUNT(username)
   INTO   v_user_count
   FROM   dba_users 
   WHERE  username = v_user(I);

/* ORDDATA user only exists starting 11.2 so no test if v_version is different */

   IF v_user(i) = 'ORDDATA' AND SUBSTR(V_VERSION,1,6) NOT IN ('11.2.0','12.1.0') THEN v_user_count :=2; 
   END IF;

/* SI_INFORMTN_SCHEMA user only exists starting 11.2 so no test if v_version is different */

   IF v_user(i) = 'SI_INFORMTN_SCHEMA' AND SUBSTR(V_VERSION,1,2) NOT IN ('10','11','12') THEN v_user_count :=2; 
   END IF; 

   CASE v_user_count
   WHEN 0 THEN  DBMS_OUTPUT.PUT_LINE (v_user(I)||' user does not exist.');
   WHEN 2 THEN NULL; -- user does not exist in that version
   ELSE DBMS_OUTPUT.PUT_LINE (v_user(I)||' user exists.');
   END CASE;
   END LOOP;

 DBMS_OUTPUT.PUT_LINE('.');

/* Prerequisites Check*/
       DBMS_OUTPUT.PUT_LINE ('Checking for Prerequisite Components...');
       
/* for versions >= 10.2 we will verify, if XDB and XDK are installed and valid */

 SELECT COUNT(1) 
 INTO   v_javavm_installed
 FROM   dba_registry
 WHERE  comp_id='JAVAVM';

 IF v_javavm_installed <> 1 THEN DBMS_OUTPUT.PUT_LINE ('JAVAVM is not installed or not valid'); 
 ELSE
      DBMS_OUTPUT.PUT_LINE('JAVAVM installed and listed as valid');
 END IF;
  
  IF  SUBSTR(V_VERSION,1,2) IN ('11','12') OR 
      SUBSTR(V_VERSION,1,6) = ('10.2.0')      THEN
             
      SELECT COUNT(1) 
      INTO   v_xdk_installed
      FROM   dba_registry
      WHERE  comp_id='XML';

      IF v_xdk_installed <> 1 THEN DBMS_OUTPUT.PUT_LINE ('XDK is not installed or not valid');
      ELSE
        DBMS_OUTPUT.PUT_LINE('XDK installed and listed as valid'); 
      END IF;
                   
      SELECT COUNT(1) 
      INTO   v_xdb_installed
      FROM   dba_registry
      WHERE  comp_id='XDB';
             
      IF v_xdb_installed <> 1 THEN DBMS_OUTPUT.PUT_LINE ('XDB is not installed or not valid');
      ELSE
        DBMS_OUTPUT.PUT_LINE ('XDB installed and listed as valid'); 
      END IF;

  END IF;               
                       
 /* for versions >= 11 we run validate_ordim */

    DBMS_OUTPUT.PUT_LINE ('Validating Oracle Multimedia/interMedia...(no output if component status is valid)'); 

    IF SUBSTR(V_VERSION,1,2) IN ('11','12') THEN
         EXECUTE IMMEDIATE 'begin validate_ordim; end;';
    ELSIF SUBSTR(V_VERSION,1,2) IN ('8.','9.','10') AND  v_status <> 'VALID' THEN
         DBMS_OUTPUT.PUT_LINE('Please run $ORACLE_HOME/ord/im/admin/imchk.sql to display details about invalid interMedia installation');
    END IF;
    
 END IF;

 EXCEPTION
   WHEN NO_DATA_FOUND THEN 
   DBMS_OUTPUT.PUT_LINE ('Oracle Multimedia/interMedia is NOT installed at database level');
 END;
/

set feedback off head off
select LPAD('*** End of LogFile ***',50) from dual;
set feedback on head on
Prompt
spool off
Prompt
set heading off
set heading off
set feedback off
select 'Upload db_upg_diag_&&dbname&&timestamp&&suffix from "&log_path" directory' 
from dual;
set heading on
set feedback on
Prompt
-- - - - - - - - - - - - - - - - Script ends here - - - - - - - - - - - - - - 

