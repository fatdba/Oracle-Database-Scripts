select
samp.dbid,
fu.name,
samp.version,
detected_usages,
total_samples,
decode(to_char(last_usage_date, 'MM/DD/YYYY, HH:MI:SS'),
NULL, 'FALSE',
to_char(last_sample_date, 'MM/DD/YYYY, HH:MI:SS'), 'TRUE',
'FALSE')
currently_used,
first_usage_date,
last_usage_date,
aux_count,
feature_info,
last_sample_date,
last_sample_period,
sample_interval,
mt.description
from
wri$_dbu_usage_sample samp,
wri$_dbu_feature_usage fu,
wri$_dbu_feature_metadata mt
where
samp.dbid = fu.dbid and
samp.version = fu.version and
fu.name = mt.name and
fu.name not like '_DBFUS_TEST%' and /* filter out test features */
bitand(mt.usg_det_method, 4) != 4 /* filter out disabled features */;
