#!/bin/bash
##############################################################################################
#  Name   : DGDiagnostic.sh                                                                  # 
#  Ver    : 21.1                                                                             #
#  Depend : srdc_DGPrimary_diag.sql, srdc_DGPhyStby_diag.sql and srdc_DGlogicalStby_diag.sql #
#  Date   : 25-Aug-2021                                                                     #
##############################################################################################

path=`pwd`
datetime=$(date "+%Y.%m.%d-%H.%M.%S")
file="dataguard_REDO_transport_check.out"
#sqlfile="srdc_DGPrimary_diag.sql"


if [ `ps -eaf|grep $ORACLE_SID|grep smon|wc -l` -eq 0 ];then
   echo ""
   echo "    Error"
   echo "    -----"
   echo "    DB is down. Please bring it first and then re-run the script."
   echo ""
   echo ""
 return 0
fi

if [ ! -f srdc_DGPrimary_diag.sql ]; then
   echo ""
   echo "    Error"
   echo "    -----"
   echo "    File srdc_DGPrimary_diag.sql doesn't exists in current directory ie \"$path\".  Script is exiting now.
    Please make sure file "DGDiagnostic.zip" from document 2219763.1 is downloaded / copied to current directory ,\"$path\",
    and extracted to ensure all the dependent files are in place.
    Once assured, re-run the script."
   echo ""
   echo ""
   return 0;
fi

if [ ! -f srdc_DGPhyStby_diag.sql ]; then
   echo ""
   echo "    Error"
   echo "    -----"
   echo "    File srdc_DGPhyStby_diag.sql doesn't exists in current directory ie \"$path\".  Script is exiting now.
    Please make sure file "DGDiagnostic.zip" from document 2219763.1 is downloaded / copied to current directory ,\"$path\",
    and extracted to ensure all the dependent files are in place.
    Once assured, re-run the script."
   echo ""
   echo ""
   return 0;
fi

if [ ! -f srdc_DGlogicalStby_diag.sql ]; then
   echo ""
   echo "    Error"
   echo "    -----"
   echo "    File srdc_DGlogicalStby_diag.sql doesn't exists in current directory ie \"$path\".  Script is exiting now.
    Please make sure file "DGDiagnostic.zip" from document 2219763.1 is downloaded / copied to current directory ,\"$path\",
    and extracted to ensure all the dependent files are in place.
    Once assured, re-run the script."
   echo ""
   echo ""
   return 0;
fi

echo "**********************************************"  >script-trace.log
echo "*********Script Version 25-Aug-2021 *********"   >>script-trace.log
echo "**********************************************"  >>script-trace.log
echo "                                              "  >>script-trace.log


sqlplus -s <<EOM>pd1.out
connect /as sysdba
whenever oserror exit 252
whenever sqlerror exit 252
set echo off feedback off timing off verify off pages 0 lines 200;
select value from v\$parameter where lower(name)='instance_name';
select db_unique_name from v\$database;
select database_role from v\$database;
select value  from v\$diag_info where name='Diag Trace';
select upper(value) from v\$parameter where lower(name)='instance_name';
exit
EOM

in=`cat pd1.out|grep -v '^\s*$'|head -1`
dn=`cat pd1.out|grep -v '^\s*$'|head -2|tail -1`
dr=`cat pd1.out|grep -v '^\s*$'|head -3|tail -1|awk '{print $1}'`
dp=`cat pd1.out|grep -v '^\s*$'|tail -2|head -1`
incap=`cat pd1.out|grep -v '^\s*$'|tail -1`

case $dr in
        'PRIMARY')
           sqlfile="srdc_DGPrimary_diag.sql"


# generate html file - data guard primary database#
echo "... Generating diagnostic output ..."
exit | sqlplus "/ as sysdba" @$sqlfile > /dev/null 2>&1

