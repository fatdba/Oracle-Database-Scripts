WITH bh_lc AS
  (SELECT
    /*+ ORDERED */
    lc.addr,
    lc.child#,
    lc.gets,
    lc.misses,
    lc.immediate_gets,
    lc.immediate_misses,
    lc.spin_gets,
    lc.sleeps,
    bh.hladdr,
    bh.tch tch,
    bh.file#,
    bh.dbablk,
    bh.class,
    bh.state,
    bh.obj
  FROM x$kslld ld,
    v$session_wait sw,
    v$latch_children lc,
    x$bh bh
  WHERE lc.addr  =sw.p1raw
  AND sw.p2      = ld.indx
  AND ld.kslldnam='cache buffers chains'
  AND lower(sw.event) LIKE '%latch%'
  AND sw.state ='WAITING'
  AND bh.hladdr=lc.addr
  )
SELECT bh_lc.hladdr,
  bh_lc.tch,
  o.owner,
  o.object_name,
  o.object_type,
  bh_lc.child#,
  bh_lc.gets,
  bh_lc.misses,
  bh_lc.immediate_gets,
  bh_lc.immediate_misses,
  spin_gets,
  sleeps
FROM bh_lc,
  dba_objects o
WHERE bh_lc.obj = o.object_id(+)
UNION
SELECT bh_lc.hladdr,
  bh_lc.tch,
  o.owner,
  o.object_name,
  o.object_type,
  bh_lc.child#,
  bh_lc.gets,
  bh_lc.misses,
  bh_lc.immediate_gets,
  bh_lc.immediate_misses,
  spin_gets,
  sleeps
FROM bh_lc,
  dba_objects o
WHERE bh_lc.obj = o.data_object_id(+)
ORDER BY 1,2 DESC;
