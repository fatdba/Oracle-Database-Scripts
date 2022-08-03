-- For testing purposes only
--
CREATE TABLE scale_write_0 AS
  WITH generator AS (
                     SELECT --+ materialize
                            level n
                       FROM DUAL
                    CONNECT BY level <= 10000
) 
 SELECT rownum id1
      , CEIL(DBMS_RANDOM.VALUE(1000000,9999999)) id2
      , CEIL(DBMS_RANDOM.VALUE(1000000,9999999)) id3
      , CEIL(DBMS_RANDOM.VALUE(1000000,9999999)) id4
      , CEIL(DBMS_RANDOM.VALUE(1000000,9999999)) id5
   FROM generator, generator
  WHERE rownum <= 10000000;

CREATE TABLE scale_write_1 AS
SELECT * from scale_write_0;

CREATE TABLE scale_write_2 AS
SELECT * from scale_write_0;

CREATE TABLE scale_write_3 AS
SELECT * from scale_write_0;

CREATE TABLE scale_write_4 AS
SELECT * from scale_write_0;

CREATE TABLE scale_write_5 AS
SELECT * from scale_write_0;

CREATE INDEX scale_write_1_1 on scale_write_1(id1);

CREATE INDEX scale_write_2_1 on scale_write_2(id1);
CREATE INDEX scale_write_2_2 on scale_write_2(id2, id1);

CREATE INDEX scale_write_3_1 on scale_write_3(id1);
CREATE INDEX scale_write_3_2 on scale_write_3(id2, id1);
CREATE INDEX scale_write_3_3 on scale_write_3(id3, id2, id1);

CREATE INDEX scale_write_4_1 on scale_write_4(id1);
CREATE INDEX scale_write_4_2 on scale_write_4(id2, id1);
CREATE INDEX scale_write_4_3 on scale_write_4(id3, id2, id1);
CREATE INDEX scale_write_4_4 on scale_write_4(id4, id3, id2
                                            , id1);

CREATE INDEX scale_write_5_1 on scale_write_5(id1);
CREATE INDEX scale_write_5_2 on scale_write_5(id2, id1);
CREATE INDEX scale_write_5_3 on scale_write_5(id3, id2, id1);
CREATE INDEX scale_write_5_4 on scale_write_5(id4, id3, id2
                                           , id1);
CREATE INDEX scale_write_5_5 on scale_write_5(id5, id4, id3
                                           , id2, id1);

begin
 DBMS_STATS.GATHER_TABLE_STATS(user
                             , 'SCALE_WRITE_0', cascade=>true);
 DBMS_STATS.GATHER_TABLE_STATS(user
                             , 'SCALE_WRITE_1', cascade=>true);
 DBMS_STATS.GATHER_TABLE_STATS(user
                             , 'SCALE_WRITE_2', cascade=>true);
 DBMS_STATS.GATHER_TABLE_STATS(user
                             , 'SCALE_WRITE_3', cascade=>true);
 DBMS_STATS.GATHER_TABLE_STATS(user
                             , 'SCALE_WRITE_4', cascade=>true);
 DBMS_STATS.GATHER_TABLE_STATS(user
                             , 'SCALE_WRITE_5', cascade=>true);
end;
/
create or replace
PACKAGE test_write_scalability IS
  TYPE piped_output IS
             RECORD ( idxes   NUMBER
                    , cmnd    VARCHAR2(255)
                    , seconds NUMBER
                    , id1     NUMBER);
  TYPE piped_output_table IS TABLE OF piped_output;

  FUNCTION run(n IN number)
    RETURN test_write_scalability.piped_output_table PIPELINED;
END;

create or replace
PACKAGE BODY test_write_scalability
IS
  TYPE tmp IS TABLE OF piped_output INDEX BY PLS_INTEGER;

FUNCTION run_insert(tbl IN NUMBER, d1 IN NUMBER)
                    RETURN VARCHAR2
AS
  r2 NUMBER := CEIL(DBMS_RANDOM.VALUE(1000000,9999999));
  r3 NUMBER := CEIL(DBMS_RANDOM.VALUE(1000000,9999999));
  r4 NUMBER := CEIL(DBMS_RANDOM.VALUE(1000000,9999999));
  r5 NUMBER := CEIL(DBMS_RANDOM.VALUE(1000000,9999999));
BEGIN
  CASE tbl
  WHEN 0 THEN 
         INSERT INTO scale_write_0 (id1, id2, id3, id4, id5)
                            VALUES ( d1,  r2,  r3,  r4,  r5);
  WHEN 1 THEN 
         INSERT INTO scale_write_1 (id1, id2, id3, id4, id5)
                            VALUES ( d1,  r2,  r3,  r4,  r5);
  WHEN 2 THEN 
         INSERT INTO scale_write_2 (id1, id2, id3, id4, id5)
                            VALUES ( d1,  r2,  r3,  r4,  r5);
  WHEN 3 THEN 
         INSERT INTO scale_write_3 (id1, id2, id3, id4, id5)
                            VALUES ( d1,  r2,  r3,  r4,  r5);
  WHEN 4 THEN 
         INSERT INTO scale_write_4 (id1, id2, id3, id4, id5)
                            VALUES ( d1,  r2,  r3,  r4,  r5);
  WHEN 5 THEN 
         INSERT INTO scale_write_5 (id1, id2, id3, id4, id5)
                            VALUES ( d1,  r2,  r3,  r4,  r5);
  END CASE;
  RETURN 'insert';
END;