echo "################## Destination detail ####################" > $file
n='grep -v dest_id $file'
# use below query to get DESTINATION where status= ERROR
echo "... Collecting more info ..."
sqlplus -s <<EOM>>$file
connect /as sysdba
whenever oserror exit 252
whenever sqlerror exit 252
ALTER SESSION SET nls_date_format = 'DD-MON-YYYY HH24:MI:SS';
SELECT TO_CHAR(sysdate) time FROM dual;
col dest_id format 99
col destination for a15
col error format a80
col status for a10
col name for a25
set pages 200
set linesize 2000
col RedoTransport_Property for a50
SELECT destination,thread#, dest_id, gvad.status, error, fail_sequence FROM gv\$archive_dest gvad, gv\$instance gvi WHERE gvad.inst_id = gvi.inst_id AND destination is NOT NULL and gvad.status='ERROR' ORDER BY thread#, dest_id;
select name,value as RedoTransport_Property from v\$parameter where value like 'service%';
exit
EOM

echo "" >> $file
echo "" >> $file
echo "################## TNS_ADMIN set by the USER ####################" >> $file
export usertns=`env|grep '^TNS_ADMIN'|uniq`
if [ -z $usertns ]
  then echo "Current Oracle user TNS_ADMIN=$ORACLE_HOME/network/admin" >> $file
else echo "Current Oracle user $usertns"  >> $file
fi
echo "" >>$file
echo "" >>$file

echo "################## TNS_ADMIN as per Database $ORACLE_SID ####################" >> $file

export pid=`ps -eaf|grep smon|grep $ORACLE_SID\$|awk '{print $2}'`
case `uname -s` in
        'SunOS')
           export tns=`pargs -e $pid| grep '^TNS_ADMIN'|awk -F= '{print $2}'|head -1`
           export home=`pargs -e $pid| grep 'ORACLE_HOME'|awk -F= '{print $2}'`
           if [  -z $tns ]
             then echo "TNS_ADMIN=$home/network/admin" >> $file
            else
            echo "TNS_ADMIN=$tns"  >> $file
            fi
        ;;
        'HP-UX')
           export tns=`pargs -e $pid| grep '^TNS_ADMIN'|awk -F= '{print $2}'|head -1`
           export home=`pargs -e $pid| grep 'ORACLE_HOME'|awk -F= '{print $2}'`
           if [  -z $tns ]
             then echo "TNS_ADMIN=$home/network/admin" >> $file
           else
             echo "TNS_ADMIN=$tns" >> $file
            fi
        ;;
        *)
           export tns=`ps eww $pid | tr ' ' '\012' | grep = | grep '^TNS_ADMIN'|awk -F= '{print $2}'|head -1`
           export home=`ps eww $pid | tr ' ' '\012' | grep = | grep '^ORACLE_HOME'|awk -F= '{print $2}'|head -1`
           if [ -z $tns ] && [ -z $home ]
             then echo "Please connect to root and execute below command to get the TNS_ADMIN set for database "                          >> $file
                  echo "   #ps eww $pid | tr ' ' '\012' | grep = | grep '^TNS_ADMIN'|awk -F= '{print $2}'|head -1"                        >> $file
           elif [ -z $tns ]
		      then echo "TNS_ADMIN=$home/network/admin"                                                                                   >> $file
           else
             echo "TNS_ADMIN=$tns"                                                                                                        >> $file  
           fi
        ;;
esac
echo "" >>$file
echo "" >>$file

# get dest id
echo "... Getting tnsping ..."
echo "################## TNSPING ####################" >> $file
for dest in `grep -v DESTINATION $file | grep ERROR | awk '{print $1}'`
do
echo "tnsping $dest" >> $file
echo "===============" >> $file
tnsping $dest >> $file
echo "" >> $file

# check login
echo "... Connection check  ..."
echo "################## connect check ####################" >> $file
read -p "...... Please enter user name used for redo transport (i.e., SYS or REDO_TRANSPORT_USER) : " user
read -s -p "...... Please enter password  : " pass
echo ""
echo "sqlplus -L $user/*****@$dest" >> $file
echo "============================" >> $file
echo "....Performing SQL login check for destination : $dest......"
sqlplus -L "$user/$pass@$dest" as sysdba <<EOM>> $file
EOM
done
        ;;
        'PHYSICAL')
           sqlfile="srdc_DGPhyStby_diag.sql"
