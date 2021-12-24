var n_snapid number

set feed off term on head off
set serveroutput on size unlimited

begin
 	:n_snapid := dbms_workload_repository.create_snapshot();
	dbms_output.put_line('snap_id: ' || to_char(:n_snapid));
end;
/
