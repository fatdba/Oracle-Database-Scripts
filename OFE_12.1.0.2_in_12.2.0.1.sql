-- Oracle provided script
REM DESCRIPTION
REM   This script is used to set the CBO parameters and fix control
REM   settings to downgrade the optimizer features to 12.1.0.2
REM   in an 12.2.0.1 Database environment with default optimizer features set.
REM   These are the parameters and fix controls that are linked to OFE and
REM   change its values upon OFE change. However, there are some parameters and
REM   fix controls that are not linked to OFE and hence such parameters/fix controls
REM   would remain unchanged upon OFE change.

REM   Starting 12.1.0.2.170418 DBBP, Optimizer fixes are included as part of bundle patches 
REM   with the fix controls disabled by default for those fixes. Hence there are chances for
REM   difference in the fix control settings given in the script with the customer environment 
REM	  when the customer environment is 12.1.0.2.170418 DBBP or above.

REM NOTES
REM   1. For errors see OFE_12.1.0.2_in_12.2.0.1.log
REM   2. This can be used in ADG (read-only standby database) environment also.

REM CBO Hidden Parameters To be set in 12.2.0.1 Optimizer Env to come to 12.1.0.2 OFE level

alter session set "_optimizer_undo_cost_change"="12.1.0.2";
alter session set "_optimizer_cbqt_or_expansion"=off;
alter session set "_optimizer_ads_use_partial_results"=false;
alter session set "_query_rewrite_use_on_query_computation"=false;
alter session set "_px_scalable_invdist_mcol"=false;
alter session set "_optimizer_eliminate_subquery"=false;
alter session set "_sqlexec_hash_based_distagg_ssf_enabled"=false;
alter session set "_optimizer_union_all_gsets"=false;
alter session set "_optimizer_enhanced_join_elimination"=false;
alter session set "_optimizer_multicol_join_elimination"=false;
alter session set "_key_vector_create_pushdown_threshold"=0;
alter session set "_optimizer_enable_plsql_stats"=false;
alter session set "_recursive_with_parallel"=false;
alter session set "_recursive_with_branch_iterations"=1;
alter session set "_px_dist_agg_partial_rollup_pushdown"=off;
alter session set "_optimizer_key_vector_pruning_enabled"=false;
alter session set "_pwise_distinct_enabled"=false;
alter session set "_vector_encoding_mode"=off;
alter session set "_ds_xt_split_count"=0;
alter session set "_ds_sampling_method"=NO_QUALITY_METRIC;
alter session set "_optimizer_ads_use_spd_cache"=false;
alter session set "_optimizer_use_table_scanrate"=OFF;
alter session set "_optimizer_use_xt_rowid"=false;
alter session set "_xt_sampling_scan_granules"=off;
alter session set "_optimizer_band_join_aware"=false;
alter session set "_optimizer_vector_base_dim_fact_factor"=0;
alter session set "_ds_enable_view_sampling"=false;
alter session set "_optimizer_inmemory_use_stored_stats"=NEVER;
alter session set "_mv_access_compute_fresh_data"=off;
alter session set "_bloom_filter_ratio"=30;
alter session set "_optimizer_control_shard_qry_processing"=65535;
alter session set "_optimizer_interleave_or_expansion"=false;
/

PRO CBO Parameters settings completed.

PAUSE Press Enter to continue.

REM CBO Fix Control Settings in 12.2.0.1 Optimizer Env to come to 12.1.0.2 OFE level