# generate html file - data guard primary database#
echo "... Generating diagnostic output ..."
exit | sqlplus "/ as sysdba" @$sqlfile > /dev/null 2>&1

#>$file
        ;;
        'LOGICAL')
           sqlfile="srdc_DGlogicalStby_diag.sql"
# generate html file - data guard primary database#
echo "... Generating diagnostic output ..."
exit | sqlplus "/ as sysdba" @$sqlfile > /dev/null 2>&1

#>$file
        ;;		
esac

### Copy the alert log and broker log to current directory 
SID=`ps -eaf|grep smon| grep -v grep|awk -F"smon" '{print $NF}'|sed 's/^_//'|grep ^$ORACLE_SID$`
case `uname -s` in
        'SunOS')
          echo "....Copying the alert log (and broker log if broker configured) to current directory ......"
          
          alertlog=`ls -lrt $dp/alert*.log|tail -1|awk '{print $NF}'|awk -F"/" '{print $NF}'|sed 's/alert_//'|sed 's/.log//'`
          cp $dp/alert_$alertlog.log  $path/alert_$alertlog\_$dr.log
          
          brokerlog=`ls -lrt $dp/drc* 2>/dev/null|tail -1|awk '{print $NF}'|awk -F"/" '{print $NF}'|sed 's/.log//'|sed 's/drc//'  2>/dev/null` 
          cp $dp/drc$brokerlog.log  $path/srdc_broker_log_drc_$brokerlog\_$dr.log                         2>/dev/null
		;;

        *)
          echo "....Copying the alert log (and broker log if broker configured) to current directory ......"
          
          alertlog=`ls -lrt $dp/alert*.log|tail -1|awk '{print $NF}'|awk -F"/" '{print $NF}'|sed 's/alert_//'|sed 's/.log//'`
          cp $dp/alert_$alertlog.log  $path/alert_$alertlog\_$dr.log
          
          brokerlog=`ls -lrt $dp/drc* 2>/dev/null |tail -1|awk '{print $NF}'|awk -F"/" '{print $NF}'|sed 's/.log//'|sed 's/drc//'  2>/dev/null` 
          cp $dp/drc$brokerlog.log  $path/srdc_broker_log_drc_$brokerlog\_$dr.log                           2>/dev/null
		;;  
esac

###############################
## Get Applied patch details ##
 
echo "....Collecting the applied patch details....."
$ORACLE_HOME/OPatch/opatch lsinventory -details > lsinventory\_$in\_$dr.log 

############################################
## Collect broker configuration details   ##
sqlplus -s <<EOM>>pd1.out
connect /as sysdba
set heading off feedback off
whenever oserror exit 252
whenever sqlerror exit 252
select dataguard_broker FROM v\$database;
exit
EOM

status=`cat pd1.out|grep ENABLED`

sqlplus -s <<EOM>>pd11.out
connect /as sysdba
set heading off feedback off
whenever oserror exit 252
whenever sqlerror exit 252
 select distinct ( substr (version, 0 , length(version) - instr ( reverse(version) , '.' , 1 ,4))) from v\$instance;
exit
EOM
version=`cat pd11.out|grep -v '^\s*$'`
rm -f pd11.out

echo "....Collecting Broker configuration in current directory ..."

#export status=`ps -eaf|grep dmon|grep ^$ORACLE_SID$`

