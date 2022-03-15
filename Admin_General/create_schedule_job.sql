-- TO schedule a job, first create a schedule, then a program and then a job
--Create a schedule

BEGIN
DBMS_SCHEDULER.CREATE_SCHEDULE (
Schedule_name => 'DAILYBILLINGJOB',
Start_date => SYSTIMESTAMP,
Repeat_interval =>'FREQ=DAILY;BYHOUR=11; BYMINUTE=30',
Comments => 'DAILY BILLING JOB'
);
END;

-- Create a program

BEGIN
DBMS_SCHEDULER.CREATE_PROGRAM (
program_name => 'DAILYBILLINGJOB',
program_type => 'STORED_PROCEDURE',
program_action => 'DAILYJOB.BILLINGPROC'
number_of_arguments =>0,
enabled => TRUE,
comments => 'DAILY BILLING JOB'
);
END;

-- Now create the job:

 

BEGIN DBMS_SCHEDULER.CREATE_JOB (
job_name => 'DAILYBILLINGJOB_RUN',
program_name => 'DAILYBILLINGJOB',
schedule_name => 'DAILYBILLINGJOB_SCHED',
enabled => FLASE,
comments => 'daily billing job'
);
END;

-- ENABLE THE JOB

EXECUTE DBMS_SCHEDULER.ENABLE('DAILYBILLINGJOB_RUN');
