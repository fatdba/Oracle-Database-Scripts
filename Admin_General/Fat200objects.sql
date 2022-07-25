PROMPT
PROMPT
PROMPT
PROMPT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PROMPT------                 /)  (\
PROMPT------            .-._((,~~.))_.-,
PROMPT------             `-.   @@   ,-'
PROMPT------               / ,o--o. \
PROMPT------              ( ( .__. ) )
PROMPT------               ) `----' (
PROMPT------              /          \
PROMPT------             /            \
PROMPT------            /              \
PROMPT------    "The Silly Cow"
PROMPT----- Script: Fat200objects.sql
PROMPT----- Author: Prashant 'The FatDBA'
PROMPT----- Version: V1.1 (Date: 04-02-2007)
PROMPT-----
PROMPT-----
PROMPT-----

WITH schema_object AS (
SELECT  
       segment_type,
       owner,
       segment_name,
       tablespace_name,
       COUNT(*) segments,
       SUM(extents) extents,
       SUM(blocks) blocks,
       SUM(bytes) bytes
  FROM dba_segments
 WHERE 'Y' = 'Y'
 GROUP BY
       segment_type,
       owner,
       segment_name,
       tablespace_name
), totals AS (
SELECT  
       SUM(segments) segments,
       SUM(extents) extents,
       SUM(blocks) blocks,
       SUM(bytes) bytes
  FROM schema_object
), top_200_pre AS (
SELECT  
       ROWNUM rank, v1.*
       FROM (
SELECT so.segment_type,
       so.owner,
       so.segment_name,
       so.tablespace_name,
       so.segments,
       so.extents,
       so.blocks,
       so.bytes,
       ROUND((so.segments / t.segments) * 100, 3) segments_perc,
       ROUND((so.extents / t.extents) * 100, 3) extents_perc,
       ROUND((so.blocks / t.blocks) * 100, 3) blocks_perc,
       ROUND((so.bytes / t.bytes) * 100, 3) bytes_perc
  FROM schema_object so,
       totals t
 ORDER BY
       bytes_perc DESC NULLS LAST
) v1
 WHERE ROWNUM < 201
), top_200 AS (
SELECT p.*,
       (SELECT object_id
          FROM dba_objects o
         WHERE o.object_type = p.segment_type
           AND o.owner = p.owner
           AND o.object_name = p.segment_name
           AND o.object_type NOT LIKE '%PARTITION%') object_id,
       (SELECT data_object_id
          FROM dba_objects o
         WHERE o.object_type = p.segment_type
           AND o.owner = p.owner
           AND o.object_name = p.segment_name
           AND o.object_type NOT LIKE '%PARTITION%') data_object_id,
       (SELECT SUM(p2.bytes_perc) FROM top_200_pre p2 WHERE p2.rank <= p.rank) bytes_perc_cum
  FROM top_200_pre p
), top_200_totals AS (
SELECT  
       SUM(segments) segments,
       SUM(extents) extents,
       SUM(blocks) blocks,
       SUM(bytes) bytes,
       SUM(segments_perc) segments_perc,
       SUM(extents_perc) extents_perc,
       SUM(blocks_perc) blocks_perc,
       SUM(bytes_perc) bytes_perc
  FROM top_200
), top_100_totals AS (
SELECT  
       SUM(segments) segments,
       SUM(extents) extents,
       SUM(blocks) blocks,
       SUM(bytes) bytes,
       SUM(segments_perc) segments_perc,
       SUM(extents_perc) extents_perc,
       SUM(blocks_perc) blocks_perc,
       SUM(bytes_perc) bytes_perc
  FROM top_200
 WHERE rank < 101
), top_20_totals AS (
SELECT  
       SUM(segments) segments,
       SUM(extents) extents,
       SUM(blocks) blocks,
       SUM(bytes) bytes,
       SUM(segments_perc) segments_perc,
       SUM(extents_perc) extents_perc,
       SUM(blocks_perc) blocks_perc,
       SUM(bytes_perc) bytes_perc
  FROM top_200
 WHERE rank < 21
)
SELECT v.rank,
       v.segment_type,
       v.owner,
       v.segment_name,
       v.object_id,
       v.data_object_id,
       v.tablespace_name,
       CASE
       WHEN v.segment_type LIKE 'INDEX%' THEN
         (SELECT i.table_name
            FROM dba_indexes i
           WHERE i.owner = v.owner AND i.index_name = v.segment_name)
       WHEN v.segment_type LIKE 'LOB%' THEN
         (SELECT l.table_name
            FROM dba_lobs l
           WHERE l.owner = v.owner AND l.segment_name = v.segment_name)
       END table_name,
       v.segments,
       v.extents,
       v.blocks,
       v.bytes,
       ROUND(v.bytes / POWER(10,9), 3) gb,
       LPAD(TO_CHAR(v.segments_perc, '990.000'), 7) segments_perc,
       LPAD(TO_CHAR(v.extents_perc, '990.000'), 7) extents_perc,
       LPAD(TO_CHAR(v.blocks_perc, '990.000'), 7) blocks_perc,
       LPAD(TO_CHAR(v.bytes_perc, '990.000'), 7) bytes_perc,
       LPAD(TO_CHAR(v.bytes_perc_cum, '990.000'), 7) perc_cum
  FROM (
SELECT d.rank,
       d.segment_type,
       d.owner,
       d.segment_name,
       d.object_id,
       d.data_object_id,
       d.tablespace_name,
       d.segments,
       d.extents,
       d.blocks,
       d.bytes,
       d.segments_perc,
       d.extents_perc,
       d.blocks_perc,
       d.bytes_perc,
       d.bytes_perc_cum
  FROM top_200 d
 UNION ALL
SELECT TO_NUMBER(NULL) rank,
       NULL segment_type,
       NULL owner,
       NULL segment_name,
       TO_NUMBER(NULL),
       TO_NUMBER(NULL),
       'TOP  20' tablespace_name,
       st.segments,
       st.extents,
       st.blocks,
       st.bytes,
       st.segments_perc,
       st.extents_perc,
       st.blocks_perc,
       st.bytes_perc,
       TO_NUMBER(NULL) bytes_perc_cum
  FROM top_20_totals st
 UNION ALL
SELECT TO_NUMBER(NULL) rank,
       NULL segment_type,
       NULL owner,
       NULL segment_name,
       TO_NUMBER(NULL),
       TO_NUMBER(NULL),
       'TOP 100' tablespace_name,
       st.segments,
       st.extents,
       st.blocks,
       st.bytes,
       st.segments_perc,
       st.extents_perc,
       st.blocks_perc,
       st.bytes_perc,
       TO_NUMBER(NULL) bytes_perc_cum
  FROM top_100_totals st
 UNION ALL
SELECT TO_NUMBER(NULL) rank,
       NULL segment_type,
       NULL owner,
       NULL segment_name,
       TO_NUMBER(NULL),
       TO_NUMBER(NULL),
       'TOP 200' tablespace_name,
       st.segments,
       st.extents,
       st.blocks,
       st.bytes,
       st.segments_perc,
       st.extents_perc,
       st.blocks_perc,
       st.bytes_perc,
       TO_NUMBER(NULL) bytes_perc_cum
  FROM top_200_totals st
 UNION ALL
SELECT TO_NUMBER(NULL) rank,
       NULL segment_type,
       NULL owner,
       NULL segment_name,
       TO_NUMBER(NULL),
       TO_NUMBER(NULL),
       'TOTAL' tablespace_name,
       t.segments,
       t.extents,
       t.blocks,
       t.bytes,
       100 segemnts_perc,
       100 extents_perc,
       100 blocks_perc,
       100 bytes_perc,
       TO_NUMBER(NULL) bytes_perc_cum
  FROM totals t) v;
