set serveroutput on
EXEC DBMS_MONITOR.session_trace_enable(session_id =>&sid, serial_num=>&serial_no, waits=>TRUE, binds=>TRUE);

EXEC DBMS_MONITOR.session_trace_disable(session_id=>&sid, serial_num=>&serial_no)

