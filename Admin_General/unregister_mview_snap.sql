set serveroutput on
set feed on
undef mview_owner
undef mview_name
undef mview_site
EXEC DBMS_MVIEW.UNREGISTER_MVIEW ( mviewowner => '&mview_owner', mviewname  => '&mview_name', mviewsite  => '&mview_site');
commit;
