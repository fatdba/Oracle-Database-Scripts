COLUMN name  FORMAT A60
COLUMN detected_usages FORMAT 999999999999

SELECT u1.name,
       u1.detected_usages,
       u1.currently_used,
       u1.version
FROM   dba_feature_usage_statistics u1
WHERE  u1.version = (SELECT MAX(u2.version)
                     FROM   dba_feature_usage_statistics u2
                     WHERE  u2.name = u1.name)
AND    u1.detected_usages > 0
AND    u1.dbid = (SELECT dbid FROM v$database)
ORDER BY name;




DBMS_FEATURE_USAGE_INTERNAL
By default the feature usage view is updated about once per week. You can force the view to be updated by using the DBMS_FEATURE_USAGE_INTERNAL package.

SQL> EXEC DBMS_FEATURE_USAGE_INTERNAL.exec_db_usage_sampling(SYSDATE);

PL/SQL procedure successfully completed.

SQL>