if [ $status ]
then 
   brokerfile=SRDC_DataGuard_Broker_Config_${dr}_$datetime.log
   
   echo "++++ SRDC_DATAGUARD_BROKER_CONFIG ++++"  >> $path/$brokerfile
   
   echo "++++++++++ show configuration +++++++++++"            >> $path/$brokerfile
   echo "show configuration"|${ORACLE_HOME}/bin/dgmgrl /       >> $path/$brokerfile
   cp $path/$brokerfile $path/brtmp.log
   echo -e "\n" >> $path/$brokerfile
   
   echo "++++++++++ show configuration verbose +++++++++++" >> $path/$brokerfile
   echo "show configuration verbose"|${ORACLE_HOME}/bin/dgmgrl / >> $path/$brokerfile
   echo  -e "\n" >> $path/$brokerfile

echo ".......Collecting primary details..."   

   echo "++++++++++ show database($PRI) verbose - primary +++++++++++" >> $path/$brokerfile
   PRI=`cat $path/brtmp.log|grep 'Primary database'|awk '{print $1}'|uniq`
   echo "show database verbose '$PRI'"|${ORACLE_HOME}/bin/dgmgrl /                                             > $path/pd.out
   cat $path/pd.out >> $path/$brokerfile
   echo -e "\n" >> $path/$brokerfile

  if [ $version -ge 11 ]; then   
   echo "++++++++++ validate database verbose ($PRI) - primary +++++++++++" >> $path/$brokerfile
   PRI=`cat $path/brtmp.log|grep 'Primary database'|awk '{print $1}'|uniq`
   echo "validate database verbose '$PRI'"|${ORACLE_HOME}/bin/dgmgrl /                                             > $path/pd.out
   cat $path/pd.out >> $path/$brokerfile
   echo -e "\n" >> $path/$brokerfile   
  fi 
   
for pi in `sed -n '/Instance(s):/,/Properties/{/Instance(s):/!{/Properties/!p;};}' $path/pd.out|grep -v ORA-|grep -vi warn|grep -vi error|grep -v '^\s*$'|sed "s/^\s*//"`
   do
   echo "++++++++++ show instance($pi) verbose - primary +++++++++++"                                             >> $path/$brokerfile
echo ".........Collecting primary instance details (instance :$pi)..."                                           
   echo "show instance verbose '$pi' on database '$PRI'"|${ORACLE_HOME}/bin/dgmgrl /                                                 >> $path/$brokerfile
   echo -e  "\n" >> $path/$brokerfile
   done

   
echo ".......Collecting Secondary details..."  
for sec in `cat $path/brtmp.log|grep database |grep -v 'Primary database'|grep -vi warn|grep -vi error|awk '{print $1}'|uniq`
do
   echo "++++++++++ show database($sec) verbose - secondary +++++++++++"                                            >> $path/$brokerfile
   echo "show database verbose '$sec'"|${ORACLE_HOME}/bin/dgmgrl /                                                  > $path/sd.out
   cat $path/sd.out >> $path/$brokerfile
   echo -e "\n" >> $path/$brokerfile
   
   if [ $version -ge 11 ]; then  
     echo "++++++++++ validate database verbose ($sec) - secondary +++++++++++"                                        >> $path/$brokerfile
     echo "validate database verbose '$sec'"|${ORACLE_HOME}/bin/dgmgrl /                                               > $path/sd.out
     cat $path/sd.out >> $path/$brokerfile
     echo -e "\n" >> $path/$brokerfile
   fi
   
for si in `sed -n '/Instance(s):/,/Properties/{/Instance(s):/!{/Properties/!p;};}' $path/sd.out|grep -v ORA-|grep -vi warn|grep -vi error|grep -v '^\s*$'|sed "s/^\s*//"`
   do
   echo "++++++++++ show instance($si) verbose - secondary +++++++++++"                                             >> $path/$brokerfile
echo ".........Collecting standby instance details (instance :$si)..."    
   echo "show instance verbose '$si' on database '$sec'"|${ORACLE_HOME}/bin/dgmgrl /                                                   >> $path/$brokerfile
   echo  -e "\n" >> $path/$brokerfile
   done
   
