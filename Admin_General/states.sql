set pages 2000
col object_name for a15
select a.object_name,b.dbarfil,b.dbablk,
decode(b.state,0,'free',1,'xcur',2,'scur',3,'cr', 4,'read',5,'mrec',6,'irec',7,'write',8,'pi', 9,'memory',10,'mwrite',11,'donated', 12,'protected',  13,'securefile', 14,'siop',15,'recckpt', 16, 'flashfree',  17, 'flashcur', 18, 'flashna') "STATE", 
decode(bitand(flag,1), 0, 'N', 'Y') "DIRTY" ,b.tch,b.CR_SCN_BAS from dba_objects a , x$bh b where a.data_object_id = b.obj AND A.OWNER='&OWNER'   order by 1,3,4,6;
