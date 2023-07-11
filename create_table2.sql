DECLARE
tbl_count number;
sql_stmt long;


BEGIN
    SELECT COUNT(*) INTO tbl_count 
    FROM dba_tables
    WHERE owner = 'system'
    AND table_name = 'Table2';

    IF(tbl_count <= 0)
        THEN
        sql_stmt:='
        CREATE TABLE Table2 (
            c1 number(6,0),
            c2 varchar2(10)
        )';
        EXECUTE IMMEDIATE sql_stmt;
    END IF;
END;
