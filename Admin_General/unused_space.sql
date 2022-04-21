set serveroutput on
declare
    un number;
    tblocks number;
    lub number;
    tbytes number;
    unbytes number;
    last_extid number;
    last_blkid number;
    begin
    dbms_space.unused_space(SEGMENT_OWNER=>'&segment_owner',SEGMENT_NAME=>'&segment_name',SEGMENT_TYPE=>'&segment_type',TOTAL_BLOCKS=>tblocks,TOTAL_BYTES=>tbytes,UNUSED_BYTES=>unbytes,UNUSED_BLOCKS=>un,LAST_USED_EXTENT_FILE_ID=>last_extid,LAST_USED_EXTENT_BLOCK_ID=>last_blkid,LAST_USED_BLOCK=>lub);
    dbms_output.put_line('Total blocks     : '||tblocks);
    dbms_output.put_line('Unused blocks     : '||un);
    dbms_output.put_line('last extent file_id   : '||last_extid);
    dbms_output.put_line('last extent block_id     : '||last_blkid);
    dbms_output.put_line('last used  block     : '||lub);
    end;
    /



set serveroutput on
declare
    un number;
    tblocks number;
    lub number;
    tbytes number;
    unbytes number;
    last_extid number;
    last_blkid number;
    begin
    dbms_space.unused_space(SEGMENT_OWNER=>'&segment_owner',SEGMENT_NAME=>'&segment_name',PARTITION_NAME=>nvl('&partition_name',null),SEGMENT_TYPE=>'&segment_type',TOTAL_BLOCKS=>tblocks,TOTAL_BYTES=>tbytes,UNUSED_BYTES=>unbytes,UNUSED_BLOCKS=>un,LAST_USED_EXTENT_FILE_ID=>last_extid,LAST_USED_EXTENT_BLOCK_ID=>last_blkid,LAST_USED_BLOCK=>lub);
    dbms_output.put_line('Total blocks     : '||tblocks);
    dbms_output.put_line('Unused blocks     : '||un);
    dbms_output.put_line('last extent file_id   : '||last_extid);
    dbms_output.put_line('last extent block_id     : '||last_blkid);
    dbms_output.put_line('last used  block     : '||lub);
    end;
    /
