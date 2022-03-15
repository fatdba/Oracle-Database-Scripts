SELECT le.leseq "Current log sequence No",
100*cp.cpodr_bno/le.lesiz "Percent Full",
cp.cpodr_bno "Current Block No",
le.lesiz "Size of Log in Blocks"
FROM x$kcccp cp, x$kccle le
WHERE le.leseq =CP.cpodr_seq
AND bitand(le.leflg,24) = 8
/
