/*
Keys:
-	For a scheduler job one can define the owner. The job will run below that schema
-	A scheduler job can run in the current session. This enables us to capture the dbms_output
--  db link db_link check
*/

BEGIN
   FOR f IN (SELECT     *
                 FROM   dba_db_links
                WHERE   owner not in ('PUBLIC') 
           )                                    
   LOOP                                        
      DBMS_SCHEDULER.create_job (              
         job_name     => f.owner || '.DBLINK', 
         job_type     => 'PLSQL_BLOCK',        
         job_action   =>    'DECLARE '
                         || '  X CHAR; '
                         || 'BEGIN '
                         || '  SELECT dummy into x from dual@'
                         || f.db_link
                         || '  ;'
                         || '  DBMS_OUTPUT.put_line('''
                         || f.owner
                         || ' '
                         || f.db_link
                         || ' VALID'');'
                         || 'END ; '
      );

      BEGIN
         DBMS_SCHEDULER.run_job (f.owner || '.DBLINK ', TRUE);
      EXCEPTION
         WHEN OTHERS THEN
            DBMS_OUTPUT.put_line (f.owner || ' ' || f.db_link || ' INVALID (ORA' || SQLCODE || ')');
      END;
      DBMS_SCHEDULER.drop_job (f.owner || ' . DBLINK ');
      
   END LOOP;
END;
/
