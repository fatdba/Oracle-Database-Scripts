col segment_name format a30
col owner format a20
col tablespace_name format a30
select * from (select owner,segment_name,SEGMENT_TYPE,TABLESPACE_NAME,round(sum(BYTES)/(1024*1024*1024)) size_in_GB from dba_segments 
group by owner,segment_name,SEGMENT_TYPE,TABLESPACE_NAME order by 5 desc ) where rownum<=10;
