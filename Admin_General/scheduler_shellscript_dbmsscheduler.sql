-- This feature in available from oracle 12c onward

-- Create an credential store:

BEGIN
dbms_credential.create_credential (
CREDENTIAL_NAME => 'ORACLEOSUSER',
USERNAME => 'oracle',
PASSWORD => 'oracle@98765',
DATABASE_ROLE => NULL,
WINDOWS_DOMAIN => NULL,
COMMENTS => 'Oracle OS User',
ENABLED => true
);
END;
/

-- Create the job:

exec dbms_scheduler.create_job(-
job_name=>'myscript4',-
job_type=>'external_script',-
job_action=>'/export/home/oracle/ttest.2.sh',-
enabled=>true,-
START_DATE=>sysdate,-
REPEAT_INTERVAL =>'FREQ=MINUTELY; byminute=1',-
auto_drop=>false,-
credential_name=>'ORACLEOSUSER');
