SET SERVEROUTPUT ON
-- Not wrriten by me but its a good script to check details on UNDO tablespace usage and recommendations
SET LINES 600
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY HH24:MI:SS';

DECLARE
    v_analyse_start_time    DATE := SYSDATE - 7;
    v_analyse_end_time      DATE := SYSDATE;
    v_cur_dt                DATE;
    v_undo_info_ret         BOOLEAN;
    v_cur_undo_mb           NUMBER;
    v_undo_tbs_name         VARCHAR2(100);
    v_undo_tbs_size         NUMBER;
    v_undo_autoext          BOOLEAN;
    v_undo_retention        NUMBER(5);
    v_undo_guarantee        BOOLEAN;
    v_instance_number       NUMBER;
    v_undo_advisor_advice   VARCHAR2(100);
    v_undo_health_ret       NUMBER;
    v_problem               VARCHAR2(1000);
    v_recommendation        VARCHAR2(1000);
    v_rationale             VARCHAR2(1000);
    v_retention             NUMBER;
    v_utbsize               NUMBER;
    v_best_retention        NUMBER;
    v_longest_query         NUMBER;
    v_required_retention    NUMBER;
BEGIN
    select sysdate into v_cur_dt from dual;
    DBMS_OUTPUT.PUT_LINE(CHR(9));
    DBMS_OUTPUT.PUT_LINE('- Undo Analysis started at : ' || v_cur_dt || ' -');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');

    v_undo_info_ret := DBMS_UNDO_ADV.UNDO_INFO(v_undo_tbs_name, v_undo_tbs_size, v_undo_autoext, v_undo_retention, v_undo_guarantee);
    select sum(bytes)/1024/1024 into v_cur_undo_mb from dba_data_files where tablespace_name = v_undo_tbs_name;

    DBMS_OUTPUT.PUT_LINE('NOTE:The following analysis is based upon the database workload during the period -');
    DBMS_OUTPUT.PUT_LINE('Begin Time : ' || v_analyse_start_time);
    DBMS_OUTPUT.PUT_LINE('End Time   : ' || v_analyse_end_time);
    
    DBMS_OUTPUT.PUT_LINE(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Current Undo Configuration');
    DBMS_OUTPUT.PUT_LINE('--------------------------');
    DBMS_OUTPUT.PUT_LINE(RPAD('Current undo tablespace',55) || ' : ' || v_undo_tbs_name);
    DBMS_OUTPUT.PUT_LINE(RPAD('Current undo tablespace size (datafile size now) ',55) || ' : ' || v_cur_undo_mb || 'M');
    DBMS_OUTPUT.PUT_LINE(RPAD('Current undo tablespace size (consider autoextend) ',55) || ' : ' || v_undo_tbs_size || 'M');
    IF V_UNDO_AUTOEXT THEN
        DBMS_OUTPUT.PUT_LINE(RPAD('AUTOEXTEND for undo tablespace is',55) || ' : ON');  
    ELSE
        DBMS_OUTPUT.PUT_LINE(RPAD('AUTOEXTEND for undo tablespace is',55) || ' : OFF');  
    END IF;
    DBMS_OUTPUT.PUT_LINE(RPAD('Current undo retention',55) || ' : ' || v_undo_retention);

    IF v_undo_guarantee THEN
        DBMS_OUTPUT.PUT_LINE(RPAD('UNDO GUARANTEE is set to',55) || ' : TRUE');
    ELSE
        dbms_output.put_line(RPAD('UNDO GUARANTEE is set to',55) || ' : FALSE');
    END IF;
    DBMS_OUTPUT.PUT_LINE(CHR(9));

    SELECT instance_number INTO v_instance_number FROM V$INSTANCE;

    DBMS_OUTPUT.PUT_LINE('Undo Advisor Summary');
    DBMS_OUTPUT.PUT_LINE('---------------------------');

    v_undo_advisor_advice := dbms_undo_adv.undo_advisor(v_analyse_start_time, v_analyse_end_time, v_instance_number);
    DBMS_OUTPUT.PUT_LINE(v_undo_advisor_advice);

    DBMS_OUTPUT.PUT_LINE(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Undo Space Recommendation');
    DBMS_OUTPUT.PUT_LINE('-------------------------');

    v_undo_health_ret := dbms_undo_adv.undo_health(v_analyse_start_time, v_analyse_end_time, v_problem, v_recommendation, v_rationale, v_retention, v_utbsize);
    IF v_undo_health_ret > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Minimum Recommendation           : ' || v_recommendation);
        DBMS_OUTPUT.PUT_LINE('Rationale                        : ' || v_rationale);
        DBMS_OUTPUT.PUT_LINE('Recommended Undo Tablespace Size : ' || v_utbsize || 'M');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Allocated undo space is sufficient for the current workload.');
    END IF;
    
    SELECT dbms_undo_adv.best_possible_retention(v_analyse_start_time, v_analyse_end_time) into v_best_retention FROM dual;
    SELECT dbms_undo_adv.longest_query(v_analyse_start_time, v_analyse_end_time) into v_longest_query FROM dual;
    SELECT dbms_undo_adv.required_retention(v_analyse_start_time, v_analyse_end_time) into v_required_retention FROM dual;

    DBMS_OUTPUT.PUT_LINE(CHR(9));
    DBMS_OUTPUT.PUT_LINE('Retention Recommendation');
    DBMS_OUTPUT.PUT_LINE('------------------------');
    DBMS_OUTPUT.PUT_LINE(RPAD('The best possible retention with current configuration is ',60) || ' : ' || v_best_retention || ' Seconds');
    DBMS_OUTPUT.PUT_LINE(RPAD('The longest running query ran for ',60) || ' : ' || v_longest_query || ' Seconds');
    DBMS_OUTPUT.PUT_LINE(RPAD('The undo retention required to avoid errors is ',60) || ' : ' || v_required_retention || ' Seconds');

END;
/
