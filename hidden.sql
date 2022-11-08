--
-- A short one to check value of a particular hidden param
--
col ParameterName for a30
col sessval for a30
col instval for a30
SELECT pi.ksppinm ParameterName, pcv.ksppstvl SessVal, psv.ksppstvl InstVal
FROM x$ksppi pi, x$ksppcv pcv, x$ksppsv psv
WHERE pi.indx = pcv.indx AND pi.indx = psv.indx AND pi.ksppinm LIKE '_kdlu_trace_layer%'