done   
   
   echo  -e "\n" >> $path/$brokerfile
   
   echo "++++++++++ FSFO Details +++++++++++"                                                                          >> $path/$brokerfile
   echo "show fast_start failover"|${ORACLE_HOME}/bin/dgmgrl /                                                         >> $path/$brokerfile
   echo  -e "\n" >> $path/$brokerfile                                                                                  
   echo "++++++++++ Observer Details +++++++++++"                                                                      >> $path/$brokerfile
   echo "show observer"|${ORACLE_HOME}/bin/dgmgrl /                                                                    >> $path/$brokerfile

   echo  -e "\n" >> $path/$brokerfile
   
   if [ $version -ge 17 ]; then 
      echo "++++++++++ Network configuration  Checks   +++++++++++"                                                        >> $path/$brokerfile
      echo  -e "\n" >> $path/$brokerfile
      echo "validate network configuration for all"|${ORACLE_HOME}/bin/dgmgrl /                                            >> $path/$brokerfile
      echo  -e "\n" >> $path/$brokerfile   
      
      echo "++++++++++ Static connect identifier Checks  +++++++++++"                                                       >> $path/$brokerfile
      echo  -e "\n" >> $path/$brokerfile   
      echo "validate static connect identifier for all"|${ORACLE_HOME}/bin/dgmgrl /                                         >> $path/$brokerfile
      echo  -e "\n" >> $path/$brokerfile 
   fi 
fi

##################################################################
## Copy tnsnames.ora and sqlnet.ora file  to current directory  ##

echo "....Copying the tnsnames.ora to current directory ......"

if [ -n "$TNS_ADMIN" ]
then
   cp $TNS_ADMIN/tnsnames.ora $path/tnsnames_$in\_$dr.ora                                                                 2>/dev/null
   cp $TNS_ADMIN/sqlnet.ora $path/sqlnet_$in\_$dr.ora                                                                     2>/dev/null
else                                                                                                                      
  cp $ORACLE_HOME/network/admin/tnsnames.ora $path/tnsnames_$in\_$dr.ora                                                  2>/dev/null
  cp $ORACLE_HOME/network/admin/sqlnet.ora $path/sqlnet_$in\_$dr.ora                                                      2>/dev/null  
fi

echo "....Gathering the listener details to current directory ......"
echo "Listeners running on server "                                                                                       >  listener_details\_$dr.log
echo "============================ "                                                                                      >> listener_details\_$dr.log
ps -eaf|grep lsnr|grep -v grep                                                                                            >> listener_details\_$dr.log
echo " "                                                                                                                  >> listener_details\_$dr.log
echo " "                                                                                                                  >> listener_details\_$dr.log

     ps -eaf|grep lsnr|grep -i -v grep|grep -i -v scan |sed 's/-inherit'//|sed 's/-no_crs_notify//'|awk '{print $(NF-1) " " $NF}'|while read t
     do
      echo " "                                                                                                             >> listener_details\_$dr.log
      echo " "                                                                                                             >> listener_details\_$dr.log
      echo "============================ "                                                                                 >> listener_details\_$dr.log
      echo "Listener details running from ORACLE_HOME : `echo  $t|awk '{print $1}'|awk -F"bin" '{print $1}'`"              >> listener_details\_$dr.log
      echo "Listener name                             : `echo  $t|awk '{print $2}'`"                                       >> listener_details\_$dr.log	  	  
      echo "---"                                                                                                           >> listener_details\_$dr.log
      echo "  "                                                                                                            >> listener_details\_$dr.log
      `echo  $t|awk '{print $1}'|awk -F"bin" '{print $1}'`/bin/lsnrctl status `echo $t|awk '{print $2}'`     2>/dev/null   >> listener_details\_$dr.log
     done

	 ps -eaf|grep lsnr|grep -i -v grep|sed s/-inherit//|sed 's/-no_crs_notify//'|awk '{print $(NF-1)}'|sed 's/\/bin\/tnslsnr//'|grep -v sed|sort -u|while read t
	 do 
      echo " "                                                                                                             >> listener_details\_$dr.log
      echo " " 
      echo "============================ "                                                                                 >> listener_details\_$dr.log
      echo "Details of listener.ora from  ORACLE_HOME : `echo  $t`"                                                        >> listener_details\_$dr.log
      echo "---"                                                                                                           >> listener_details\_$dr.log
	  `echo cat $t/network/admin/listener.ora 2>/dev/null`                                                                             >> listener_details\_$dr.log
	 done
	 

