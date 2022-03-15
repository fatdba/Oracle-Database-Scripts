SET SERVEROUTPUT ON

DECLARE
	ObjList dbms_stats.ObjectTab;
BEGIN
	dbms_stats.gather_database_stats(objlist => ObjList , options => 'LIST STALE');
	FOR i in ObjList.FIRST..ObjList.LAST
	LOOP
		dbms_output.put_line(rpad(ObjList(i).ownname||'.'||ObjList(i).ObjName,40,' ')||' '||ObjList(i).ObjType||' '||rpad(ObjList(i).partname,30,' ')||Objlist(i).subpartname);
	END LOOP;
END;
/