alter session set "_fix_control"="16515789:0";
alter session set "_fix_control"="17491018:0";
alter session set "_fix_control"="17986549:0";
alter session set "_fix_control"="18115594:0";
alter session set "_fix_control"="18182018:0";
alter session set "_fix_control"="18302923:0";
alter session set "_fix_control"="18377553:0";
alter session set "_fix_control"="5677419:0";
alter session set "_fix_control"="18134680:0";
alter session set "_fix_control"="18636079:0";
alter session set "_fix_control"="18415557:0";
alter session set "_fix_control"="18385778:0";
alter session set "_fix_control"="18308329:0";
alter session set "_fix_control"="17973658:0";
alter session set "_fix_control"="18558952:0";
alter session set "_fix_control"="18874242:0";
alter session set "_fix_control"="18765574:0";
alter session set "_fix_control"="18952882:0";
alter session set "_fix_control"="18924221:0";
alter session set "_fix_control"="18422714:0";
alter session set "_fix_control"="18798414:0";
alter session set "_fix_control"="18969167:0";
alter session set "_fix_control"="19055664:0";
alter session set "_fix_control"="18898582:0";
alter session set "_fix_control"="18960760:0";
alter session set "_fix_control"="19070454:0";
alter session set "_fix_control"="19230097:0";
alter session set "_fix_control"="19063497:0";
alter session set "_fix_control"="19046459:0";
alter session set "_fix_control"="19269482:0";
alter session set "_fix_control"="18876528:0";
alter session set "_fix_control"="19227996:0";
alter session set "_fix_control"="18864613:0";
alter session set "_fix_control"="19239478:0";
alter session set "_fix_control"="19451895:0";
alter session set "_fix_control"="18907390:0";
alter session set "_fix_control"="19025959:0";
alter session set "_fix_control"="16774698:0";
alter session set "_fix_control"="19475484:0";
alter session set "_fix_control"="19287919:0";
alter session set "_fix_control"="19386746:0";
alter session set "_fix_control"="19774486:0";
alter session set "_fix_control"="18671960:0";
alter session set "_fix_control"="19484911:0";
alter session set "_fix_control"="19731940:0";
alter session set "_fix_control"="19604408:0";
alter session set "_fix_control"="14402409:0";
alter session set "_fix_control"="16486095:0";
alter session set "_fix_control"="19563657:0";
alter session set "_fix_control"="19632232:0";
alter session set "_fix_control"="19889960:0";
alter session set "_fix_control"="17208933:0";
alter session set "_fix_control"="19710102:0";
alter session set "_fix_control"="18697515:0";
alter session set "_fix_control"="18318631:0";
alter session set "_fix_control"="20078639:0";
alter session set "_fix_control"="19503668:0";
alter session set "_fix_control"="20124288:0";
alter session set "_fix_control"="19847091:0";
alter session set "_fix_control"="12618642:0";
alter session set "_fix_control"="19779920:0";
alter session set "_fix_control"="20186282:0";
alter session set "_fix_control"="20186295:0";
alter session set "_fix_control"="20265690:0";
alter session set "_fix_control"="16047938:0";
alter session set "_fix_control"="19507904:0";
alter session set "_fix_control"="18915345:0";
alter session set "_fix_control"="20329321:0";
alter session set "_fix_control"="20225191:0";
alter session set "_fix_control"="18776755:0";
alter session set "_fix_control"="19882842:0";
alter session set "_fix_control"="20010996:0";
alter session set "_fix_control"="20379571:0";
alter session set "_fix_control"="20129763:0";
alter session set "_fix_control"="19899588:0";
alter session set "_fix_control"="10098852:0";
alter session set "_fix_control"="19663421:0";
alter session set "_fix_control"="20465582:0";
alter session set "_fix_control"="16732417:0";
alter session set "_fix_control"="20732410:0";
alter session set "_fix_control"="20289688:0";
alter session set "_fix_control"="20543684:0";
alter session set "_fix_control"="20506136:0";
alter session set "_fix_control"="20830312:0";
alter session set "_fix_control"="19768896:0";
alter session set "_fix_control"="19814541:0";
alter session set "_fix_control"="17443547:0";
alter session set "_fix_control"="19123152:0";
alter session set "_fix_control"="19899833:0";
alter session set "_fix_control"="20754928:0";
alter session set "_fix_control"="20808265:0";
alter session set "_fix_control"="20808192:0";
alter session set "_fix_control"="20340595:0";
alter session set "_fix_control"="18949550:0";
alter session set "_fix_control"="14775297:0";
alter session set "_fix_control"="17497847:0";
alter session set "_fix_control"="20232513:0";
alter session set "_fix_control"="20587527:0";
alter session set "_fix_control"="19186783:0";
alter session set "_fix_control"="19653920:0";
alter session set "_fix_control"="21211786:0";
alter session set "_fix_control"="21057343:0";
alter session set "_fix_control"="21503478:0";
alter session set "_fix_control"="21476032:0";
alter session set "_fix_control"="20859246:0";
alter session set "_fix_control"="21639419:0";
alter session set "_fix_control"="20951803:0";
alter session set "_fix_control"="21683982:0";
alter session set "_fix_control"="20216500:0";
alter session set "_fix_control"="20906162:0";
alter session set "_fix_control"="20854798:0";
alter session set "_fix_control"="21509656:0";
alter session set "_fix_control"="21833220:0";
alter session set "_fix_control"="21802552:0";
alter session set "_fix_control"="21452843:0";
alter session set "_fix_control"="21800590:0";
alter session set "_fix_control"="21273039:0";
alter session set "_fix_control"="16750133:0";
alter session set "_fix_control"="22013607:0";
alter session set "_fix_control"="22152372:0";
alter session set "_fix_control"="22077191:0";
alter session set "_fix_control"="22123025:0";
alter session set "_fix_control"="16913734:0";
alter session set "_fix_control"="8357294:0";
alter session set "_fix_control"="21979983:0";
alter session set "_fix_control"="22158526:0";
alter session set "_fix_control"="21971099:0";
alter session set "_fix_control"="22090662:0";
alter session set "_fix_control"="21300129:0";
alter session set "_fix_control"="21339278:0";
alter session set "_fix_control"="20270511:0";
alter session set "_fix_control"="21424812:0";
alter session set "_fix_control"="22114090:0";
alter session set "_fix_control"="22159570:0";
alter session set "_fix_control"="22272439:0";
alter session set "_fix_control"="22372694:0";
alter session set "_fix_control"="22514195:0";
alter session set "_fix_control"="22520315:0";
alter session set "_fix_control"="22649054:0";
alter session set "_fix_control"="8617254:0";
alter session set "_fix_control"="22020067:0";
alter session set "_fix_control"="22864730:0";
alter session set "_fix_control"="21099502:0";
alter session set "_fix_control"="22904304:0";
alter session set "_fix_control"="22967807:0";
alter session set "_fix_control"="22879002:0";
alter session set "_fix_control"="23019286:0";
alter session set "_fix_control"="22760704:0";
alter session set "_fix_control"="20853506:0";
alter session set "_fix_control"="22513493:0";
alter session set "_fix_control"="22518491:0";
alter session set "_fix_control"="23103096:0";
alter session set "_fix_control"="22143411:0";
alter session set "_fix_control"="23180670:0";
alter session set "_fix_control"="23002609:0";
alter session set "_fix_control"="23210039:0";
alter session set "_fix_control"="23102649:0";
alter session set "_fix_control"="23071621:0";
alter session set "_fix_control"="23136865:0";
alter session set "_fix_control"="23176721:0";
alter session set "_fix_control"="23223113:0";
alter session set "_fix_control"="22258300:0";
alter session set "_fix_control"="22205301:0";
alter session set "_fix_control"="23556483:0";
alter session set "_fix_control"="21305617:0";
alter session set "_fix_control"="22533539:0";
alter session set "_fix_control"="23596611:0";
alter session set "_fix_control"="22937293:0";
alter session set "_fix_control"="23565188:0";
alter session set "_fix_control"="24654471:0";
alter session set "_fix_control"="24845754:0";
/
SPO OFF;

PRO Fix control settings completed.


ALTER session set "_fix_control"='5483301:OFF';