case $dr in
        'PHYSICAL')

############################################################
# copy the PRnn trace file from Physical standby database ##
case `uname -s` in
        'SunOS')
		  export PRN_TRACE=`/usr/xpg4/bin/awk -v A=9 '/Slave exiting with ORA-600 exception|ERROR: ORA-00752/{f=A+1} f{print;f--}' $dp/alert_$alertlog.log|grep "_pr[0-9a-z][0-9a-z]_"|tail -1|awk -F"file" '{print $2}'|awk -F: '{print $1}'`
		  if [ ! -z $PRN_TRACE ] 
           then  
echo "....Copying the PRnn trace......"				   
		   `cp $PRN_TRACE $path/ 2>/dev/null`
		  fi 
		   
        ;;
        'HP-UX')
		  export PRN_TRACE=`awk -v A=9 '/Slave exiting with ORA-600 exception|ERROR: ORA-00752/{f=A+1} f{print;f--}' $dp/alert_$alertlog.log|grep "_pr[0-9a-z][0-9a-z]_"|tail -1|awk -F"file" '{print $2}'|awk -F: '{print $1}'`
		  if [ ! -z $PRN_TRACE ] 
           then
echo "....Copying the PRnn trace......"		
		   `cp $PRN_TRACE $path/ 2>/dev/null`
		  fi
        ;;
        *)
		  export PRN_TRACE=`awk -v A=9 '/Slave exiting with ORA-600 exception|ERROR: ORA-00752/{f=A+1} f{print;f--}' $dp/alert_$alertlog.log|grep "_pr[0-9a-z][0-9a-z]_"|tail -1|awk -F"file" '{print $2}'|awk -F: '{print $1}'`
		  if [ ! -z $PRN_TRACE ] 
           then  
echo "....Copying the PRnn trace......"		   
		   `cp $PRN_TRACE $path/ 2>/dev/null`
		  fi	
        ;;
esac
        ;;
esac


############################
## Prepare tar ball files ##

echo "....Preparing the tar of all the files generated ......"
case $dr in
        'PRIMARY')
		
diag=`ls -lrt SRDC_DG_PRIM_DIAG*|grep -i $in|tail -1|awk '{print $NF}'`

# Chek the files created in current directory 

ls -lrt srdc_DGPrimary_diag.sql srdc_DGPhyStby_diag.sql srdc_DGlogicalStby_diag.sql 2>/dev/null        >> script-trace.log
echo ""                                                                                                >> script-trace.log
ls -lrt|tail -16                                                                                       >> script-trace.log
echo ""                                                                                                >> script-trace.log
echo "DB Parameters"                                                                                   >> script-trace.log
echo "=============="                                                                                  >> script-trace.log
cat pd1.out                                                                                            >> script-trace.log
ls -lrt $dp/alert*.log                                                                                 >> script-trace.log
ls -lrt $dp/drc*  2>/dev/null |grep -i $in                                                             >> script-trace.log
rm -f pd1.out pd.out sd.out brtmp.log


#tar -zcf SRDC_PRIMARY_Details.tar.gz $(ls $diag dataguard_REDO_transport_check.out $alertlog\_$dr.log tnsnames_$in\_$dr.ora)
tar -cf SRDC_PRIMARY_Details_$datetime.tar $(ls $diag dataguard_REDO_transport_check.out alert_$alertlog\_$dr.log tnsnames_$in\_$dr.ora  listener_details\_$dr.log script-trace.log srdc_broker_log_drc_$brokerlog\_$dr.log $brokerfile sqlnet_$in\_$dr.ora lsinventory\_$in\_$dr.log 2>/dev/null) && gzip -9f SRDC_PRIMARY_Details_$datetime.tar
echo ""
echo ""
echo  "Please upload the following file to Oracle support:"
echo "        ""$path"/SRDC_PRIMARY_Details_$datetime.tar.gz
        ;;
		
