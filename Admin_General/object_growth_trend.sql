COLUMN timepoint FORMAT A30

undef oowner
undef oname
undef otype
undef partname
SELECT *
FROM   TABLE(DBMS_SPACE.object_growth_trend ('&&oowner','&&oname','&&otype','&&partname'))
ORDER BY timepoint;
