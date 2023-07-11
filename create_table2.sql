DECLARE
sql_stmt long;

BEGIN
    sql_stmt:='
    CREATE TABLE Table2 (
        c1 number(6,0),
        c2 varchar2(10)
    )';
    EXECUTE IMMEDIATE sql_stmt;

    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -955 THEN
                NULL;
            ELSE
                RAISE;
            END IF;
END;