#################################################
## Prepart tar ball for standby database files ##	
	
        'PHYSICAL')

diag=`ls -lrt SRDC_DG_PHYSTBY_DIAG*|grep -i $in|tail -1|awk '{print $NF}'`

ls -lrt srdc_DGPrimary_diag.sql srdc_DGPhyStby_diag.sql srdc_DGlogicalStby_diag.sql 2>/dev/null        >> script-trace.log
echo ""                                                                                                >> script-trace.log
ls -lrt|tail -16                                                                                       >> script-trace.log
echo ""                                                                                                >> script-trace.log
echo "pd1.out"                                                                                         >> script-trace.log
echo "======="                                                                                         >> script-trace.log
cat pd1.out                                                                                            >> script-trace.log
ls -lrt $dp/alert*.log                                                                                 >> script-trace.log
rm -f pd1.out pd.out sd.out brtmp.log


#tar -zcf SRDC_PHYSICAL_Details.tar.gz $(ls $diag alert_$in\_$dr.log listener_details_$dr.log *_pr[0-9a-z][0-9a-z]_*.trc)
tar -cf SRDC_PHYSICAL_Details_$datetime.tar $(ls $diag alert_$alertlog\_$dr.log tnsnames_$in\_$dr.ora listener_details\_$dr.log $in\_pr[0-9a-z][0-9a-z]\_*.trc script-trace.log srdc_broker_log_drc_$brokerlog\_$dr.log $brokerfile sqlnet_$in\_$dr.ora lsinventory\_$in\_$dr.log 2>/dev/null) && gzip -9f SRDC_PHYSICAL_Details_$datetime.tar
echo ""
echo ""
echo "Please upload the following file to Oracle support:"
echo "        ""$path"/SRDC_PHYSICAL_Details_$datetime.tar.gz
        ;;

#################################################
## Prepart tar ball for standby database files ##	
	
        'LOGICAL')

diag=`ls -lrt SRDC_DG_LOGICSTBY_DIAG*|grep -i $in|tail -1|awk '{print $NF}'`

ls -lrt srdc_DGPrimary_diag.sql srdc_DGPhyStby_diag.sql srdc_DGlogicalStby_diag.sql 2>/dev/null        >> script-trace.log
echo ""                                                                                                >> script-trace.log
ls -lrt|tail -16                                                                                       >> script-trace.log
echo ""                                                                                                >> script-trace.log
echo "pd1.out"                                                                                         >> script-trace.log
echo "======="                                                                                         >> script-trace.log
cat pd1.out                                                                                            >> script-trace.log
ls -lrt $dp/alert*.log                                                                                 >> script-trace.log
rm -f pd1.out pd.out sd.out brtmp.log


#tar -zcf SRDC_LOGICSTBY_Details.tar.gz $(ls $diag alert_$in\_$dr.log listener_details_$dr.log *_pr[0-9a-z][0-9a-z]_*.trc)
tar -cf SRDC_LOGICSTBY_Details_$datetime.tar $(ls $diag alert_$alertlog\_$dr.log tnsnames_$in\_$dr.ora listener_details\_$dr.log $in\_pr[0-9a-z][0-9a-z]\_*.trc script-trace.log srdc_broker_log_drc_$brokerlog\_$dr.log $brokerfile sqlnet_$in\_$dr.ora lsinventory\_$in\_$dr.log 2>/dev/null) && gzip -9f SRDC_LOGICSTBY_Details_$datetime.tar
echo ""
echo ""
echo "Please upload the following file to Oracle support:"
echo "        ""$path"/SRDC_LOGICSTBY_Details_$datetime.tar.gz
        ;;		
		
esac

echo ""