FUNCTION run_delete(tbl IN NUMBER, d1 IN NUMBER)
RETURN VARCHAR2
AS
BEGIN
  CASE tbl
  WHEN 1 THEN 
         DELETE FROM scale_write_1 WHERE id1 = d1;
  WHEN 2 THEN 
         DELETE FROM scale_write_2 WHERE id1 = d1;
  WHEN 3 THEN 
         DELETE FROM scale_write_3 WHERE id1 = d1;
  WHEN 4 THEN 
         DELETE FROM scale_write_4 WHERE id1 = d1;
  WHEN 5 THEN 
         DELETE FROM scale_write_5 WHERE id1 = d1;
  ELSE NULL;
  END CASE;
  IF SQL%ROWCOUNT > 0 THEN RETURN 'delete';
  ELSE RETURN NULL; END IF;
END;

FUNCTION run_update_all(tbl IN NUMBER, d1 IN NUMBER)
RETURN VARCHAR2
AS 
  r2 NUMBER := CEIL(DBMS_RANDOM.VALUE(1000000,9999999));
  r3 NUMBER := CEIL(DBMS_RANDOM.VALUE(1000000,9999999));
  r4 NUMBER := CEIL(DBMS_RANDOM.VALUE(1000000,9999999));
  r5 NUMBER := CEIL(DBMS_RANDOM.VALUE(1000000,9999999));
BEGIN
  CASE tbl
  WHEN 1 THEN 
         UPDATE scale_write_1
            SET id2 = r2, id3=r3, id4=r4, id5=r5 WHERE id1=d1;
  WHEN 2 THEN 
         UPDATE scale_write_2
            SET id2 = r2, id3=r3, id4=r4, id5=r5 WHERE id1=d1;
  WHEN 3 THEN 
         UPDATE scale_write_3
            SET id2 = r2, id3=r3, id4=r4, id5=r5 WHERE id1=d1;
  WHEN 4 THEN 
         UPDATE scale_write_4
            SET id2 = r2, id3=r3, id4=r4, id5=r5 WHERE id1=d1;
  WHEN 5 THEN 
         UPDATE scale_write_5
            SET id2 = r2, id3=r3, id4=r4, id5=r5 WHERE id1=d1;
  ELSE NULL;
  END CASE; 
  IF SQL%ROWCOUNT > 0 THEN RETURN 'update all';
  ELSE RETURN NULL; END IF;
END;

FUNCTION run_update_one(tbl IN NUMBER, d1 IN NUMBER)
RETURN VARCHAR2
AS
  r NUMBER := CEIL(DBMS_RANDOM.VALUE(1000000,9999999));
BEGIN
  CASE tbl
  WHEN 1 THEN -- no index updated
         UPDATE scale_write_1 SET id2 = r WHERE id1=d1;
  WHEN 2 THEN -- one index updated
         UPDATE scale_write_2 SET id2 = r WHERE id1=d1;
  WHEN 3 THEN -- one index updated
         UPDATE scale_write_3 SET id3 = r WHERE id1=d1;
  WHEN 4 THEN -- one index updated
         UPDATE scale_write_4 SET id4 = r WHERE id1=d1;
  WHEN 5 THEN -- one index updated
         UPDATE scale_write_5 SET id5 = r WHERE id1=d1;
  ELSE NULL;
  END CASE; 
  IF SQL%ROWCOUNT > 0 THEN RETURN 'update one';
  ELSE RETURN NULL; END IF;
END;

FUNCTION run(n IN NUMBER)
  RETURN test_write_scalability.piped_output_table PIPELINED
IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  rec  test_write_scalability.piped_output;

  id1  NUMBER;
  tbl  NUMBER;
  strt TIMESTAMP(9);
  cmnd NUMBER;
  d1   NUMBER;
  q    NUMBER;
  begn NUMBER;
  iter NUMBER;
  r    NUMBER;
  tmp  DATE;

BEGIN
  SELECT CEIL((max(id1)-min(id1))/4) into q FROM scale_write_1;

  iter := n;
  WHILE iter > 0 LOOP
    FOR cmd IN 0 .. 3 LOOP
      r := TRUNC(DBMS_RANDOM.VALUE(0, q));
      FOR tbl IN 0 .. 5 LOOP
        strt := systimestamp;
        rec.cmnd := 
        CASE cmd
        WHEN 0 THEN run_update_all(tbl, r + cmd*q)
        WHEN 1 THEN run_insert    (tbl, r + cmd*q)
        WHEN 2 THEN run_update_one(tbl, r + cmd*q)
        WHEN 3 THEN run_delete    (tbl, r + cmd*q)
        END;
        IF rec.cmnd IS NOT NULL THEN
          COMMIT;
          -- magic: convert INTERVAL DAYS TO SECONDS
          -- to NUMERIC (seconds)
          tmp := sysdate;
          rec.seconds := tmp 
                       + (systimestamp - strt)*86400
                       - tmp;         
          rec.idxes   := tbl;
          rec.id1     := r + cmd*q;
          PIPE ROW(rec);
        END IF;
      END LOOP;
    END LOOP;
    iter := iter - 1;
  END LOOP;
  COMMIT;
  RETURN;
END run;
END test_write_scalability;
SELECT *
  FROM (SELECT idxes, cmnd, seconds
          FROM TABLE (test_write_scalability.run(1000)
       )
 PIVOT (AVG(seconds)
   FOR cmnd
    IN ('insert', 'delete', 'update all', 'update one')
       );
