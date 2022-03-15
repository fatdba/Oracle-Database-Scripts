#!/bin/ksh
#prw.sh

VERSION=19.8.20.9.0
# Version format = latest_tested_db_version_major_release(#.#).year.month.revision#
#
# This script will find clusterware and/or Oracle Background processes and collect
# stack traces for debugging.  It will write a file called procname_pid_date_hour.out
# for each process.  If you are debugging clusterware then run this script as root.
# If you are only debugging Oracle background processes then you can run as
# root or oracle.
#
# Paramaters have been moved to the prwinit.ora file which is created in the Procwatcher directory

## 19.8.20.9.0 mpolaski: hostname special characters, process_memory on by default in Linux, permissions
## 12.2.17.4 mpolaski: TFA/root compatibility, don't remove proclist file for external table, security
## 12.2.15.2 mpolaski: server pool / policy managed support & clean option
## 12.1.14.12 mpolaski: prwinit.ora file
## 11.2.12.12 mpolaski: Warning e-mails, suspected final blocker
## 111212 mpolaski: Faster cycle time, sgamemwatch param, top cpu consumers on Linux
## 043012 mpolaski: Reduce SQL versions with procwatcher_pids table
## 022812 mpolaski: New PRWDIR parameter
## 062211 mpolaski: Format waitchains output and fix housekeeper retention issue
## 122010 mpolaski: Linux specific pgamemory collection added with process_memory=y
## 050710 mpolaski: Add custom SQL and handle instance startup/shutdown better
## 042110 mpolaski: Add RETENTION parameter, change start arguments
## 041210 mpolaski: Add heapdetails query, other minor fixes
## 040110 mpolaski: Add version check, smarter oratab search, dynamic stack count
## 030910 mpolaski: Don't fall back to OS debugger by default if short_stack fails per bug 6859515
## 031010 mpolaski: Add SQL control
## 030510 mpolaski: Added process memory collection
## 030410 mpolaski: Add pack option
## 030310 mpolaski: Add v$wait_chains for 11g
## 030110 mpolaski: Add 11g clusterware procs, add procstack, _go_faster=true
## 040209 mpolaski: fall back to v$ views if gv$ times out
## 101907 mpolaski: added sqltext functionality
## 092807 mpolaski: released

### PATH Check
PS=`which ps`
FIND=`which find`
if [ ! -f "$PS" ] || [ ! -f "$FIND" ]
  then echo `date`: "ERROR: PATH is not set up correctly (need /bin and /usr/bin), Exiting"
  exit 1;
fi

### Platform specific section...
platform=`uname`
osversion=$platform
case $platform in
Linux)
  ECHO="echo -e"
  # pstack is just a wrapper for gdb on linux anyways...
  USE_PSTACK=false
  USE_GDB=true
  GDB=/usr/bin/gdb
  process_memory=y
  if [ -z "$PROCINTERVAL" ]
  then PROCINTERVAL=1
  fi
  INSTLOC=/etc/oraInst.loc
  ;;
HP-UX)
  export UNIX95=0
  if [ -z "$USE_PSTACK" ]; then
    USE_GDB=true
    if [ -f /opt/langtools/bin/gdb64 ]
      then GDB=/opt/langtools/bin/gdb64
    elif [ -f /usr/ccs/bin/gdb64 ]
      then GDB=/usr/ccs/bin/gdb64
    fi
  fi
  if [ -z "$PROCINTERVAL" ]
  then PROCINTERVAL=1
  fi
  INSTLOC=/var/opt/oracle/oraInst.loc
  ;;
SunOS)
  osversion=`uname -r`
  USE_PSTACK=true
  PSTACK=/usr/bin/pstack
  if [ -z "$PROCINTERVAL" ]
  then PROCINTERVAL=1
  fi
  INSTLOC=/var/opt/oracle/oraInst.loc
  ;;
AIX)
  if [ -z "$USE_PSTACK" ]; then
    if [ -f /bin/procstack ]; then
      USE_PROCSTACK=true
      PROCSTACK=/bin/procstack
    else
      USE_DBX=true
      DBX=/bin/dbx
    fi
 fi
  if [ -z "$PROCINTERVAL" ]
  then PROCINTERVAL=1
  fi
  INSTLOC=/etc/oraInst.loc
  ;;
OSF1)
  if [ -z "$USE_PSTACK" ]; then
    USE_LADEBUG=true
    LADEBUG=/bin/ladebug
  fi
  if [ -z "$PROCINTERVAL" ]
  then PROCINTERVAL=2
  fi
  INSTLOC=/var/opt/oracle/oraInst.loc
  ;;
*)
  echo `date`: "ERROR: Unknown Operating System, Exiting..."
  exit 1;
esac

### Stuff to Use Later...
banner="################################################################################"
preamble1="Thank you for using Procwatcher.  :-)"
preamble2="Please add a comment to Oracle Support Note 459694.1"
preamble3="if you have any comments, suggestions, or issues with this tool."
findprocname='ps -e -o pid,args'
findprocnameuser='ps -e -o pid,user,args'
debugprocs="gdb |pstack |gdb64 |dbx |procstack |ladebug |shortstack start|prw.sh sqlstart|oradebug start"
badlist="grep|$debugprocs|init|COMM|WCHAN|su |ps |sh |strace|sed |crsctl stat res"
HOSTNAME=`hostname | cut -d '.' -f1 | tr "[A-Z]" "[a-z]"`
EXAMINE_CELL=false
EXEDIR="$( cd "$( dirname "$0" )" && pwd )"
SUPPORTEDVERSIONS="9.|10.|11.|12.|18.|19.|20."

### Clusterware Check
if [ `$findprocname | grep ocssd.bin | egrep -v "$badlist" | wc -l` -gt 0 ]; then
  CLUSTERWARE=true
  CRS_HOME_BIN=`$findprocname | grep ocssd.bin | egrep -v "$badlist" | awk '{print $2}' | sed "s@/ocssd.bin@@" | grep -v sed | cut -d ' ' -f1 | head -1`
  CWLOGDIR=`$findprocname | grep ocssd.bin | egrep -v "$badlist" | awk '{print $2}' | sed "s@/bin/ocssd.bin@/log/procwatcher@" | cut -d ' ' -f1 | head -1`
  GRIDLOGDIR=`echo $CWLOGDIR | sed "s@/procwatcher@@" | head -1`
  CRSREGISTERED=false
  if [ `$findprocname | grep "ohasd.b" | grep -v grep | wc -l` -gt 0 ]; then
     if [ `$CRS_HOME_BIN/./crsctl stat res procwatcher | wc -l | tr -d ' '` -gt 2 ]; then
       CRSREGISTERED=true
     fi
  fi
else
  CLUSTERWARE=false
fi

### Set Procwatcher Directory
setprwdir()
{
if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
  set -x
fi

# defaults
if [ "$1" = 'deploy' ] && [ -n "$2" ]; then
  PRWDIR=$2
fi
PRWPERM=764
PRWGROUP=oinstall
if [ -f $INSTLOC ]; then
  if [ `grep inst_group $INSTLOC | wc -l | tr -d ' '` -gt 0 ]; then
    PRWGROUP=`grep inst_group $INSTLOC | cut -d "=" -f2`
  fi
fi

# if prw.sh is running, that is the PRWDIR
if [ `$findprocname | grep "prw.sh run" | grep -v grep | wc -l` -gt 0 ]; then
  tPRWDIR=`$findprocname | grep "prw.sh run" | grep -v grep | awk '{print $3}' | sed "s@/prw.sh@?@" | cut -d '?' -f1 | head -1`
  if [ "$tPRWDIR" = "-x" ]; then
    tPRWDIR=`$findprocname | grep "prw.sh run" | grep -v grep | awk '{print $4}' | sed "s@/prw.sh@?@" | cut -d '?' -f1 | head -1`
  fi
  if [ "$tPRWDIR" != "$CWLOGDIR" ]; then
    PRWDIR=$tPRWDIR
  fi
fi

# create prw temp directory
makeprwtmpdir()
{

if [ ! -d $2 ]; then
  mkdir $2
  chown $1 $2
  chmod $PRWPERM $2
  chgrp $PRWGROUP $2
fi
}

# if prwinit.ora exists in executable dir, check it for PRWDIR param
if [ -z "$PRWDIR" ] && [ -f $EXEDIR/prwinit.ora ]; then
  if [ `cat $EXEDIR/prwinit.ora | grep PRWDIR= | grep -v "#" | wc -l | tr -d ' '` =  1 ]; then
    PRWDIR=`cat $EXEDIR/prwinit.ora | grep PRWDIR= | grep -v "#" | cut -d '=' -f2`
  fi
  if [ `cat $EXEDIR/prwinit.ora | grep PRWPERM= | grep -v "#" | wc -l | tr -d ' '` =  1 ]; then
    PRWPERM=`cat $EXEDIR/prwinit.ora | grep PRWPERM= | grep -v "#" | cut -d '=' -f2`
  fi
  if [ `cat $EXEDIR/prwinit.ora | grep PRWGROUP= | grep -v "#" | wc -l | tr -d ' '` =  1 ]; then
    PRWGROUP=`cat $EXEDIR/prwinit.ora | grep PRWGROUP= | grep -v "#" | cut -d '=' -f2`
  fi
fi

# find a .prwinit file
if [ -r $EXEDIR/.prwinit.ora ]; then
  HPRWINIT=$EXEDIR/.prwinit.ora
else
  HPRWINIT=$HOME/.prwinit.ora
fi

# check for hidden file too in case PRWDIR is somewhere else
if  [ -z "$PRWDIR" ] && [ -f $HPRWINIT ]; then
  if [ `cat $HPRWINIT | grep PRWDIR= | grep -v "#" | wc -l | tr -d ' '` =  1 ]; then
    PRWDIR=`cat $HPRWINIT | grep PRWDIR= | grep -v "#" | cut -d '=' -f2`
  fi
  if [ `cat $EXEDIR/.prwinit.ora | grep PRWPERM= | grep -v "#" | wc -l | tr -d ' '` =  1 ]; then
    PRWPERM=`cat $EXEDIR/.prwinit.ora | grep PRWPERM= | grep -v "#" | cut -d '=' -f2`
  fi
  if [ `cat $EXEDIR/.prwinit.ora | grep PRWGROUP= | grep -v "#" | wc -l | tr -d ' '` =  1 ]; then
    PRWGROUP=`cat $EXEDIR/.prwinit.ora | grep PRWGROUP= | grep -v "#" | cut -d '=' -f2`
  fi
fi

# can't find PRWDIR in prwinit.ora so defaulting location
if [ -z "$PRWDIR" ]; then
 if [ `$findprocname | grep "prw.sh r" | grep -v grep | wc -l | tr -d ' '` -gt 0 ]; then
  if [ "$2" = 'debug' ] ||
  [ `$findprocname | grep "prw.sh r" | grep "\-x" | grep -v grep | wc -l` -gt 0 ]; then
    PRWDIR=`$findprocname | grep "prw.sh r" | grep -v grep | awk '{print $4}' | sed "s@/prw.sh@@"`
  else
    PRWDIR=`$findprocname | grep "prw.sh r" | grep -v grep | awk '{print $3}' | sed "s@/prw.sh@@"`
  fi
 else
  if [ `$findprocname | grep tfa | grep jre | wc -l | tr -d ' '` -gt 0 ]; then
    AHFDIR=`$findprocname | grep tfa | grep jre | awk '{print $2}' | cut -d "/" -f1-3`
    PRWDIR=$AHFDIR/tfa/ext/prw
  elif [ $CLUSTERWARE='true' ] && [ -w "$GRIDLOGDIR" ]; then
    PRWDIR=$CWLOGDIR
  else
    PRWDIR=$EXEDIR
  fi
 fi
else
  if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/prwdir ]; then
    if [ ! -d $PRWDIR/PRW_SYS_$HOSTNAME ]; then
      mkdir -p $PRWDIR/PRW_SYS_$HOSTNAME
      prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME
    fi
    touch $PRWDIR/PRW_SYS_$HOSTNAME/prwdir
    chmod $PRWPERM $PRWDIR/PRW_SYS_$HOSTNAME/prwdir
    chgrp $PRWGROUP $PRWDIR/PRW_SYS_$HOSTNAME/prwdir
  fi
fi
### Make sure there are no duplicates
PRWDIR=`echo $PRWDIR | cut -d ' ' -f1`

### Make Procwatcher Directory if it doesn't exist
if [ ! -d $PRWDIR ]; then
  mkdir -p $PRWDIR
  prwpermissions $PRWDIR
fi
if [ ! -f $PRWDIR/prw.sh ]; then
  cp $EXEDIR/prw.sh $PRWDIR/prw.sh
  prwpermissions $PRWDIR/prw.sh
  chmod u+x $PRWDIR/prw.sh
fi
}

setprwdir

if [ ! -f  $PRWDIR/PRW_SYS_$HOSTNAME/proclist ]; then
  if [ ! -d $PRWDIR/PRW_SYS_$HOSTNAME ]; then
    mkdir -p $PRWDIR/PRW_SYS_$HOSTNAME
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME
  fi
  touch $PRWDIR/PRW_SYS_$HOSTNAME/proclist
  prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/proclist
fi

if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ] && [ "$1" = 'run' ] ; then
  set -x
fi

if [ ! -f $PRWDIR/prwinit.ora ] && [ ! -f $HOME/.prwrelocate ] && [ `$findprocname | grep "prw.sh init" | grep -v grep | wc -l | tr -d ' '` -eq 0 ]; then
  if [ "$1" = 'deploy' ] && [ -n "$2" ]; then
    ksh $EXEDIR/prw.sh init $2 2>&1 &

  else
    ksh $EXEDIR/prw.sh init 2>&1 &
  fi
  sleep 1
fi

### Set parameters
if [ $1 != init ]; then
  for i in 1 2 3 4 5
  do
   if [ `$findprocname | grep "prw.sh init" | grep -v grep | wc -l | tr -d ' '` -gt 0 ]; then
    sleep 1
   fi
  done

## Make variables case insenstive
typeset -l EXAMINE_CLUSTER
typeset -l EXAMINE_BG
typeset -l USE_SQL

# main parameters
# defaults
defEXAMINE_CLUSTER=false
defEXAMINE_BG=true
defPRWGROUP=oinstall
defRETENTION=7
defWARNINGEMAIL=
defINTERVAL=60
defTHROTTLE=5
defIDLECPU=3
defSIDLIST=
# end defaults
for param in EXAMINE_CLUSTER EXAMINE_BG PRWPERM PRWGROUP RETENTION WARNINGEMAIL INTERVAL THROTTLE IDLECPU SIDLIST
do
  if [ `cat $PRWDIR/prwinit.ora | grep $param= | grep -v "#" | wc -l | tr -d ' '` =  1 ]; then
   export $param=`cat $PRWDIR/prwinit.ora | grep $param= | grep -v "#" | cut -d '=' -f2`
  else
   eval $param=\$def$param
   export $param
  fi
done;

# advanced parameters
# defaults
defUSE_SQL=true
defsessionwait=y
deflock=y
deflatchholder=y
defgesenqueue=y
defwaitchains=y
defrmanclient=n
defsqltext=y
defash=y
deferrorstack=n
defsgamemwatch=off
defheapdump_level=0
deflib_cache_dump_level=0
defsuspectprocthreshold=2
defwarningprocthreshold=10
defhanganalyze_level=0
defsystemstate_level=0
defCLUSTERPROCS='"crsd.bin|evmd.bin|evmlogge|racgimon|racge|racgmain|racgons.b|ohasd.b|oraagent|oraroota|gipcd.b|mdnsd.b|gpnpd.b|gnsd.bi|diskmon|octssd.b|tnslsnr"'
defBGPROCS='"_dbw|_smon|_pmon|_lgwr|_lmd|_lms|_lck|_lmon|_ckpt|_arc|_rvwr|_gmon|_lmhb|_rms0"'
defuse_gv=
defuse_pmap=n
defVERSION_10_1=y
defVERSION_10_2=y
defVERSION_11_1=y
defVERSION_11_2=y
defVERSION_12_1=y
defVERSION_12_2=y
defVERSION_18_0=y
defVERSION_19_0=y
defVERSION_20_0=y
defFALL_BACK_TO_OSDEBUGGER=false
defSTACKCOUNT=3
defCUSTOMSQL1=
defCUSTOMSQL2=
defCUSTOMSQL3=
# end defaults
 for param in USE_SQL sessionwait lock latchholder gesenqueue waitchains rmanclient sqltext ash errorstack sgamemwatch heapdump_level lib_cache_dump_level suspectprocthreshold warningprocthreshold hanganalyze_level systemstate_level CLUSTERPROCS BGPROCS use_gv use_pmap VERSION_10_1 VERSION_10_2 VERSION_11_1 VERSION_11_2 VERSION_12_1 VERSION_12_2 VERSION_18_0 VERSION_19_0 VERSION_20_0 FALL_BACK_TO_OSDEBUGGER STACKCOUNT CUSTOMSQL1 CUSTOMSQL2 CUSTOMSQL3
 do
  if [ `cat $PRWDIR/prwinit.ora | grep $param= | grep -v "#" | wc -l | tr -d ' '` =  1 ]; then
    export $param=`cat $PRWDIR/prwinit.ora | grep $param= | grep -v "#" | cut -d '=' -f2`
  else
    eval $param=\$def$param
    export $param
  fi
 done;
fi

### Try to use pstack if we have it
if [ -f /usr/bin/pstack ]; then
  USE_PSTACK=true
  PSTACK=/usr/bin/pstack
fi

ECHO=echo

# SGA mem queries
if [ "$sgamemwatch" = 'diag' ] || [ "$sgamemwatch" = 'avoid4031' ]; then
  MEMsgastat=y
  MEMheapdetails=y
  MEMsgadynamic=y
  MEMtop20sqls=y
  MEMlru=y
else
  MEMsgastat=n
  MEMheapdetails=n
  MEMsgadynamic=n
  MEMtop20sqls=n
  MEMlru=n
fi

# Function to set oratab based on platform
oratabplatform()
{
case $platform in
Linux)
  ORATAB=/etc/oratab
  ;;
HP-UX)
  ORATAB=/etc/oratab
  ;;
SunOS)
  ORATAB=/var/opt/oracle/oratab
  ;;
AIX)
  ORATAB=/etc/oratab
  ;;
OSF1)
  ORATAB=/etc/oratab
  ;;
esac
}

# Set ORATAB
oratabplatform

### Cell check
if [ $EXAMINE_CELL = 'true' ] && [ `$findprocname | grep "/bin/cellsrv " | egrep -v "$badlist" | wc -l` -gt 0 ]; then
  CELL_HOME_BIN=`$findprocname | grep "/bin/cellsrv " | egrep -v "$badlist" | awk '{print $2}' | sed "s@/cellsrv/bin/cellsrv@/cellsrv/bin@" | grep -v sed | cut -d ' ' -f1`
  PRWDIR=/opt/oracle.procwatcher
fi

### BEGIN FUNCTIONS

### Log parameter settings
logparametersettings()
{
if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
  set -x
fi

  ### Log Parameter Settings
  echo `date`: "### Parameters ###"
  echo `date`: "Procwatcher Directory (PRWDIR): $PRWDIR"
  for param in EXAMINE_CLUSTER EXAMINE_BG PRWPERM PRWGROUP RETENTION WARNINGEMAIL INTERVAL THROTTLE IDLECPU SIDLIST
  do
    eval psetting=\$$param
    echo `date`: "$param=$psetting"
  done
  echo `date`: "### Advanced Parameters (non-default) ###"
  for param in USE_SQL sessionwait lock latchholder gesenqueue waitchains rmanclient sqltext ash errorstack sgamemwatch heapdump_level lib_cache_dump_level suspectprocthreshold warningprocthreshold hanganalyze_level systemstate_level CLUSTERPROCS BGPROCS use_gv use_pmap VERSION_10_1 VERSION_10_2 VERSION_11_1 VERSION_11_2 VERSION_12_1 VERSION_12_2 VERSION_18_0 VERSION_19_0 VERSION_20_0 FALL_BACK_TO_OSDEBUGGER STACKCOUNT CUSTOMSQL1 CUSTOMSQL2 CUSTOMSQL3
  do
    defparam=`echo def$param`
    eval dpsetting=\$def$param
    eval psetting=\$$param
    if ([ ! -z "$dpsetting" ] && [ ! -z "$psetting" ]) && [ `echo $psetting | cut -c1-3` = 'def' ]; then
      psetting=$dpsetting
    fi
    if [ "$dpsetting" != "$psetting" ] && ([ ! -z "$dpsetting" ] && [ ! -z "$psetting" ]); then
      echo `date`: "$param=$psetting"
    fi
  done
  echo `date`: "### End Parameters ###"
}

### Capture vmstat
capturevmstat()
{
  echo $DATESECONDS > $PRWDIR/PRW_SYS_$HOSTNAME/lastvmstat
  vmstat 1 2 | egrep "id|0|1|2|3|4|5|6|7|8|9" | grep -v -i System > $PRWDIR/PRW_SYS_$HOSTNAME/vmstat
  prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/vmstat
  cat $PRWDIR/PRW_SYS_$HOSTNAME/vmstat | while read `cat $PRWDIR/PRW_SYS_$HOSTNAME/vmstat | head -1 | sed "s@--@aa@"`
  do
    idle=$id
    if [ $idle != "id" ]; then
      echo $idle > $PRWDIR/PRW_SYS_$HOSTNAME/idlecpu
      prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/idlecpu
    fi
  done
}

### Throttle control - Don't start more debug processes than $THROTTLE or run with < $IDLECPU
### Check if we haven't checked for over 5 seconds
throttlecontrol()
{
  if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/idlecpu ]; then
    echo 99 > $PRWDIR/PRW_SYS_$HOSTNAME/idlecpu
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/idlecpu
  fi
  let DATESECONDS=`date +'%y'`*31556926+`date +'%m'`*2629743+`date +'%d'`*86400+`date +'%H'`*3600+`date +'%M'`*60+`date +'%S'`
  if [ $IDLECPU -gt 0 ]; then
    let timecheck=$DATESECONDS-5
  else
    let timecheck=0
  fi
  if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/lastvmstat` -lt $timecheck ]; then
    capturevmstat
  fi
  sleeptime=5
  while [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/idlecpu` -lt $IDLECPU ]; do
    let DATESECONDS=`date +'%y'`*31556926+`date +'%m'`*2629743+`date +'%d'`*86400+`date +'%H'`*3600+`date +'%M'`*60+`date +'%S'`
    if [ $IDLECPU -gt 0 ]; then
      let timecheck=$DATESECONDS-3
    else
      let timecheck=0
    fi
    if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/lastvmstat` -lt $timecheck ]; then
      capturevmstat
    fi
    if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/idlecpu` -lt $IDLECPU ]; then
      echo `date`: "WARNING: CPU is `cat $PRWDIR/PRW_SYS_$HOSTNAME/idlecpu` % idle - less than $IDLECPU % idle, sleeping $sleeptime seconds"
      if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
        cat $PRWDIR/PRW_SYS_$HOSTNAME/vmstat
      fi
      sleep $sleeptime
    else
      break
    fi
    if [ $sleeptime -lt $INTERVAL ]; then
      let sleeptime=sleeptime*1.5
    else
      let sleeptime=$INTERVAL
    fi
  done
  sleeptime=5
  until [ `ps -e -o args | egrep "$debugprocs" | grep -v grep | wc -l | tr -d ' '` -lt $THROTTLE ]; do
    sleep $PROCINTERVAL
  done
}

### Run this after throttle for big processes or jobs
halfthrottle()
{
  # Half of throttle but round up
  let halfthrottlenum=$THROTTLE/2+1
  until [ `ps -e -o args | egrep "$debugprocs" | grep -v grep | wc -l | tr -d ' '` -lt $halfthrottlenum ]; do
    sleep $PROCINTERVAL
  done
}

### Check for clusterware migration
prwrelocate()
{
  touch $HOME/.prwrelocate
  if [ $CLUSTERWARE = 'true' ] && [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/prwdir ]; then
    CWLOGDIR=`$findprocname | grep ocssd.bin | egrep -v "$badlist" | awk '{print $2}' | sed "s@/bin/ocssd.bin@/log/procwatcher@"`
    GRIDLOGDIR=`echo $CWLOGDIR | sed "s@/procwatcher@@"`
    # Check to see if clusterware moved
    if [ -w $GRIDLOGDIR ] && [ $PRWDIR != $CWLOGDIR ]; then
      ### Clusterware moved
      echo `date`: "Clusteware has moved, relocating Procwatcher directory to $CWLOGDIR"
      cp $EXEDIR/prwinit.ora $CWLOGDIR/prwinit.ora
      prwpermissions $CWLOGDIR/prwinit.ora
      if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
        nohup ksh -x $EXEDIR/prw.sh deploy 2>&1 &
      else
        nohup ksh $EXEDIR/prw.sh deploy 2>&1 &
      fi
      exit
    fi
   fi
   if [ -f $PRWDIR/.prw_masternode ] && [ `$findprocname | grep "ohasd.b" | grep -v grep | wc -l` -gt 0 ] && [ "$CRSREGISTERED" = 'true' ]; then
      # Check to see if # of nodes changed
      NODECOUNT=`$CRS_HOME_BIN/./olsnodes | wc -l | tr -d ' '`
      CARDINALITY=`$CRS_HOME_BIN/crsctl stat res procwatcher -f | grep CARDINALITY= | cut -d '=' -f2`
      if [ $NODECOUNT != $CARDINALITY ]; then
        # Num of nodes changed, redeploy
        if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
          nohup ksh -x $EXEDIR/prw.sh deploy 2>&1 &
        else
          nohup ksh $EXEDIR/prw.sh deploy 2>&1 &
        fi
        exit
      fi
      # Check to see if prw.sh exists on remote nodes
      NODELIST=`$CRS_HOME_BIN/./olsnodes | tr '\n' ' '`
      for prwnode in $NODELIST
      do
        if ssh $prwnode "[ ! -f $PRWDIR/prw.sh ]"
        then
          if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
            nohup ksh -x $EXEDIR/prw.sh deploy 2>&1 &
          else
            nohup ksh $EXEDIR/prw.sh deploy 2>&1 &
          fi
        fi
      done
   fi
}

### To find ORATAB entries
findoratabentry()
{
  OH=
  sidlength=`echo $sid | wc -m | tr -d ' '`
  let sidlength=$sidlength-1
  # Set oratab to platform specific location if there is no $PRWDIR/PRW_SYS_$HOSTNAME/oratab
  if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/oratab ] && [ -z "$ORATAB" ]; then
    ORATAB=$PRWDIR/PRW_SYS_$HOSTNAME/oratab
  else
    oratabplatform
  fi
  # Is there an oratab file?  If not then use default $OH
  if [ ! -f $ORATAB ]; then
    # Use default $OH which may not work...
    OH=$ORACLE_HOME
  else
    until [ $sidlength -eq 1 ]; do
     DBNAME=`echo $DBNAME | cut -c1-$sidlength`
     if [ `grep $DBNAME $ORATAB | grep ":/" | wc -l | tr -d ' '` -eq 1 ]; then
       # Best match
       OH=`grep $DBNAME: $ORATAB | grep ":/" | cut -d ":" -f2`
       break
     elif [ `grep $DBNAME $ORATAB |  grep ":/" | wc -l | tr -d ' '` -gt 1 ]; then
       # Try ignoring commented lines
       if [ `grep $DBNAME $ORATAB |  grep ":/" | grep -v "#" | wc -l | tr -d ' '` -eq 1 ]; then
         # Best match
         OH=`grep $DBNAME $ORATAB |  grep ":/" | grep -v "#" | cut -d ":" -f2`
         break
       fi
       # See if it is ASM
       if [ `grep +$DBNAME $ORATAB |  grep ":/" | wc -l | tr -d ' '` -eq 1 ]; then
         # Best match
         OH=`grep +$DBNAME: $ORATAB | grep ":/" | cut -d ":" -f2`
         break
       fi
       # Found more than 1 entry
       badsid=blahblahblah
       for oratabentry in `grep $DBNAME $ORATAB | cut -d ":" -f1 | grep -v "#"`
       do
         oratabsidlength=`echo $oratabentry | sed s@+@@ | sed s@-MGMTDB@MGMTDB@ | wc -m | tr -d ' '`
         let oratabsidlength=$oratabsidlength-1
         if [ $sidlength -ne $oratabsidlength ]; then
           badsid=$oratabentry"|"$badsid
           badsid=`echo $badsid | sed s@+@@ | sed s@-MGMTDB@MGMTDB@`
         fi
       done
       if [ `grep $DBNAME: $ORATAB | egrep -v "$badsid"  | grep -v "#$DBNAME" | grep -v "#+$DBNAME" | grep -v "#-$DBNAME" | grep ":/" | wc -l | tr -d ' '` -eq 1 ]; then
         # good match
         OH=`grep $DBNAME: $ORATAB  | egrep -v "$badsid" | grep -v "#$DBNAME" | grep -v "#+$DBNAME" | grep -v "#-$DBNAME" | grep ":/" | cut -d ":" -f2`
         break
       fi
     else
       # not found in oratab, check clusterware?
       if [ "$CLUSTERWARE" = 'true' ]; then
         DBRES=ora.$DBNAME.db
         if [ `$CRS_HOME_BIN/crsctl stat res $DBRES -f | grep ORACLE_HOME= | grep -v grep | wc -l | tr -d ' '` -gt 0 ]; then
           OH=`$CRS_HOME_BIN/crsctl stat res $DBRES -f | grep ORACLE_HOME= | grep -v grep | cut -d "=" -f2 | sed 's@=@@`
           break
         fi
       fi
     fi

     let sidlength=sidlength-1
    done
    if [ -z "$OH" ]; then
      # If I couldn't find the home in the oratab use default $OH which may not work...
      OH=$ORACLE_HOME
    fi
  fi
}

### For packing files
prwpack()
{
  if [ -x /usr/bin/zip ] || [ -x $ORACLE_HOME/bin/zip ]; then
    suffix=.zip
    zip $filename.zip $source
  elif [ -x /bin/tar ]; then
    tar cvf $filename.tar $source
    if [ -x /bin/gzip ]; then
      suffix=.tar.gz
      gzip -f $filename.tar
    elif [ -x /bin/compress ]; then
      suffix=.tar.Z
      compress $filename.tar
    else
      suffix=.tar
    fi
  else
    echo `date`: "Could not pack files...please pack them manually."
    exit;
  fi
}

# Check to see if the instance is running
isinstanceup()
{
  isinstanceup=
  sidlength=`echo $sqlsid | wc -m | tr -d ' '`
  let sidlength=$sidlength-1
  until [ $sidlength -eq 1 ]; do
   PMONSIDNAME=`echo $sqlsid | cut -c1-$sidlength`
   if [ `$findprocnameuser | grep "_pmon" | grep $PMONSIDNAME | egrep -v "$badlist" | wc -l | tr -d ' '` -gt 0 ]; then
     badsid=
     for pmonsid in `$findprocnameuser | grep "_pmon" | egrep -v "$badlist" | awk '{print $3}' | sed s@_pmon_@^@ | cut -d "^" -f2`
     do
       pmonsidlength=`echo $pmonsid | sed s@+@@ | sed s@-MGMTDB@MGMTDB@ | wc -m | tr -d ' '`
       let pmonsidlength=$pmonsidlength-1
       if [ $sidlength -ne $pmonsidlength ] && [ `echo $sqlsid | grep $pmonsid | wc -l | tr -d ' '` -lt 1 ];  then 
         if [ -z "$badsid" ]; then
           badsid=$pmonsid
         else
           badsid=$pmonsid"|"$badsid
         fi
       fi
     done
     if [ -z "$badsid" ]; then
       badsid=blahblahblahblah
     else
       badsid=`echo $badsid | sed s@+@@ | sed s@-MGMTDB@MGMTDB@`
     fi
     if [ `$findprocnameuser | grep "_pmon" | grep $PMONSIDNAME | egrep -v "$badsid" | egrep -v "$badlist" | wc -l | tr -d ' '` -eq 1 ]; then
       # good match
       isinstanceup=1
       break
     else
       isinstanceup=0
     fi
   else
     isinstanceup=0
   fi
   let sidlength=sidlength-1
  done
  if [ -z "$isinstanceup" ]; then
     isinstanceup=0
  fi
}

processwarning()
{
 let DATESECONDS=`date +'%y'`*31556926+`date +'%m'`*2629743+`date +'%d'`*86400+`date +'%H'`*3600+`date +'%M'`*60+`date +'%S'`
 if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/warning_$warningsid ]; then
   echo 0 > $PRWDIR/PRW_SYS_$HOSTNAME/warning_$warningsid
   prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/warning_$warningsid
 fi
 LASTWARNING=`cat $PRWDIR/PRW_SYS_$HOSTNAME/warning_$warningsid`
 let DIFFWARNING=$DATESECONDS-$LASTWARNING
 if [ "$warningtype" != "DATABASE CONTENTION" ]; then
  # always warn if not DB contention
  DIFFWARNING=10000
 fi
 # Wait 5 min between contention warnings and only send warning if $WARNINGEMAIL is configured
 if [ -n "$WARNINGEMAIL" ] && [ $DIFFWARNING -gt 300 ]; then
  echo $DATESECONDS > $PRWDIR/PRW_SYS_$HOSTNAME/warning_$warningsid
  mailheader=`echo "PROCWATCHER $warningtype WARNING FOR INSTANCE $warningsid!"`
  mail -s "$mailheader" $WARNINGEMAIL < $warningfile
  echo `date`: "E-MAIL sent to $WARNINGEMAIL : $mailheader"
 fi
}

prwpermissions()
{
prwfile=$1
chmod $PRWPERM $prwfile
chgrp $PRWGROUP $prwfile
}

### END FUNCTIONS

# Starting command line arguments...
case $1 in
'run')

### BEGIN FUNCTIONS
buildinitialsidlist()
{
if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
  set -x
fi

  if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/usersidlist ] && ([ "$EXAMINE_BG" = 'true' ] || [ "$USE_SQL" = 'true' ]); then
    SIDLIST=`cat $PRWDIR/PRW_SYS_$HOSTNAME/usersidlist`
    # Make a bad sidlist (sids we don't want to debug)
    for sid in `$findprocnameuser | grep "_pmon" | grep -v "$SIDLIST" | egrep -v "$badlist" | awk '{print $3}' | sed s@_pmon_@^@ | cut -d "^" -f2`
    do
        sid=`echo $sid | sed s@+@@ | sed s@-MGMTDB@MGMTDB@ | grep -v sed`
        BADSIDLIST="$BADSIDLIST""|""$sid"
    done
  elif [ ! -f  $PRWDIR/PRW_SYS_$HOSTNAME/usersidlist ] && ([ "$EXAMINE_BG" = 'true' ] || [ "$USE_SQL" = 'true' ]); then
    SIDLIST=
    BADSIDLIST=
    userstring="_pmon"
    if [ "$user" != 'root' ]
      then
      ### Only get SIDs for this user
      userstring="$user"
    fi
    # Make a good sidlist (sids we want to debug)
    for sid in `$findprocnameuser | grep "_pmon" | grep "$userstring" | egrep -v "$badlist" | awk '{print $3}' | sed s@_pmon_@^@ | cut -d "^" -f2`
      do
        sid=`echo $sid | sed s@+@@ | sed s@-MGMTDB@MGMTDB@ | grep -v sed`
        SIDLIST="$SIDLIST""|""$sid"
    done
    # Make a bad sidlist (sids we don't want to debug)
    for sid in `$findprocnameuser | grep "_pmon" | grep -v "$userstring" | egrep -v "$badlist" | awk '{print $3}' | sed s@_pmon_@^@ | cut -d "^" -f2`
    do
        sid=`echo $sid | sed s@+@@ | sed s@-MGMTDB@MGMTDB@ | grep -v sed`
        BADSIDLIST="$BADSIDLIST""|""$sid"
    done
    if [ ! -z "$SIDLIST" ]; then
      sidlistlength=`echo $SIDLIST | wc -m | tr -d ' '`
      if [ $sidlistlength -gt 2 ]; then
        SIDLIST=`echo $SIDLIST | cut -c2-$sidlistlength | tr "+" " " | tr "-" " " | grep -v sed`
      else
        SIDLIST=
      fi
    fi
    if [ ! -z "$BADSIDLIST" ]; then
      badsidlistlength=`echo $BADSIDLIST | wc -m | tr -d ' '`
      if [ $badsidlistlength -gt 2 ]; then
        BADSIDLIST=`echo $BADSIDLIST | cut -c2-$badsidlistlength | tr "+" " " | tr "-" " " | grep -v sed`
      else
        BADSIDLIST=
      fi
    fi
  fi
}

# Function to build the oratab, check the DB version, filter, and save the SIDLIST
filtersidlist()
{
if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
  set -x
fi

  ### Build procwatcher oratab
  if [ "$USE_SQL" = 'true' ] || [ "$EXAMINE_BG" = 'true' ]; then
  if [ -n "$SIDLIST" ]; then
   if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/oratab ]; then
     rm -f $PRWDIR/PRW_SYS_$HOSTNAME/oratab
   fi
   for sid in `echo $SIDLIST | tr "|" " "`
   do
    DBNAME=$sid
    oratabplatform
    findoratabentry
    echo $sid":"$OH >> $PRWDIR/PRW_SYS_$HOSTNAME/oratab

   if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/oratab ]; then
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/oratab
   fi

   ### Get DB version
     sqlsid=$sid
     isinstanceup
     if [ $isinstanceup -gt 0 ]; then
      if [ "$USE_SQL" = 'true' ] || [ "$EXAMINE_BG" = 'true' ]; then
       echo `date`: "Checking DB version for SID $sid"
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/version_$sid ]; then
           rm -f $PRWDIR/PRW_SYS_$HOSTNAME/version_$sid
         fi
         throttlecontrol
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
           ksh -x $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLvinstance $user $sid $OH 
         else
           ksh $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLvinstance $user $sid $OH 
         fi
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/procinterval ]; then
         sleep $PROCINTERVAL
         fi

         # Give it a chance for version info to show up
         for n in 1 2 3 4 5 6 7 8 9 10
         do
           if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLvinstance$sid.out ]; then
             if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLvinstance$sid.out | grep DBVERSION | wc -l` -eq 0 ]; then
               sleep $PROCINTERVAL
             else
               break
             fi
           else
               sleep $PROCINTERVAL
           fi
         done

         ### Save version info
        for n in 1 2 3 4 5 6 7 8 9 10
        do
         if [ `grep "DBVERSION" $PRWDIR/PRW_SYS_$HOSTNAME/SQLvinstance$sid.out | awk '{print $2}' | wc -l` -lt 1 ]; then
           sleep $PROCINTERVAL 
         else
            break
         fi
        done
         grep "DBVERSION" $PRWDIR/PRW_SYS_$HOSTNAME/SQLvinstance$sid.out | awk '{print $2}' > $PRWDIR/PRW_SYS_$HOSTNAME/version_$sid
         prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/version_$sid
         if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/version_$sid | egrep $SUPPORTEDVERSIONS | wc -l` -gt 0 ]; then
           echo `date`: "DB Version for SID $sid is "`cat $PRWDIR/PRW_SYS_$HOSTNAME/version_$sid`
         fi
         if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/version_$sid | egrep $SUPPORTEDVERSIONS | wc -l` -eq 0 ]; then
           echo `date`: "WARNING: Could not get version info for SID $sid..."
           echo `date`: "There may be an environment or install issue."
         fi
      fi
     fi

     ### Create PRW Directory and External Table if it doesn't exist
     if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/ppids ]; then
       touch $PRWDIR/PRW_SYS_$HOSTNAME/ppids
       prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/ppids
     fi
     if [ `echo $sid | cut -c1-3` != 'ASM' ] && [ `echo $sid | cut -c1-3` != 'APX' ] && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/version_$sid | egrep $SUPPORTEDVERSIONS | wc -l` -gt 0 ] && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/ppids | grep "SQLprocwatcher_pids$sid " | wc -l | tr -d ' '` -eq 0 ]; then
      throttlecontrol
      if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
        ksh -x $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLdrop_procwatcher_pids $user $sid $OH 2>&1
        sleep 1
        nohup ksh -x $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLprocwatcher_pids $user $sid $OH 2>&1
      else
        ksh $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLdrop_procwatcher_pids $user $sid $OH 2>&1 &
        sleep 1
        nohup ksh $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLprocwatcher_pids $user $sid $OH 2>&1 &
      fi
      if [ "$sgamemwatch" = 'avoid4031' ]; then
        # Clearing LRU count since sgamemwatch=avoid4031
        if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
          ksh -x $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMlru $user $sid $OH 2>&1
        else
          ksh $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMlru $user $sid $OH 2>&1
        fi
      fi
     fi
   done
  fi

    ### Filter SIDLIST based on version
    NEWSIDLIST=
    for sid in `echo $SIDLIST | tr "|" " "`
    do
     if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/version_$sid ]; then
      if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/version_$sid | wc -l` -gt 0 ]; then
       ver1=`cat $PRWDIR/PRW_SYS_$HOSTNAME/version_$sid | cut -d "." -f1`
       ver2=`cat $PRWDIR/PRW_SYS_$HOSTNAME/version_$sid | cut -d "." -f2`
       version=`echo $ver1"_"$ver2`
       if [ "$version" = '10_1' ] && [ "$VERSION_10_1" = 'y' ]; then
        goodsid=true
       elif [ "$version" = '10_2' ] && [ "$VERSION_10_2" = 'y' ]; then
        goodsid=true
       elif [ "$version" = '11_1' ] && [ "$VERSION_11_1" = 'y' ]; then
        goodsid=true
       elif [ "$version" = '11_2' ] && [ "$VERSION_11_2" = 'y' ]; then
        goodsid=true
       elif [ "$version" = '12_1' ] && [ "$VERSION_12_1" = 'y' ]; then
        goodsid=true
       elif [ "$version" = '12_2' ] && [ "$VERSION_12_2" = 'y' ]; then
        goodsid=true
       elif [ "$version" = '18_0' ] && [ "$VERSION_18_0" = 'y' ]; then
        goodsid=true
       elif [ "$version" = '19_0' ] && [ "$VERSION_19_0" = 'y' ]; then
        goodsid=true
       elif [ "$version" = '20_0' ] && [ "$VERSION_20_0" = 'y' ]; then
        goodsid=true
       else
        goodsid=false
       fi
      else
        goodsid=false
      fi
     else
        goodsid=false
     fi
     if [ "$goodsid" = 'true' ]; then
       if [ -z "$NEWSIDLIST" ]; then
         NEWSIDLIST=$sid
       else
         NEWSIDLIST=$sid"|"$NEWSIDLIST
       fi
     elif [ "$goodsid" = 'false' ]; then
       if [ ! -z "$BADSIDLIST" ]; then
         BADSIDLIST=$sid"|"$BADSIDLIST
       else
         BADSIDLIST=$sid
       fi
     fi
    done
  fi

  # Save the $SIDLIST
  echo "$NEWSIDLIST" > $PRWDIR/PRW_SYS_$HOSTNAME/sidlist
  prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/sidlist
  echo "$BADSIDLIST" > $PRWDIR/PRW_SYS_$HOSTNAME/badsidlist
  prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/badsidlist

  if [ `echo $NEWSIDLIST | wc -m | tr -d ' '` != `echo $SIDLIST | wc -m | tr -d ' '` ]; then
    echo `date`: "Adjusting SIDLIST after version check"
    echo `date`: "SIDLIST=$NEWSIDLIST"
  fi

  SIDLIST=$NEWSIDLIST

  ### Make DB_SID dir and check for RAC
  for sid in `echo $SIDLIST | tr "|" " "`
  do
    if [ ! -d $PRWDIR/PRW_DB_$sid ]
      then mkdir $PRWDIR/PRW_DB_$sid
      prwpermissions $PRWDIR/PRW_DB_$sid
      echo `date`: "Created "$PRWDIR/PRW_DB_$sid" directory"
    fi
    # Find out if it is RAC
    if [ `ps -e -o args | grep "_lmd0" | egrep -v "$badlist" | wc -l | tr -d ' '` -gt 0 ]; then
       echo "true" > $PRWDIR/PRW_SYS_$HOSTNAME/israc_$sid
    else
       echo "false" > $PRWDIR/PRW_SYS_$HOSTNAME/israc_$sid
    fi
       prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/israc_$sid
  done
}

### END FUNCTIONS

  echo $banner
  echo `date`: "Procwatcher Version $VERSION starting on "$platform
  if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
    echo `date`: KSH Version:
    ksh --version
  fi
  echo $banner
  echo `date`: $preamble1
  echo `date`: $preamble2
  echo `date`: $preamble3
  echo $banner

  let DATESECONDS=`date +'%y'`*31556926+`date +'%m'`*2629743+`date +'%d'`*86400+`date +'%H'`*3600+`date +'%M'`*60+`date +'%S'`
  echo $DATESECONDS > $PRWDIR/PRW_SYS_$HOSTNAME/prwinterval
  prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/prwinterval

  if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/lastvmstat ]; then
    echo "0" > $PRWDIR/PRW_SYS_$HOSTNAME/lastvmstat
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/lastvmstat
  fi

  if [ "$USE_SQL" != 'true' ]; then
    echo "false" > $PRWDIR/PRW_SYS_$HOSTNAME/usesql
  else
    echo "true" > $PRWDIR/PRW_SYS_$HOSTNAME/usesql
  fi
  prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/*sql

  if [ "$EXAMINE_BG" != 'true' ]; then
    echo "false" > $PRWDIR/PRW_SYS_$HOSTNAME/examinebg
  else
    echo "true" > $PRWDIR/PRW_SYS_$HOSTNAME/examinebg
  fi
  prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/examinebg

  echo "true" > $PRWDIR/PRW_SYS_$HOSTNAME/shortstack
  prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/shortstack

  if [ $EXAMINE_CELL = 'true' ]; then
    touch $PRWDIR/PRW_SYS_$HOSTNAME/exadatacells
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/exadatacells
  fi

  ### Find user
  user=`id | cut -d "(" -f2 | cut -d ")" -f1`
  echo `date`: "Procwatcher running as user "$user
  echo "$user" > $PRWDIR/PRW_SYS_$HOSTNAME/user
  prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/user

  if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
    nohup ksh -x $EXEDIR/prw.sh sqlbuilder >> $PRWDIR/prw_$HOSTNAME.log 2>&1
  else
    nohup ksh $EXEDIR/prw.sh sqlbuilder >> $PRWDIR/prw_$HOSTNAME.log 2>&1 &
  fi

  if [ ! -z "$SIDLIST" ]; then
    echo "$SIDLIST" > $PRWDIR/PRW_SYS_$HOSTNAME/usersidlist
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/usersidlist
  fi

  # Build initial sidlist
  buildinitialsidlist

  # Log the parameter settings
  logparametersettings

  # Filter the sidlist (add to procwatcher oratab, check version, etc...)
  filtersidlist

  if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/shortstack` = 'true' ]; then
    echo `date`: "Using oradebug short_stack to speed up DB stack times..."
  fi

  ### We Found Our Debugger and Are Happy
 if [ $EXAMINE_CLUSTER = 'true' ] || [ $EXAMINE_CELL = 'true' ] || [ $FALL_BACK_TO_OSDEBUGGER = 'true' ]; then
  if [ "$USE_PSTACK" = 'true' ] && [ -f "$PSTACK" ]
    then echo `date`: "Going to use pstack for debugging if we can't use short_stack"
  fi
  if [ "$USE_GDB" = 'true' ] && [ -f "$GDB" ]
    then echo `date`: "Going to use gdb for debugging if we can't use short_stack"
  fi
  if [ "$USE_DBX" = 'true' ] && [ -f "$DBX" ]
    then echo `date`: "Going to use dbx for debugging if we can't use short_stack"
  fi
  if [ "$USE_LADEBUG" = 'true' ] && [ -f "$LADEBUG" ]
    then echo `date`: "Going to use ladebug for debugging if we can't use short_stack"
  fi
  if [ "$USE_PROCSTACK" = 'true' ] && [ -f "$PROCSTACK" ]
    then echo `date`: "Going to use procstack for debugging if we can't use short_stack"
  fi
 fi

  ### Uh Oh We Can't Find Our Debugger...
  if [ "$USE_PSTACK" = 'true' ] && [ ! -f "$PSTACK" ] && [ $EXAMINE_CLUSTER = 'true' ] || [ $EXAMINE_CELL = 'true' ]
    then echo `date`: "Trying to find pstack..."
    PSTACK=`which pstack`
    if [ -f "$PSTACK" ]
      then echo `date`: "Found pstack, will use it..."
    else
      echo `date`: "ERROR: I can't find pstack, exiting..."
      exit 1;
    fi
  fi
  if [ "$USE_GDB" = 'true' ] && [ ! -f "$GDB" ] && [ $EXAMINE_CLUSTER = 'true' ] || [ $EXAMINE_CELL = 'true' ]
    then echo `date`: "Trying to find gdb..."
    GDB=`which gdb`
    if [ -f "$GDB" ]
      then echo `date`: "Found gdb, will use it..."
    else
      if [ -f /opt/langtools/bin/gdb ]; then
        GDB=/opt/langtools/bin/gdb
        echo `date`: "Found gdb, will use it..."
      else
      echo `date`: "ERROR: I can't find gdb, exiting..."
      exit 1;
      fi
    fi
  fi
  if [ "$USE_DBX" = 'true' ] && [ ! -f "$DBX" ] && [ $EXAMINE_CLUSTER = 'true' ]
    then echo `date`: "Trying to find dbx..."
    DBX=`which dbx`
    if [ -f "$DBX" ]
      then echo `date`: "Found dbx, will use it..."
    else
      echo `date`: "ERROR: I can't find dbx, exiting..."
      exit 1;
    fi
  fi
  if [ "$USE_LADEBUG" = 'true' ] && [ ! -f "$LADEBUG" ] && [ $EXAMINE_CLUSTER = 'true' ]
    then echo `date`: "Trying to find ladebug..."
    LADEBUG=`which ladebug`
    if [ -f "$LADEBUG" ]
      then echo `date`: "Found ladebug, will use it..."
    else
      echo `date`: "ERROR: I can't find ladebug, exiting..."
      exit 1;
    fi
  fi

  ### Debugger Options...
  if [ "$USE_GDB" = 'true' ]
    then if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/prw_gdb.cmd ]
      then rm $PRWDIR/PRW_SYS_$HOSTNAME/prw_gdb.cmd
    fi
    echo "set height 0" >> $PRWDIR/PRW_SYS_$HOSTNAME/prw_gdb.cmd
    echo "thread apply all bt" >> $PRWDIR/PRW_SYS_$HOSTNAME/prw_gdb.cmd
    echo "detach" >> $PRWDIR/PRW_SYS_$HOSTNAME/prw_gdb.cmd
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/prw_gdb.cmd
    chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/prw_gdb.cmd 
    if [ $platform = "Linux" ]
      then
      if $GDB -nx --quiet --batch --readnever > /dev/null 2>&1; then
        readnever=--readnever
      else
        readnever=
      fi
    fi
  fi
  if [ "$USE_LADEBUG" = 'true' ]
    then if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/prw_iladebug.cmd ] || [ -f $PRWDIR/PRW_SYS_$HOSTNAME/prw_cladebug.cmd ]
      then rm $PRWDIR/PRW_SYS_$HOSTNAME/prw_iladebug.cmd
      rm $PRWDIR/PRW_SYS_$HOSTNAME/prw_cladebug.cmd
    fi
    echo "set "$"stoponattach=1" >> $PRWDIR/PRW_SYS_$HOSTNAME/prw_iladebug.cmd
    echo "where thread all" >> $PRWDIR/PRW_SYS_$HOSTNAME/prw_cladebug.cmd
    echo "detach" >> $PRWDIR/PRW_SYS_$HOSTNAME/prw_cladebug.cmd
    echo "quit" >> $PRWDIR/PRW_SYS_$HOSTNAME/prw_cladebug.cmd
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/prw_iladebug.cmd
    chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/prw_iladebug.cmd
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/prw_cladebug.cmd
    chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/prw_cladebug.cmd
  fi
  if [ "$USE_DBX" = 'true' ]
    then if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/prw_dbx.cmd ]
      then rm $PRWDIR/PRW_SYS_$HOSTNAME/prw_dbx.cmd
    fi
    echo "where" >> $PRWDIR/PRW_SYS_$HOSTNAME/prw_dbx.cmd
    echo "detach" >> $PRWDIR/PRW_SYS_$HOSTNAME/prw_dbx.cmd
    echo "quit" >> $PRWDIR/PRW_SYS_$HOSTNAME/prw_dbx.cmd
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/prw_dbx.cmd
    chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/prw_dbx.cmd
  fi

  ### Can't debug CRS or Cell if not root or its not running...
  if [ $EXAMINE_CLUSTER = 'true' ] || [ $EXAMINE_CELL = 'true' ]; then
    ohasduser=`$findprocnameuser | grep "ohasd.bin" | egrep -v "$badlist" | awk '{print $2}'`
    if [ "$user" != "root" ] && [ "$ohasduser" = "root" ]; then
      if [ $EXAMINE_CLUSTER = 'true' ]; then
        echo `date`: "WARNING: Can't debug cluster since we are not running as root..."
        EXAMINE_CLUSTER='false'
      else
        echo `date`: "WARNING: Can't debug cell nodes since we are not running as root..."
        EXAMINE_CELL='false'
      fi
    elif [ $EXAMINE_CLUSTER = 'true' ] && [ `$findprocname | grep ocssd.bin | egrep -v "$badlist" | wc -l` -eq 0 ]
      then echo `date`: "WARNING: Couldn't find running cluster so can't debug cluster..."
      EXAMINE_CLUSTER='false'
    elif [ $EXAMINE_CELL = 'true' ] && [ `$findprocname | grep "bin/cellsrv " | egrep -v "$badlist" | wc -l` -eq 0 ]
      then echo `date`: "Cell Server not running here.  Will not debug cell here."
      EXAMINE_CELL='false'
    fi
  fi

  ### Make the $PRWDIR/PRW_CLUSTER dir if it's not already there...
  if [ $EXAMINE_CLUSTER = 'true' ]
    then
    if [ ! -d $PRWDIR/PRW_CLUSTER ]
      then mkdir $PRWDIR/PRW_CLUSTER
      echo `date`: "Created $PRWDIR/PRW_CLUSTER directory"
      prwpermissions $PRWDIR/PRW_CLUSTER
    fi
  fi

  ### Make the $PRWDIR/PRW_CELL dir if it's not already there...
  if [ $EXAMINE_CELL = 'true' ]
    then
    if [ ! -d $PRWDIR/PRW_CELL ]
      then mkdir $PRWDIR/PRW_CELL
      echo `date`: "Created $PRWDIR/PRW_CELL directory"
      prwpermissions $PRWDIR/PRW_CELL
    fi
  fi

  ### Start the Main Loop
  while [ 1 -ne 0 ]; do

   ### Start Housekeeper if it isn't already running
   if [ `ps -e -o args | grep "prw.sh housekeeper" | egrep -v "grep|COMM" | wc -l | tr -d ' '` -eq 0 ]; then
     ksh $EXEDIR/prw.sh starthousekeeper
   fi

   if [ $EXAMINE_CLUSTER = 'true' ]
    then
     ### Collect crsstat output
     echo `date`: "Getting crsstat output (in "$PRWDIR/PRW_CLUSTER/prw_"$HOSTNAME"_crsstat_`date +"%m-%d-%y"`.out")"
     if [ ! -f $PRWDIR/PRW_CLUSTER/prw_"$HOSTNAME"_crsstat_`date +"%m-%d-%y"`.out ]; then
       touch $PRWDIR/PRW_CLUSTER/prw_"$HOSTNAME"_crsstat_`date +"%m-%d-%y"`.out
       prwpermissions $PRWDIR/PRW_CLUSTER/prw_"$HOSTNAME"_crsstat_`date +"%m-%d-%y"`.out
     fi
     echo $banner >> $PRWDIR/PRW_CLUSTER/prw_"$HOSTNAME"_crsstat_`date +"%m-%d-%y"`.out
     date >> $PRWDIR/PRW_CLUSTER/prw_"$HOSTNAME"_crsstat_`date +"%m-%d-%y"`.out
     if [ `$findprocname | grep "ohasd.b" | grep -v grep | wc -l` -gt 0 ]; then
       $CRS_HOME_BIN/./crsctl stat res -t -init >> $PRWDIR/PRW_CLUSTER/prw_"$HOSTNAME"_crsstat_`date +"%m-%d-%y"`.out
       $CRS_HOME_BIN/./crsctl stat res -t >> $PRWDIR/PRW_CLUSTER/prw_"$HOSTNAME"_crsstat_`date +"%m-%d-%y"`.out &
     else
       $CRS_HOME_BIN/./crs_stat >> $PRWDIR/PRW_CLUSTER/prw_"$HOSTNAME"_crsstat_`date +"%m-%d-%y"`.out &
     fi
   fi

   if [ $EXAMINE_CELL = 'true' ] && [ `$findprocname | grep "/bin/cellsrv " | egrep -v "$badlist" | wc -l` -gt 0 ];
   then
     CELL_HOME_BIN=`$findprocname | grep "/bin/cellsrv " | egrep -v "$badlist" | awk '{print $2}' | sed "s@/cellsrv/bin/cellsrv@/cellsrv/bin@" | grep -v sed | cut -d ' ' -f1`
     ### Collect cell output
     for cellgather in griddisk celldisk flashcache
     do
       echo `date`: "Getting $cellgather output (in "$PRWDIR/PRW_CELL/pw_"$HOSTNAME"_"$cellgather"_`date +"%m-%d-%y"`.out")"
       if [ ! -f $PRWDIR/PRW_CELL/pw_"$HOSTNAME"_"$cellgather"_`date +"%m-%d-%y"`.out ]; then
         touch $PRWDIR/PRW_CELL/pw_"$HOSTNAME"_"$cellgather"_`date +"%m-%d-%y"`.out
         prwpermissions $PRWDIR/PRW_CELL/pw_"$HOSTNAME"_"$cellgather"_`date +"%m-%d-%y"`.out
       fi
       echo $banner >> $PRWDIR/PRW_CELL/pw_"$HOSTNAME"_"$cellgather"_`date +"%m-%d-%y"`.out
       date >> $PRWDIR/PRW_CELL/pw_"$HOSTNAME"_"$cellgather"_`date +"%m-%d-%y"`.out
       echo `date`: "Collecting $cellgather output with: 'cellcli -e list $cellgather detail'"
       $CELL_HOME_BIN/cellcli -e list $cellgather detail >> $PRWDIR/PRW_CELL/pw_"$HOSTNAME"_"$cellgather"_`date +"%m-%d-%y"`.out
     done
   fi

   ### Find out which processes to debug...
   SIDLIST=`cat $PRWDIR/PRW_SYS_$HOSTNAME/sidlist`

   ### See if we need to adjust the SIDLIST
   numrunningsids=`$findprocnameuser | grep "_pmon" | egrep -v "$badlist" | awk '{print $3}' | sed s@_pmon_@^@ | cut -d "^" -f2 | wc -w | tr -d ' '`
   numknownsids=`echo $SIDLIST $BADSIDLIST |  tr "|" " " | wc -w | tr -d ' '`
   if [ $numrunningsids -ne $numknownsids ] && [ $EXAMINE_BG = 'true' ]; then
     # Rebuild sidlist
     echo `date`: "New SID found running, re-building SIDLIST"
     if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/examinebg` = 'true' ]; then
       EXAMINE_BG=true
     fi
     buildinitialsidlist
     filtersidlist
   fi

   if [ $EXAMINE_CELL = 'true' ]; then
     CELLPROCS=`$findprocname | grep $CELL_HOME_BIN | egrep -v "$badlist" | awk '{print $2}' | sed "s@$CELL_HOME_BIN/@@" | egrep -v "sed|bash" | tr -d '$' | sed "s@ @|@g"`
   fi
   if [ -z "$SIDLIST" ] && [ $EXAMINE_CLUSTER != 'true' ] && [ $EXAMINE_CELL != 'true' ]; then
     EXAMINE_BG=false
     echo `date`: "Couldn't find any SIDs to debug..."
     if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/proclist | wc -l` -gt 0 ]; then
       cat /dev/null > $PRWDIR/PRW_SYS_$HOSTNAME/proclist
     fi
   fi
   if [ $EXAMINE_CLUSTER = 'true' ] && [ $EXAMINE_CELL != 'true' ]
    then proclist=$CLUSTERPROCS
    sidprocs="$proclist"
   elif [ $EXAMINE_CELL = 'true' ]
    then proclist=$CELLPROCS
    sidprocs="$proclist"
   elif [ $USE_SQL = 'false' ] && [ $EXAMINE_BG = 'false' ]; then
    echo `date`: "ERROR: No processes to debug..."
    echo `date`: "Sleeping until the next INTERVAL ($INTERVAL seconds)"
    if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/proclist | wc -l` -gt 0 ]; then
      cat /dev/null > $PRWDIR/PRW_SYS_$HOSTNAME/proclist
    fi
    sleep $INTERVAL
    continue
   fi

   # Remove previous SQL output files
   if [ "$USE_SQL" = 'true' ] && [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQL | grep out | wc -l | tr -d ' '` -gt 0 ] \
   && [ `ps -e -o args | egrep "$debugprocs|prw.sh sqlrun" | grep prw | grep -v grep | wc -l | tr -d ' '` -eq 0 ]; then
     rm -f $PRWDIR/PRW_SYS_$HOSTNAME/SQL*out
   fi

   ### First SID Loop
   for sqlsid in `cat $PRWDIR/PRW_SYS_$HOSTNAME/sidlist | tr "|" " "`
     do
     if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/usesql_$sqlsid ]; then
       cp $PRWDIR/PRW_SYS_$HOSTNAME/usesql $PRWDIR/PRW_SYS_$HOSTNAME/usesql_$sqlsid
       prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/usesql_$sqlsid
     fi
     if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/shortstack_$sqlsid ]; then
       cp $PRWDIR/PRW_SYS_$HOSTNAME/shortstack $PRWDIR/PRW_SYS_$HOSTNAME/shortstack_$sqlsid
     fi
     if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/stackcount_$sqlsid ]; then
       echo $STACKCOUNT > $PRWDIR/PRW_SYS_$HOSTNAME/stackcount_$sqlsid
       prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/stackcount_$sqlsid
     fi
     if [ ! -d $PRWDIR/PRW_DB_$sqlsid ]
       then mkdir $PRWDIR/PRW_DB_$sqlsid
       echo `date`: "Created "$PRWDIR/PRW_DB_$sqlsid" directory"
       prwpermissions $PRWDIR/PRW_DB_$sqlsid
     fi

     ### Find the SID from the prw oratab and set the $OH
     if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/oratab ] && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/oratab | grep $sqlsid | wc -l` -gt 0 ]
       then
         sid=$sqlsid
         DBNAME=$sid
         ORATAB=$PRWDIR/PRW_SYS_$HOSTNAME/oratab
         findoratabentry
     fi

     isinstanceup
     if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/usesql_$sqlsid` = 'true' ] && [ $isinstanceup -gt 0 ]
     then
       echo `date`: "Collecting SQL Data for SID $sqlsid"

       ### Run v$wait_chains and use v$ views if 11g or higher
       if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/version_$sqlsid ]; then
       if [ `egrep $SUPPORTEDVERSIONS $PRWDIR/PRW_SYS_$HOSTNAME/version_$sqlsid | wc -l` -gt 0 ]; then
        if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/version_$sqlsid | cut -d "." -f1` -gt 10 ] && [ "$waitchains" = 'y' ]; then
         # If use_gv is not set and we use waitchains, don't use gv$ views
         if [ -z "$use_gv" ]; then
           echo "v" > $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$sqlsid
         fi
         throttlecontrol
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
           if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/version_$sqlsid | cut -d "." -f1-2` -eq "11.1" ] || \
           [ -f $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_"$sqlsid"SQLvwaitchains ]; then
             ksh -x $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLv111waitchains $user $sqlsid $OH 2>&1
           else
             ksh -x $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLvwaitchains $user $sqlsid $OH 2>&1
           fi
         else
           if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/version_$sqlsid | cut -d "." -f1-2` -eq "11.1" ] || \
           [ -f $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_"$sqlsid"SQLvwaitchains ]; then
             ksh $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLv111waitchains $user $sqlsid $OH 2>&1
           else
             ksh $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLvwaitchains $user $sqlsid $OH 2>&1
           fi
         fi
        fi
       fi
       fi

       ### Determine view type and create viewtype file if it doesn't exist
       if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/israc_$sqlsid` = true ] && [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$sqlsid ] && [ "$use_gv" != "n" ]; then
         echo "gv" > $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$sqlsid
         prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$sqlsid
       else
         echo "v" > $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$sqlsid
         prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$sqlsid
       fi

       if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$sqlsid` = 'gv' ]; then
         filelist="$PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMlru $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvsessionwait $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvlock $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvlatchholder $PRWDIR/PRW_SYS_$HOSTNAME/SQLrmanclient $PRWDIR/PRW_SYS_$HOSTNAME/SQLpgamemory $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgastat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMheapdetails $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgadynamic $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMtop20sqls $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom1 $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom2 $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom3"
       else
         filelist="$PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMlru $PRWDIR/PRW_SYS_$HOSTNAME/SQLvsessionwait $PRWDIR/PRW_SYS_$HOSTNAME/SQLvlock $PRWDIR/PRW_SYS_$HOSTNAME/SQLvlatchholder $PRWDIR/PRW_SYS_$HOSTNAME/SQLrmanclient $PRWDIR/PRW_SYS_$HOSTNAME/SQLpgamemory $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgastat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMheapdetails $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgadynamic $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMtop20sqls $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom1 $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom2 $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom3"
       fi

      if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep waitchains | grep $sqlsid | grep out | wc -l | tr -d ' '` -gt 0 ]; then
       if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*waitchains*$sqlsid* | grep PROC | grep INST | wc -l | tr -d ' '` -lt $suspectprocthreshold ]; then
         filelist="$PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMlru $PRWDIR/PRW_SYS_$HOSTNAME/SQLrmanclient $PRWDIR/PRW_SYS_$HOSTNAME/SQLpgamemory $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgastat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMheapdetails $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgadynamic $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMtop20sqls $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom1 $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom2 $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom3"
       fi
      fi

       # Loop to run first set of SQLs
       for sqlfile in $filelist
       do
         sqlname=`echo $sqlfile | sed 's@'$PRWDIR'/PRW_SYS_'$HOSTNAME'/@@' | sed 's@SQLgv@@' | sed 's@SQLv@@' | sed 's@SQL@@'`

         # Make sure SQL is enabled
         if [ "$sqlname" = 'MEMlru' ] && [ "$MEMlru" != 'y' ]; then
           continue
         elif [ "$sqlname" = 'sessionwait' ] && [ "$sessionwait" != 'y' ]; then
           continue
         elif [ "$sqlname" = 'lock' ] && [ "$lock" != 'y' ]; then
           continue
         elif  [ "$sqlname" = 'latchholder' ] && [ "$latchholder" != 'y' ]; then
           continue
         elif [ "$sqlname" = 'rmanclient' ] && [ "$rmanclient" != 'y' ]; then
           continue
         elif [ "$sqlname" = 'pgamemory' ] && [ "$process_memory" != 'y' ]; then
           continue
         elif [ "$sqlname" = 'custom1' ] && ([ -z "$CUSTOMSQL1" ] || [ ! -x "$CUSTOMSQL1" ]); then
           continue
         elif [ "$sqlname" = 'custom2' ] && ([ -z "$CUSTOMSQL2" ] || [ ! -x "$CUSTOMSQL2" ]); then
           continue
         elif [ "$sqlname" = 'custom3' ] && ([ -z "$CUSTOMSQL3" ] || [ ! -x "$CUSTOMSQL3" ]); then
           continue
         elif [ "$sqlname" = 'MEMsgadynamic' ] && [ "$MEMsgadynamic" != 'y' ]; then
           continue
         elif [ "$sqlname" = 'MEMsgastat' ] && [ "$MEMsgastat" != 'y' ]; then
           continue
         elif [ "$sqlname" = 'MEMheapdetails' ] && [ "$MEMheapdetails" != 'y' ]; then
           continue
         elif [ "$sqlname" = 'MEMtop20sqls' ] && [ "$MEMtop20sqls" != 'y' ]; then
           continue
         fi

         if [ "$sqlname" = 'custom1' ]; then
           if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom1 ]; then
             echo "set timing on" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom1.sql
             cat $CUSTOMSQL1 >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom1.sql
           fi
           sqlname=$PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom1
         elif [ "$sqlname" = 'custom2' ]; then
           if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom2 ]; then
             echo "set timing on" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom2.sql
             cat $CUSTOMSQL2 >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom2.sql
           fi
           sqlname=$PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom2
         elif [ "$sqlname" = 'custom3' ]; then
           if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom3 ]; then
             echo "set timing on" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom3.sql
             cat $CUSTOMSQL3 >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom3.sql
           fi
           sqlname=$PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom3
         fi

         throttlecontrol

         if [ "$sqlname" = 'MEMheapdetails' ] || [ "$sqlname" = 'MEMtop20sqls' ]; then
           # only collect these if LRU > 0 due to cost
           ### Can't do this check unless LRU query is done
           until [ `ps -e -o args | grep "$PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMlru" | grep -v grep | wc -l` -eq 0 ] \
           && [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQLMEMlru$sqlsid | grep .out | wc -l | tr -d ' '` -gt 0 ]; do
             sleep 1
           done
           memlru1=`cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMlru$sqlsid.out | grep MAXKSMLRNUM | cut -d ":" -f2 | cut -d " " -f1`
           memlru=0
           for i in $memlru1
           do
            if  test ${i} -gt 0
            then
              memlru=$i
              break
            fi
           done
           if [ $memlru = 0 ]; then
             continue
           fi
         fi

         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
           nohup ksh -x $EXEDIR/prw.sh sqlstart $sqlfile $user $sqlsid $OH
         else
           nohup ksh $EXEDIR/prw.sh sqlstart $sqlfile $user $sqlsid $OH 2>&1 &
         fi
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/procinterval ]; then
         sleep $PROCINTERVAL
         fi
       done
       if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/israc_$sqlsid` = 'true' ] && [ "$gesenqueue" = 'y' ] \
       && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*waitchains*$sqlsid* | grep PROC | wc -l | tr -d ' '` -gt 0 ]; then
        throttlecontrol
        if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$sqlsid` = 'gv' ]; then
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
           nohup ksh -x $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvgesenqueue $user $sqlsid $OH
         else
           nohup ksh $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvgesenqueue $user $sqlsid $OH 2>&1 &
         fi
        else
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
           nohup ksh -x $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLvgesenqueue $user $sqlsid $OH
         else
           nohup ksh $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLvgesenqueue $user $sqlsid $OH 2>&1 &
         fi
        fi
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/procinterval ]; then
         sleep $PROCINTERVAL
         fi
       fi
     else
       if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/usesql_$sqlsid` = 'true' ] && [ $isinstanceup -lt 1 ]; then
         echo `date`: "SID $sqlsid is down, skipping SQL collection"
         # if instance is down, remove disabled SQLs
         if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep disabled_SQL_$sqlsid | wc -l | tr -d ' '` -gt 0 ]; then
           rm -f $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_$sqlsid*
         fi
       fi
     fi
   done

   # Save report data
   # SQL collection needs to be done by now...
   sleep 1
   until [ `ps -e -o args | egrep "$debugprocs|prw.sh sqlrun" | grep prw | grep -v grep | wc -l | tr -d ' '` -eq 0 ]; do
     sleep 1
   done

   for sqlsid in `cat $PRWDIR/PRW_SYS_$HOSTNAME/sidlist | tr "|" " "`
   do
     # If the instance isn't up, move on to the next SID
     isinstanceup
     if [ $isinstanceup -lt 1 ]; then
       continue
     fi

     numaddprocs=0
     if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/usesql_$sqlsid` = 'true' ] && [ $isinstanceup -gt 0 ]; then
     echo `date`: "Saving SQL report data for SID $sqlsid"
       for report in sessionwait lock latchholder rmanclient pgamemory MEMsgastat MEMheapdetails MEMsgadynamic MEMtop20sqls MEMlru custom1 custom2 custom3
       do
        if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQL | grep $report$sqlsid.out | wc -l | tr -d ' '` -gt 0 ]; then
         reportname=`echo "$PRWDIR/PRW_DB_$sqlsid/pw_""$report"_"$sqlsid"_``date "+%m-%d-%y"``echo ".out"`
         if [ ! -f $reportname ]; then
           echo $banner > $reportname
           echo "Procwatcher $report report" >> $reportname
           prwpermissions $reportname
         fi
         if [ `egrep "PROC |POOL|SQL:|CMNT: " $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$report$sqlsid.out | grep -v "Idle" | wc -l` -gt 0 ]; then
           echo $banner >> $reportname
           echo " " >> $reportname
           if [ $report = 'sessionwait' ]; then
             egrep "Snapshot Taken At|PROC|---|CMNT: |Elapsed" $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$report$sqlsid.out | grep -v "Idle" >> $reportname
           elif [ $report = 'custom1' ] || [ $report = 'custom2' ] || [ $report = 'custom3' ]; then
             cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$report$sqlsid.out >> $reportname
           elif [ $report = 'pgamemory' ]; then
             # Summing up PGA Usage
             cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$report$sqlsid.out | awk '{sum+=$9} END {print sum/1024/1024}' > $PRWDIR/PRW_SYS_$HOSTNAME/pga_$sqlsid
             # Summing up SGA Usage
             cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$report$sqlsid.out | grep "SGA:" | cut -d ":" -f2 |  awk '{sum+=$1} END {print sum/1024/1024}' > $PRWDIR/PRW_SYS_$HOSTNAME/sga_$sqlsid 
             egrep "Snapshot Taken At|PARAM|PGA_|sga_|pga_| [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]|POOL|CMNT|---|Elapsed" $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$report$sqlsid.out >> $reportname
             echo " " >> $reportname
             echo `date`: "Total SGA in MB: "`cat $PRWDIR/PRW_SYS_$HOSTNAME/sga_$sqlsid` >> $reportname
             echo `date`: "Total PGA in MB: "`cat $PRWDIR/PRW_SYS_$HOSTNAME/pga_$sqlsid` >> $reportname
           else
             egrep "Snapshot Taken At|SQL:|PROC|POOL|CMNT|---|Elapsed" $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$report$sqlsid.out >> $reportname
           fi
           echo " " >> $reportname
         elif [ $report = 'custom1' ] || [ $report = 'custom2' ] || [ $report = 'custom3' ]; then
           cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$report$sqlsid.out >> $reportname
         else
           echo "No rows found at "`date` >> $reportname
         fi
        fi
       done

       if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/version_$sqlsid ]; then
       if [ `grep "." $PRWDIR/PRW_SYS_$HOSTNAME/version_$sqlsid | wc -l` -gt 0 ]; then
        report=waitchains
        if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/version_$sqlsid | cut -d "." -f1` -gt 10 ] \
        && [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQL | grep $report$sqlsid.out | wc -l | tr -d ' '` -gt 0 ] ; then
         reportname=`echo "$PRWDIR/PRW_DB_$sqlsid/pw_""$report"_"$sqlsid"_``date "+%m-%d-%y"``echo ".out"`
         if [ ! -f $reportname ]; then
           echo $banner > $reportname
           echo "Procwatcher $report report" >> $reportname
           prwpermissions $reportname
         fi
         if [ `egrep "Current Process" $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$report$sqlsid.out | wc -l` -gt 0 ]; then
           echo $banner >> $reportname
           echo " " >> $reportname
           if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
             cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$report$sqlsid.out >> $reportname
           else
             egrep "Snapshot Taken|PROC |Elapsed|--------" $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$report$sqlsid.out >> $reportname
           fi
           echo " " >> $reportname
         else
           echo "No rows found at "`date` >> $reportname
         fi
        fi
       fi
       fi

       report=gesenqueue
       if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/israc_$sqlsid` = 'true' ] \
       && [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQL | grep $report$sqlsid.out | wc -l | tr -d ' '` -gt 0 ]; then
         reportname=`echo "$PRWDIR/PRW_DB_$sqlsid/pw_""$report"_"$sqlsid"_``date "+%m-%d-%y"``echo ".out"`
         if [ ! -f $reportname ]; then
           echo $banner > $reportname
           echo "Procwatcher $report report" >> $reportname
           prwpermissions $reportname
         fi
         if [ `egrep "PROC " $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$report$sqlsid.out | grep -v "Idle" | wc -l` -gt 0 ]; then
           echo $banner >> $reportname
           echo " " >> $reportname
           egrep "Snapshot Taken At|PROC|---|Elapsed" $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$report$sqlsid.out >> $reportname
           echo " " >> $reportname
         else
           echo "No rows found at "`date` >> $reportname
         fi
       fi

       ### 4031 Avoidance/Check Section
       if [ "$sgamemwatch" = 'avoid4031' ] || [ "$sgamemwatch" = 'diag' ]; then
         echo `date`: "Checking for Shared Pool Issues on SID $sqlsid"

         ### Parameters
         # Min largest free memory chunk threshold (higher = more aggressive flushing - default: 1000000)
         MEMMAXFREETHRESHOLD=1000000
         # Min average free memory chunk threshold (higher = more aggressive flushing - default: 4000)
         MEMAVGFREETHRESHOLD=4000
         # Percentage of unused memory threshold (higher = more aggressive flushing - default: 20)
         UNUSEDMEMPCT=20
         # Max LRU list threshold (lower = more aggressive flushing - default: 100)
         MAXLRUNUM=100
         ### End Parameters

         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgadynamic$sqlsid.out ]; then
           currentsize1=`cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgadynamic$sqlsid.out | grep "POOL:shared pool" | awk '{print $1}'`
         fi
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgastat$sqlsid.out ]; then
           freememsize1=`cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgastat$sqlsid.out | grep "shared pool free memory" | awk '{print $6}'`
         fi

         # Check initialized memory
         if [ -n "$currentsize1" ] && [ -n "$freememsize1" ]; then
           let spthreshold=$currentsize1*0.$UNUSEDMEMPCT
           if [ $freememsize1 -le $spthreshold ]; then
             possiblememissue=1
           else
             possiblememissue=0
           fi
         else
             possiblememissue=1
         fi

         if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMheapdetails$sqlsid.out ]; then
          possiblememissue=0
         fi

         # Max Free Mem Chunk Size Check
         if [ "$possiblememissue" -eq 1 ]; then
          if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMheapdetails$sqlsid.out | grep 'DURATION:2' | wc -l | tr -d ' '` -gt 0 ]; then
           memmaxsize1=`cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMheapdetails$sqlsid.out | grep "CMNT: free memory" | grep -v "R-free" | grep -v 'DURATION:1' | cut -d ":" -f5 | cut -d "." -f1 | tr -s " " " " | cut -d " " -f2`
          else
           # _enable_shared_pool_durations=false
           memmaxsize1=`cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMheapdetails$sqlsid.out | grep "CMNT: free memory" | grep -v "R-free" | cut -d ":" -f5 | cut -d "." -f1 | tr -s " " " " | cut -d " " -f2`
          fi
          for i in $memmaxsize1
          do
           memissue=0
           if test ${i} -le $MEMMAXFREETHRESHOLD
           then
            smallMemsize=$i
            possiblememissue=1
            break
           else
            possiblememissue=0
           fi
          done
         fi

         # Avg Free Mem Chunk Size Check
         if [ "$possiblememissue" -eq 1 ]; then
          if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMheapdetails$sqlsid.out | grep 'DURATION:2' | wc -l | tr -d ' '` -gt 0 ]; then
           memavgsize1=`cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMheapdetails$sqlsid.out | grep "CMNT: free memory" | grep -v "R-free" | grep -v 'DURATION:1' | cut -d ":" -f4 | cut -d "." -f1 | tr -s " " " " | cut -d " " -f2`
          else
           # _enable_shared_pool_durations=false
           memavgsize1=`cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMheapdetails$sqlsid.out | grep "CMNT: free memory" | grep -v "R-free" | cut -d ":" -f4 | cut -d "." -f1 | tr -s " " " " | cut -d " " -f2`
          fi
          for i in $memavgsize1
          do
           if test ${i} -le $MEMAVGFREETHRESHOLD
           then
            avgsize=$i
            possiblememissue=1
            echo `date`: "WARNING: SID $sqlsid Avg Free Memory Size $i Below Threshold $MEMAVGFREETHRESHOLD"
            break
           else
            possiblememissue=0
           fi
          done
         fi

         # LRU Check
         if [ "$possiblememissue" -eq 1 ]; then
          if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMlru$sqlsid.out ]; then
            sleep 1
          fi
          if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMlru$sqlsid.out ]; then
           memlru1=`cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMlru$sqlsid.out | grep MAXKSMLRNUM | cut -d ":" -f2 | cut -d " " -f1`
           for i in $memlru1
           do
            if  test ${i} -gt $MAXLRUNUM
            then
              memlru=$i
              memissue=1
              echo `date`: "WARNING: SID $sqlsid Shared Pool LRU $i Higher Than $MAXLRUNUM"
              break
            else
              memissue=0
            fi
           done
          else
           memisssue=1
          fi
         fi

        if [ "$memissue" -eq 1 ]; then
          echo `date`: "WARNING: Shared pool fragmentation on Instance $sqlsid"
          if [ -n "$WARNINGEMAIL" ]; then
            cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEM*$sqlsid.out > $PRWDIR/PRW_SYS_$HOSTNAME/spwarningfile
            prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/spwarningfile
            if [ "$sgamemwatch" = 'avoid4031' ]; then
              warningtype="SHARED POOL FRAGMENTATION AUTO FLUSH"
            else
              warningtype="SHARED POOL FRAGMENTATION"
            fi
            warningsid=$sqlsid
            warningfile=$PRWDIR/PRW_SYS_$HOSTNAME/spwarningfile
            processwarning
          fi
        fi

        if [ "$memissue" -eq 1 ] && [ "$sgamemwatch" = 'avoid4031' ]; then
         echo `date`: "WARNING: Flushing shared pool on Instance $sqlsid"
         sid=$sqlsid
         SID=$sqlsid
         DBNAME=$sid
         ORATAB=$PRWDIR/PRW_SYS_$HOSTNAME/oratab
         findoratabentry
         # Fix ASM string
         if [ `echo $SID | cut -c1-3` = 'ASM' ]; then
           SID=`echo $SID | sed 's@ASM@+ASM@'`
         fi
         # Fix APX string
         if [ `echo $SID | cut -c1-3` = 'APX' ]; then
           SID=`echo $SID | sed 's@APX@+APX@'`
         fi
         # Fix MGMTDB string
         if [ `echo $SID | wc -m | tr -d ' '` -gt 6 ]; then
          if [ `echo $SID | cut -c1-6` = 'MGMTDB' ]; then
           SID=`echo $SID | sed 's@MGMTDB@-MGMTDB@'`
          fi
         fi
         # Set variables
         export ORACLE_SID=$SID
         export ORACLE_HOME=$OH
         export LD_LIBRARY_PATH=$OH/lib:usr/lib:$OH/db_1/rdbms/lib
         export PATH=$ORACLE_HOME/bin:$PATH
         export ORA_SERVER_THREAD_ENABLED=FALSE

         # Run
         if [ $user = 'root' ]; then
           PRWTMPDIR=`eval echo "~$owner"/prw`
           makeprwtmpdir $owner $PRWTMPDIR
           cp $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMflush.sql $PRWTMPDIR/SQLMEMflush.sql
           chown $owner $PRWTMPDIR/SQLMEMflush.sql
           # Switch to owner
           su $owner << UEOF
           sqlplus '/ as sysdba' << DBEOF
           @$PRWTMPDIR/SQLMEMflush.sql
           exit
DBEOF
UEOF
           rm -f $PRWTMPDIR/SQLMEMflush.sql
         else
           sqlplus '/ as sysdba' << DBEOF
           @$PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMflush.sql
           exit
DBEOF
         fi
         for report in MEMsgastat MEMheapdetails MEMsgadynamic MEMtop20sqls MEMlru
         do
           reportname=`echo "$PRWDIR/PRW_DB_$sqlsid/pw_""$report"_"$sqlsid"_``date "+%m-%d-%y"``echo ".out"`
           if [ -f $reportname ]; then
             echo " " >> $reportname
             echo `date`: "SHARED POOL FLUSHED!!!" >> $reportname
             echo " " >> $reportname
           fi
         done
        fi
       fi
       ### End 4031 Avoidance

       ### Check free memory
       if [ "$process_memory" = 'y' ]; then
         memfree=`grep MemFree /proc/meminfo | awk '{ print $2 }'`
         swapfree=`grep SwapFree /proc/meminfo | awk '{ print $2 }'`
         mysum1=`expr $memfree + $swapfree`
         mysum=`expr $mysum1 / 1024`
         if [ $mysum -lt 1000 ]; then
           echo `date`": WARNING: Memory is low...Free Memory is: $mysum MB"
           LOWMEM=y
         else
           LOWMEM=n
         fi
       fi

       ### Add problem procs to list for examining
       if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep listSQL | grep $sqlsid | wc -l | tr -d ' '` -gt 0 ]; then
         rm -f $PRWDIR/PRW_SYS_$HOSTNAME/listSQL*$sqlsid
       fi
       ### Criteria for which processes to look at
       if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLvwaitchains$sqlsid.out ] || [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLv111waitchains$sqlsid.out ]; then
         reprts="waitchains latchholder rmanclient pgamemory"
       else
         reprts="gesenqueue sessionwait lock latchholder rmanclient pgamemory"
       fi
       if [ "$LOWMEM" = 'y' ] && [ "$process_memory" = 'y' ]; then
         reprts="$reprts pgamemory"
       fi
       ### Find procs from report files
       for listrep in $reprts
       do
         if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQL | grep $listrep$sqlsid.out | wc -l | tr -d ' '` -gt 0 ]; then
          if [ "$listrep" != 'pgamemory' ]; then
            grep "PROC " $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$listrep$sqlsid.out | grep "INST " | grep $sqlsid | grep -v "Idle" | awk '{print $2}' | sort > $PRWDIR/PRW_SYS_$HOSTNAME/listSQL$listrep$sqlsid
          else
            grep "PROC " $PRWDIR/PRW_SYS_$HOSTNAME/SQL*$listrep$sqlsid.out | grep "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]"| grep "INST " | grep $sqlsid | grep -v "Idle" | awk '{print $2}' | sort > $PRWDIR/PRW_SYS_$HOSTNAME/listSQL$listrep$sqlsid
          fi
         fi
       done

       # Linux only for now, find top CPU consumers
      if [ $platform = 'Linux' ] && [ -x /usr/bin/top ]; then
       pidlist=`ps -e -o %cpu,pid,user,args | grep $sqlsid | sort -rn | head -20 | awk '{print $2}'`
       pidlist2=`echo $pidlist | sed 's@ @,@g'`
       top -b -n1 -p $pidlist2 > $PRWDIR/PRW_SYS_$HOSTNAME/top$sqlsid.out
       prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/top$sqlsid.out
       for i in $pidlist
       do
         if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/top$sqlsid.out | grep $i | awk '{print $9}' | cut -d "." -f1 | wc -l | tr -d ' '` -eq 0 ]; then
           continue
         else
           pidcpu=`cat $PRWDIR/PRW_SYS_$HOSTNAME/top$sqlsid.out | grep -A 20 COMMAND | grep -v CPU | grep $i | awk '{print $9}' | cut -d "." -f1 | tr -d ' ' | tr -d '\n'`
           # Looking for procs consuming over 90% of a CPU in the next line
           if [ -n $pidcpu ]; then
            if [ $pidcpu -gt 90 ]; then
             echo $i >> $PRWDIR/PRW_SYS_$HOSTNAME/listSQLtop$sqlsid
             prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/listSQLtop$sqlsid
            fi
           fi
         fi
       done
       if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep listSQLtop$sqlsid | wc -l | tr -d ' '` -gt 0 ]; then
         topreport=`echo "$PRWDIR/PRW_DB_$sqlsid/pw_topcpu_""$sqlsid"_``date "+%m-%d-%y"``echo ".out"`
         if [ ! -f $topreport ] && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/listSQLtop$sqlsid | wc -l | tr -d ' '` -gt 0 ]; then
           echo $banner > $topreport
           echo "Procwatcher Top CPU Consumers Report" >> $topreport
           prwpermissions $topreport
         fi
         echo $banner >> $topreport
         echo `date`: "Procwatcher Top CPU Consumers:" >> $topreport
         pidlist3=`sort -mu $PRWDIR/PRW_SYS_$HOSTNAME/listSQLtop$sqlsid | tr '\n' ' ' | sed 's@ @|@g' | tr -d ' '`
         pidlist3length=`echo $pidlist3 | wc -m | tr -d ' '`
         let pidlist3length=$pidlist3length-2
         pidlist4=`echo $pidlist3 | cut -c1-$pidlist3length`
         egrep "CPU|$pidlist4" $PRWDIR/PRW_SYS_$HOSTNAME/top$sqlsid.out >> $topreport
       fi
      fi

       # Find processes to add to the list from SQL reports
       if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep listSQL | grep $sqlsid | wc -l | tr -d ' '` -gt 0 ]; then
        if [ `sort -mu $PRWDIR/PRW_SYS_$HOSTNAME/listSQL*$sqlsid | wc -l` -gt 0 ]; then
         addprocs=
         addproclist=`sort -mu $PRWDIR/PRW_SYS_$HOSTNAME/listSQL*$sqlsid | tr '\n' ' '`
         for proc in $addproclist
         do
           addprocs="$addprocs""|""$proc"
         done
         addprocslength=`echo $addprocs | wc -m | tr -d ' '`
         if [ $addprocslength -gt 2 ]; then
           addprocs=`echo $addprocs | cut -c2-$addprocslength`
         else
           addprocs=
         fi
         numaddprocs=`echo $addprocs | tr '|' ' ' | wc -w`
         # WARNING THRESHOLD
         if [ $numaddprocs -ge $warningprocthreshold ]; then
           echo `date`: "WARNING: $numaddprocs suspect processes found in $sqlsid SQL reports"
           if [ -n "$WARNINGEMAIL" ]; then
             echo " " > $PRWDIR/PRW_SYS_$HOSTNAME/wcwarningfile
             prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/wcwarningfile
           fi
         fi

           # Final Blocker A.I.
          if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLvwaitchains$sqlsid.out ] || [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLv111waitchains$sqlsid.out ]; then
            if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLvwaitchains$sqlsid.out ]; then
              waitchainsfile=$PRWDIR/PRW_SYS_$HOSTNAME/SQLvwaitchains$sqlsid.out
            else
              waitchainsfile=$PRWDIR/PRW_SYS_$HOSTNAME/SQLv111waitchains$sqlsid.out
            fi
            maxwaiters=`grep "Number of waiters" $waitchainsfile | cut -d ":" -f4 | tr -d ' ' | sort -nr`
            maxwaiters1=`echo $maxwaiters | cut -d ' ' -f1`
            suspectprocs=`grep "Number of waiters: $maxwaiters1" $waitchainsfile | cut -d ' ' -f2 | sort -n | sort -mu`

             suspectchains=
             finalblocker=

             # Iterate 3 times through criteria
             for i in 1 2 3
             do

               # Loop to eliminate procs that have other blockers
               for blkr in $suspectprocs
               do
                 if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLvwaitchains$sqlsid.out ]; then
                   blockingprocess=`grep "PROC $blkr " $waitchainsfile | grep "Final Blocking Process" | cut -d ':' -f3 | cut -d ' ' -f2 | tr ' ' '\n' | sort -n | sort -mu`
                 else
                   blockingprocess=`grep "PROC $blkr " $waitchainsfile | grep "Blocking Process" | cut -d ':' -f3 | cut -d ' ' -f2 | tr ' ' '\n' | sort -n | sort -mu`
                 fi
                 if [ `echo $blockingprocess | grep none | wc -l | tr -d ' '` -eq 0 ]; then
                   suspectprocs=`echo $blockingprocess $suspectprocs | sed "s/$blkr //g" | sed "s/ $blkr//g" | tr ' ' '\n' | sort -n | sort -mu`
                 fi
               done
               # End eliminate procs with other blockers loop

              # Find blocking chains loops
              for cblkr in $suspectprocs
              do
                 mychain=`egrep "PROC $cblkr : Wait Chain|PROC $cblkr :  Wait Chain" $waitchainsfile | cut -d ':' -f3 | cut -d ' ' -f2 | tr ' ' '\n' | sort -n | sort -mu`
                 blockingchain=`egrep "PROC $cblkr : Blocking Wait Chain|PROC $cblkr :  Blocking Wait Chain" $waitchainsfile | cut -d ':' -f3 | cut -d ' ' -f2 | tr ' ' '\n' | sort -n | sort -mu`
                 if [ `echo $blockingchain | grep none | wc -l | tr -d ' '` -gt 0 ]; then
                   suspectchains=`echo $mychain $suspectchains | tr ' ' '\n' | sort -n | sort -mu`
                   if [ `echo $suspectprocs | wc -w | tr -d ' '` -eq 1 ]; then
                     finalblocker=$suspectprocs
                     break
                   fi
                 else
                   suspectchains=`echo $blockingchain $suspectchains | tr ' ' '\n' | sort -n | sort -mu`
                   suspectprocs=`echo $suspectprocs | sed "s/$cblkr //g" | sed "s/ $cblkr//g"`
                 fi
              done

              if [ -z "$finalblocker" ]; then
                schains=`echo $suspectchains | sed 's@ @:|@g'`
                for xblkr in $suspectprocs
                do
                  if [ `grep $xblkr $waitchainsfile | grep "Wait Chain: " | egrep "$schains" | wc -l | tr -d ' '` -eq 0 ]; then
                  suspectprocs=`echo $suspectprocs | sed "s/$xblkr //g" | sed "s/ $xblkr//g"`
                  fi
                if [ `echo $suspectprocs | wc -w | tr -d ' '` -eq 1 ]; then
                  finalblocker=$suspectprocs
                  break
                fi
                done
              fi
              # End blocking chains loops

              # Highest wait time check
              if [ -z "$finalblocker" ]; then
                scount=`echo $suspectprocs | wc -w | tr -d ' '`
                let hcount=$scount/2
                for wblkr in $suspectprocs
                do
                  siw=`grep "PROC $wblkr" $waitchainsfile | grep "Seconds in Wait" | cut -d ':' -f3 | cut -d 'S' -f1 | cut -d ' ' -f2 | tr -d '\r' | sort -rn`
                  sslw=`grep "PROC $wblkr" $waitchainsfile | grep "Seconds Since Last Wait" | cut -d ':' -f4 | cut -d ' ' -f2 | tr -d '\r' | sort -rn`
                  siw=`echo $siw | cut -d ' ' -f1`
                  sslw=`echo $sslw | cut -d ' ' -f1`
                  if [ `echo $siw | egrep "0|1|2|3|4|5|6|7|8|0" | wc -l | tr -d ' '` -eq 0 ]; then
                    siw=0
                  fi
                  if [ `echo $sslw | egrep "0|1|2|3|4|5|6|7|8|0" | wc -l | tr -d ' '` -eq 0 ]; then
                    sslw=0
                  fi
                  let ts=$siw+$sslw
                  if [ -z $maxwait ]; then
                    maxwait=$ts
                  fi
                  if [ $ts -lt $maxwait ]; then
                    suspectprocs=`echo $suspectprocs | sed "s/$wblkr //g" | sed "s/ $wblkr//g" | tr ' ' '\n' | sort -n | sort -mu`
                  else
                    maxwait=$ts
                  fi
                  if [ `echo $suspectprocs | wc -w | tr -d ' '` -eq 1 ]; then
                    finalblocker=$suspectprocs
                    break
                  fi
                done
              fi
              if [ -z "$finalblocker" ] && [ `echo $suspectprocs | wc -w | tr -d ' '` -eq 1 ]; then
                finalblocker=$suspectprocs
                break
              fi
             done

             report=waitchains
             reportname=`echo "$PRWDIR/PRW_DB_$sqlsid/pw_""$report"_"$sqlsid"_``date "+%m-%d-%y"``echo ".out"`

             if [ -z "$finalblocker" ]; then
               echo `date`: "Unable to determine final blocker for instance $sqlsid"
               echo " " >> $reportname
               echo `date`: "Unable to determine final blocker for instance $sqlsid" >> $reportname
               echo " " >> $waitchainsfile
               echo `date`: "Unable to determine final blocker for instance $sqlsid" >> $waitchainsfile
             else
               echo `date`: "Instance $sqlsid Suspected final blocker is:" `grep "PROC $finalblocker" $waitchainsfile | grep "Current Process" | sort -mu | sed 's/Current /~/' | cut -d "~" -f2`
               echo "----------blkr----------" >> $reportname
               echo `date`: "Suspected final blocker is: " `grep "PROC $finalblocker" $waitchainsfile | grep "Current Process" | sort -mu | sed 's/Current /~/' | cut -d "~" -f2` >> $reportname
               echo "-------end blkr---------" >> $reportname
               echo "----------blkr----------" >> $waitchainsfile
               echo `date`: "Suspected final blocker is:" `grep "PROC $finalblocker" $waitchainsfile | grep "Current Process" | sort -mu | sed 's/Current /~/' | cut -d "~" -f2` >> $waitchainsfile
               echo "-------end blkr---------" >> $waitchainsfile
             fi
             waitcounts=`grep INST $waitchainsfile | cut -d ':' -f6 | egrep -v "Suspected|SID" | sort -n | uniq -c | sed 's/  /-/g' | sort -nr`
             waitcounts1=`echo $waitcounts | sed 's/---/SessionCount:/g' | sed 's/-/-Instance:/g'`
             for wc in $waitcounts1
             do
               echo `date`: "$sqlsid Waitchains" $wc
               echo "$sqlsid Waitchains" $wc >> $reportname
               echo "$sqlsid Waitchains" $wc >> $waitchainsfile
             done
          fi
           # End Final Blocker A.I.

         # WARNING THRESHOLD
         if [ $numaddprocs -ge $warningprocthreshold ]; then

           for listprocs in $reprts
           do
             if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/listSQL$listprocs$sqlsid ]; then
               numprocs=`cat $PRWDIR/PRW_SYS_$HOSTNAME/listSQL$listprocs$sqlsid | wc -l | tr -d ' '`
               if [ $numprocs -gt 0 ]; then
                 echo `date`: "$numprocs procs found in $listprocs report"
                 if [ -n "$WARNINGEMAIL" ]; then
                   cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*"$listprocs"*"$sqlsid.out" | egrep "blkr----|Suspected|Waitchains Session|Unable" >> $PRWDIR/PRW_SYS_$HOSTNAME/wcwarningfile
                   cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*"$listprocs"*"$sqlsid.out" | egrep "Snapshot Taken|PROC |Elapsed|--------" >> $PRWDIR/PRW_SYS_$HOSTNAME/wcwarningfile
                 fi
               fi
             fi
           done
           warningtype="DATABASE CONTENTION"
           warningsid=$sqlsid
           warningfile=$PRWDIR/PRW_SYS_$HOSTNAME/wcwarningfile
           if [ -f $PRWDIR/.prw_masternode ]; then
             processwarning
           fi

          # Optional hanganalyze/systemstate collection
          gethang=true
          # Flood control:
          let DATEHOUR=`date +'%y'`*31556926+`date +'%m'`*2629743+`date +'%d'`*86400+`date +'%H'`*3600
          if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/hang_$sqlsid_$DATAHOUR ]; then
            if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep "hang_$sqlsid_" | wc -l | tr -d ' '` -gt 0 ]; then
              # Removing old hang collection counts
              rm -f $PRWDIR/PRW_SYS_$HOSTNAME/hang_$sqlsid_*
            fi
            echo "hangcount 1" > $PRWDIR/PRW_SYS_$HOSTNAME/hang_$sqlsid_$DATAHOUR
            prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/hang_$sqlsid_$DATAHOUR
          else
            let hangcount=`grep hangcount $PRWDIR/PRW_SYS_$HOSTNAME/hang_$sqlsid_$DATAHOUR | awk '{print $2}'`
            if [ $hangcount -ge 3 ]; then
              gethang=false
            else
              gethang=true
            fi
          fi
          let DATESECONDS=`date +'%y'`*31556926+`date +'%m'`*2629743+`date +'%d'`*86400+`date +'%H'`*3600+`date +'%M'`*60+`date +'%S'`
          if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/wcwarning_$sqlsid ]; then
            echo 0 > $PRWDIR/PRW_SYS_$HOSTNAME/wcwarning_$sqlsid
            prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/wcwarning_$sqlsid
          fi
          LASTHANGDUMP=`cat $PRWDIR/PRW_SYS_$HOSTNAME/wcwarning_$sqlsid`
          let HANGDIFF=$DATESECONDS-$LASTHANGDUMP
          if [ $HANGDIFF -lt 180 ] && [ "$gethang" = 'true' ]; then
            gethang=false
          fi
          if [ $hanganalyze_level -gt 0 ] || [ $systemstate_level -gt 0 ]; then
            if [ "$gethang" = 'false' ] && [ -f $PRWDIR/.prw_masternode ]; then
              echo `date`: "Skipping hang diag collection due to flood control (hourly_count: $hangcount seconds_since_last: $HANGDIFF)"
            fi
          fi
          # End Flood Control

          # If hanganalyze/systemstate set and we passed flood control, collect
          if [ $hanganalyze_level -gt 0 ] || [ $systemstate_level -gt 0 ]; then
           if [ "$gethang" = 'true' ] && [ -f $PRWDIR/.prw_masternode ]; then

            # Marking that we're getting diags
            let hangcount=$hangcount+1
            echo "hangcount $hangcount" > $PRWDIR/PRW_SYS_$HOSTNAME/hang_$sqlsid_$DATAHOUR
            echo $DATESECONDS > $PRWDIR/PRW_SYS_$HOSTNAME/wcwarning_$sqlsid

            echo `date`: "WARNING: Collecting Hang Diagnostics"
            echo `date`: "hanganalyze_level=$hanganalyze_level systemstate_level=$systemstate_level"
            sid=$sqlsid
            SID=$sqlsid
            DBNAME=$sid
            ORATAB=$PRWDIR/PRW_SYS_$HOSTNAME/oratab
            findoratabentry
            # Fix ASM string
            if [ `echo $SID | cut -c1-3` = 'ASM' ]; then
             SID=`echo $SID | sed 's@ASM@+ASM@'`
            fi
            # Fix APX string
            if [ `echo $SID | cut -c1-3` = 'APX' ]; then
             SID=`echo $SID | sed 's@APX@+APX@'`
            fi
            # Fix MGMTDB string
            if [ `echo $SID | wc -m | tr -d ' '` -gt 6 ]; then
             if [ `echo $SID | cut -c1-6` = 'MGMTDB' ]; then
              SID=`echo $SID | sed 's@MGMTDB@-MGMTDB@'`
             fi
            fi
            # Set variables
            export ORACLE_SID=$SID
            export ORACLE_HOME=$OH
            export LD_LIBRARY_PATH=$OH/lib:usr/lib:$OH/db_1/rdbms/lib
            export PATH=$ORACLE_HOME/bin:$PATH
            export ORA_SERVER_THREAD_ENABLED=FALSE

            if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/israc_$sqlsid` = 'true' ]; then
            # Run
             if [ $user = 'root' ]; then
              PRWTMPDIR=`eval echo "~$owner"/prw`
              makeprwtmpdir $owner $PRWTMPDIR
              cp $PRWDIR/PRW_SYS_$HOSTNAME/SQLRAChang.sql $PRWTMPDIR/SQLRAChang.sql
              chown $owner $PRWTMPDIR/SQLRAChang.sql
              # Switch to owner
              su $owner << UEOF
              sqlplus '/ as sysdba' << DBEOF
              @$PRWTMPDIR/SQLRAChang.sql
              exit
DBEOF
UEOF
              rm -f $PRWTMPDIR/SQLRAChang.sql
             else
              sqlplus '/ as sysdba' << DBEOF
              @$PRWDIR/PRW_SYS_$HOSTNAME/SQLRAChang.sql
              exit
DBEOF
             fi
            else
            # Run
             if [ $user = 'root' ]; then
              PRWTMPDIR=`eval echo "~$owner"/prw`
              makeprwtmpdir $owner $PRWTMPDIR
              cp $PRWDIR/PRW_SYS_$HOSTNAME/SQLhang.sql $PRWTMPDIR/SQLhang.sql
              chown $owner $PRWTMPDIR/SQLhang.sql
              # Switch to owner
              su $owner << UEOF
              sqlplus '/ as sysdba' << DBEOF
              @$PRWTMPDIR/SQLhang.sql
              exit
DBEOF
UEOF
              rm -f $PRWTMPDIR/SQLhang.sql
             else
              sqlplus '/ as sysdba' << DBEOF
              @$PRWDIR/PRW_SYS_$HOSTNAME/SQLhang.sql
              exit
DBEOF
             fi
            fi
           fi
          fi
          # End hang collection
         fi
         # End WARNING THRESHOLD

         if [ -n "$addprocs" ]; then
           if [ `ps -ef | egrep "$addprocs" | grep $sqlsid | grep -v grep | wc -l` -gt 0 ]; then
           echo `date`: "Adding these processes to the process list for SID $sqlsid if they are not there already:"
           ps -ef | egrep "$addprocs|CMD" | egrep "$sqlsid|CMD" | grep -v grep
           fi
         fi
        fi
       fi
     fi
     if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/listbgprocs$sqlsid ]; then
       rm -f $PRWDIR/PRW_SYS_$HOSTNAME/listbgprocs$sqlsid
     fi
     if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/numaddprocs_$sqlsid ]; then
       echo $numaddprocs > $PRWDIR/PRW_SYS_$HOSTNAME/numaddprocs_$sqlsid
       prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/numaddprocs_$sqlsid
     fi

     # Decide whether or not to get BG proc stacks
     if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep waitchains | grep $sqlsid | grep out | wc -l | tr -d ' '` -gt 0 ];  then
      if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*waitchains*$sqlsid* | grep PROC | grep INST | wc -l | tr -d ' '` -ge $suspectprocthreshold ] && [ $EXAMINE_BG = 'true' ]; then
        echo `$findprocname | egrep "$BGPROCS" | egrep "$sqlsid" | egrep -v "$badlist" | awk '{print $1}'` > $PRWDIR/PRW_SYS_$HOSTNAME/listbgprocs$sqlsid
      elif [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*waitchains*$sqlsid* | grep Elapsed | wc -l | tr -d ' '` -eq 0 ] && [ $waitchains = 'y' ] && [ $USE_SQL = 'true' ]; then
        # waitchains didn't finish, get stacks
        echo `$findprocname | egrep "$BGPROCS" | egrep "$sqlsid" | egrep -v "$badlist" | awk '{print $1}'` > $PRWDIR/PRW_SYS_$HOSTNAME/listbgprocs$sqlsid
      else
       echo `date`: "No contention found on DB instance $sqlsid, no additional data collection needed"
      fi
     elif [ $numaddprocs -ge $suspectprocthreshold ] && [ $EXAMINE_BG = 'true' ]; then
       echo `$findprocname | egrep "$BGPROCS" | egrep "$sqlsid" | egrep -v "$badlist" | awk '{print $1}'` > $PRWDIR/PRW_SYS_$HOSTNAME/listbgprocs$sqlsid
     elif [ $USE_SQL = 'false' ] && [ $EXAMINE_BG = 'true' ]; then
       echo `$findprocname | egrep "$BGPROCS" | egrep "$sqlsid" | egrep -v "$badlist" | awk '{print $1}'` > $PRWDIR/PRW_SYS_$HOSTNAME/listbgprocs$sqlsid
     elif [ $USE_SQL = 'true' ] && [ $EXAMINE_BG = 'true' ] && [ $waitchains = 'y' ] && [ $USE_SQL = 'true' ]; then
       # Waitchains should have run but it hasn't, get stacks
       echo `$findprocname | egrep "$BGPROCS" | egrep "$sqlsid" | egrep -v "$badlist" | awk '{print $1}'` > $PRWDIR/PRW_SYS_$HOSTNAME/listbgprocs$sqlsid
     else
       echo `date`: "No contention found on DB instance $sqlsid, no additional data collection needed"
     fi
     echo $numaddprocs > $PRWDIR/PRW_SYS_$HOSTNAME/numaddprocs_$sqlsid
     prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/numaddprocs_$sqlsid
   done

   ### Check Memory
   if [ "$process_memory" = 'y' ]; then
     TotalMem=`cat /proc/meminfo | grep MemTotal | awk '{print $2/1024}'`
     TotalSwap=`cat /proc/meminfo | grep SwapTotal | awk '{print $2/1024}'`
     TotalHuge=`cat /proc/meminfo | grep HugePages_Total | awk '{print $2}'`
     HugePageSize=`cat /proc/meminfo | grep Hugepagesize | awk '{print $2}'`
     HugePageMem=`expr $TotalHuge \* $HugePageSize`
     HugePageMemMB=`expr $HugePageMem / 1024`
     memfree=`grep MemFree /proc/meminfo | awk '{ print $2 }'`
     swapfree=`grep SwapFree /proc/meminfo | awk '{ print $2 }'`
     mysum1=`expr $memfree + $swapfree`
     FreeMemSwapFree=`expr $mysum1 / 1024`
     MemFree=`expr $memfree / 1024`
     SwapFree=`expr $swapfree / 1024`
     TotalSGA=`cat  $PRWDIR/PRW_SYS_$HOSTNAME/sga_* | awk '{sum+=$1} END {print sum}'`
     TotalPGA=`cat  $PRWDIR/PRW_SYS_$HOSTNAME/pga_* | awk '{sum+=$1} END {print sum}'`
     CW=`ps -e -o vsz,args | egrep "d.bin|grid" | grep -v grep | awk '{sum+=$1} END {print sum+0}'`
     CWMem=`expr $CW / 1024`
     echo `date`: "Memcheck: TotalMem: $TotalMem"M"  SwapTotal: $TotalSwap"M"  HugePageMem: $HugePageMemMB"M""
     echo `date`: "Memcheck: FreeMem: $MemFree"M"  SwapFree: $SwapFree"M"  FreeMem+SwapFree: $FreeMemSwapFree"M""
     echo `date`: "Memcheck: TotalSGA: $TotalSGA"M"  TotalPGA: $TotalPGA"M"  Clusterware: $CWMem"M""
   fi

   if [ -n "$proclist" ] && [ -n "$sidprocs" ]; then
     echo `$findprocname | egrep "$proclist" | egrep "$sidprocs" | egrep -v "$badlist" | awk '{print $1}'` > $PRWDIR/PRW_SYS_$HOSTNAME/listuser
   fi
   if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep list | egrep -v "sidlist|proclist" | wc -l | tr -d ' '` -gt 0 ]; then
     sort -mu $PRWDIR/PRW_SYS_$HOSTNAME/list* |  tr '\n' ' '  > $PRWDIR/PRW_SYS_$HOSTNAME/proclist
     prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/proclist
   fi
   if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/proclist ]; then
     if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/proclist | wc -w | tr -d ' '` -eq 0 ]; then
       # sleeping for a sec to make sure proclist is populated
       sleep 1
     fi
     totalprocs=`cat $PRWDIR/PRW_SYS_$HOSTNAME/proclist | wc -w | tr -d ' '`
   else
     totalprocs=0
   fi

   ### Run process query
   for  sqlsid in `cat $PRWDIR/PRW_SYS_$HOSTNAME/sidlist | tr "|" " "`
   do
    ### Set ORACLE_HOME
    isinstanceup
    sid=$sqlsid
    DBNAME=$sid
    ORATAB=$PRWDIR/PRW_SYS_$HOSTNAME/oratab
    findoratabentry
    if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/usesql_$sqlsid` = 'true' ] &&  [ "$process_memory" = 'y' ] \
    && [ $isinstanceup -gt 0 ] && [ $totalprocs -gt 0 ]
    then
    if [ `echo $sqlsid | cut -c1-3` = 'ASM' ] || [ `echo $sqlsid | cut -c1-3` = 'APX' ]; then
      SQLLIST="$PRWDIR/PRW_SYS_$HOSTNAME/SQLASMvProcess"
    else
      SQLLIST="$PRWDIR/PRW_SYS_$HOSTNAME/SQLvProcess"
    fi
    for sqlfile in $SQLLIST
    do
      throttlecontrol
      if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
        nohup ksh -x $EXEDIR/prw.sh sqlstart $sqlfile $user $sqlsid $OH
      else
        nohup ksh $EXEDIR/prw.sh sqlstart $sqlfile $user $sqlsid $OH 2>&1 &
      fi
    done
    fi
   done

   ### Save oracle pid list
   if  [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/usesql` = 'true' ] && [ $process_memory = 'y' ] \
   && [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep disabled | grep Process | wc -l | tr -d ' '` -eq 0 ] \
   && [ $totalprocs -gt 0 ]; then
     ### Can't save the list until process queries are done
     until [ `ps -e -o args | grep "$PRWDIR/PRW_SYS_$HOSTNAME/SQLvProcess" | grep -v grep | wc -l` -eq 0 ] \
     && [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQLvProcess | grep .out | wc -l | tr -d ' '` -gt 0 ]; do
       sleep 1
     done
     cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLvProcess*.out | grep PROC | grep -v select | awk '{print $2}' | tr '\n' ' ' > $PRWDIR/PRW_SYS_$HOSTNAME/opidlist
     prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/opidlist
    if [ `grep ASM $PRWDIR/PRW_SYS_$HOSTNAME/sidlist | wc -l` -gt 0 ]; then
     until [ `ps -e -o args | grep "$PRWDIR/PRW_SYS_$HOSTNAME/SQLASMvProcess" | grep -v grep | wc -l` -eq 0 ] \
     && [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQLASMvProcess | grep .out | wc -l | tr -d ' '` -gt 0 ]; do
       sleep 1
     done
     cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMvProcess*.out | grep PROC | grep -v select | awk '{print $2}' | tr '\n' ' ' > $PRWDIR/PRW_SYS_$HOSTNAME/asmpidlist
     prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/asmpidlist
    fi
   fi

if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/proclist | wc -w | tr -d ' '` -gt 0 ]; then
### Make process memory query
echo " " > $PRWDIR/PRW_SYS_$HOSTNAME/SQLvprocess_memory.sql
if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/opidlist ]; then
for proc in `cat $PRWDIR/PRW_SYS_$HOSTNAME/opidlist`
do
$ECHO "
alter session set events 'immediate trace name PGA_DETAIL_GET level $proc';" >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLvprocess_memory.sql
done
$ECHO "
host echo \"Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
host sleep 5
set timing on
column PROC format a14 tru
column heap_name format a20 wra
column name format a40 wra
select 'PROC '||p.spid PROC, pm.heap_name, pm.name, pm.bytes, pm.allocation_count
from v\$process p, v\$process_memory_detail pm
where pm.pid = p.pid and pm.bytes > 5000
and p.spid in (select prwpid from procwatcher_pids_$HOSTNAME)
order by PROC, bytes desc;"| sed 's@,)@)@' >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLvprocess_memory.sql
until [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLvprocess_memory.sql ]; do
  sleep 1
done
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLvprocess_memory.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLvprocess_memory.sql
fi
fi

if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/proclist | wc -w | tr -d ' '` -gt 0 ]; then
### Make ASM process memory query
echo " " > $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMvprocess_memory.sql
if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/asmpidlist ]; then
for proc in `cat $PRWDIR/PRW_SYS_$HOSTNAME/asmpidlist`
do
$ECHO "
alter session set events 'immediate trace name PGA_DETAIL_GET level $proc';" >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMvprocess_memory.sql
done
$ECHO "
host echo \"Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
host sleep 5
set timing on
column PROC format a14 tru
column heap_name format a20 wra
column name format a40 wra
select 'PROC '||p.spid PROC, pm.heap_name, pm.name, pm.bytes, pm.allocation_count
from v\$process p, v\$process_memory_detail pm
where pm.pid = p.pid and pm.bytes > 5000
order by PROC, bytes desc;"| sed 's@,)@)@' >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMvprocess_memory.sql
until [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMvprocess_memory.sql ]; do
  sleep 1
done
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMvprocess_memory.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMvprocess_memory.sql
fi
fi

   ### Kick off SQL Text, ASH, and process memory SQL
   for sqlsid in `cat $PRWDIR/PRW_SYS_$HOSTNAME/sidlist | tr "|" " "`
   do
    if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/numaddprocs_$sqlsid` -ge $suspectprocthreshold ]; then
     ### Set ORACLE_HOME
     isinstanceup
     sid=$sqlsid
     DBNAME=$sid
     ORATAB=$PRWDIR/PRW_SYS_$HOSTNAME/oratab
     findoratabentry

     if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/usesql_$sqlsid` = 'true' ] && [ $isinstanceup -gt 0 ] && [ $totalprocs -gt 0 ]
     then
       ### Can't start until process query is done
       until [ `ps -e -o args | grep "$PRWDIR/PRW_SYS_$HOSTNAME/SQLvProcess" | grep $sqlsid | grep -v grep | wc -l` -eq 0 ]; do
         sleep 1
       done
       echo `date`: "Collecting process specific SQLs for SID $sqlsid"
       if [ `echo $sqlsid | cut -c1-3` = 'ASM' ] || [ `echo $sqlsid | cut -c1-3` = 'APX' ]; then
         SQLLIST="$PRWDIR/PRW_SYS_$HOSTNAME/SQLASMvprocess_memory $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMsqltext $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMash"
       else
         SQLLIST="$PRWDIR/PRW_SYS_$HOSTNAME/SQLvprocess_memory $PRWDIR/PRW_SYS_$HOSTNAME/SQLsqltext $PRWDIR/PRW_SYS_$HOSTNAME/SQLash"
       fi
       for sqlfile in $SQLLIST
       do
         sqlname=`echo $sqlfile | sed 's@'$PRWDIR'/PRW_SYS_'$HOSTNAME'/@@' | sed 's@SQLgv@@' | sed 's@SQLv@@' | sed 's@SQL@@' | sed 's@ASMv@@' | sed 's@ASM@@'`

         # Make sure SQL is enabled
         if [ "$sqlname" = 'process_memory' ] && [ "$process_memory" != 'y' ]; then
           continue
         elif [ "$sqlname" = 'sqltext' ] && [ "$sqltext" != 'y' ]; then
           continue
         elif  [ "$sqlname" = 'ash' ] && [ "$ash" != 'y' ]; then
           continue
         fi

         throttlecontrol

         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
           nohup ksh -x $EXEDIR/prw.sh sqlstart $sqlfile $user $sqlsid $OH
         else
           nohup ksh $EXEDIR/prw.sh sqlstart $sqlfile $user $sqlsid $OH 2>&1 &
         fi
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/procinterval ]; then
         sleep $PROCINTERVAL
         fi
       done
      fi
    fi
   done

   # SQL collection needs to be done before continuing...
   if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/usesql` = 'true' ]; then
     until [ `ps -e -o args | egrep "$debugprocs|prw.sh sqlrun" | grep prw | grep -v grep | wc -l | tr -d ' '` -eq 0 ]; do
       sleep 1
     done
     ### Record SQL timings
     for sqlsid in `cat $PRWDIR/PRW_SYS_$HOSTNAME/sidlist | tr "|" " "`
     do
       if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/usesql_$sqlsid` = 'true' ] \
       && [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQL | grep $sqlsid.out | wc -l | tr -d ' '` -gt 0 ]; then
         reportname=`echo "$PRWDIR/PRW_DB_$sqlsid/pw_sqltimings_$sqlsid"_``date "+%m-%d-%y"``echo ".out"`
         date >> $reportname
         grep Elapsed $PRWDIR/PRW_SYS_$HOSTNAME/SQ*$sqlsid.out >> $reportname
         echo " " >> $reportname
         prwpermissions $reportname
       fi
     done
     if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQL | grep .out | wc -l | tr -d ' '` -gt 0 ]; then
      sqlcount=`ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQL | grep .out | wc -l | tr -d ' '`
      PRWINTERVAL=`cat $PRWDIR/PRW_SYS_$HOSTNAME/prwinterval`
      let SQLDATESECONDS=`date +'%y'`*31556926+`date +'%m'`*2629743+`date +'%d'`*86400+`date +'%H'`*3600+`date +'%M'`*60+`date +'%S'`
      let CYCLE=$SQLDATESECONDS-$PRWINTERVAL
      let avgsql=$CYCLE/$sqlcount
      echo `date`: "SQL collection complete after $CYCLE seconds ($sqlcount SQLs - average seconds: $avgsql)"
     fi
   fi

   ### Start process loop
   if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/proclist | wc -w | tr -d ' '` -gt 0 ] && [ $totalprocs -gt 0 ]; then
   for proc in `cat $PRWDIR/PRW_SYS_$HOSTNAME/proclist`
     do

       ### Get process name/path
       procname=`ps -p $proc -o args | grep -v COMM`

       ### Make sure we have our process info
       if [ -z "$proc" ] || [ -z "$procname" ]
         then echo `date`: "Was going to debug process $proc but it vanished..."
         continue
       fi

       ### Figure out process type
       pathcount=`echo $procname | cut -d ' ' -f1 | tr '//' ' ' | tr '/' ' ' | wc -w | tr -d ' '`
       let pathcount=$pathcount+1
       procbin=`echo $procname | cut -d ' ' -f1 |  sed "s@//@/@g" | cut -d '/' -f$pathcount`
       if [ `echo $procname | cut -c1-3` = 'ora' ] && [ `echo $procbin | cut -c1-3` = 'ora' ]; then
         proctype='oracle'
       elif [ `echo $procname | cut -c1-3` = 'asm' ] && [ `echo $procbin | cut -c1-3` = 'asm' ]; then
         proctype='oracle'
       elif [ `echo $procname | cut -c1-3` = 'apx' ] && [ `echo $procbin | cut -c1-3` = 'apx' ]; then
         proctype='oracle'
       elif [ `echo $procname | cut -c1-3` = 'mdb' ] && [ `echo $procbin | cut -c1-3` = 'mdb' ]; then
         proctype='oracle'
       else
         proctype=$procbin
         procname=`echo $procname | cut -d ' ' -f1`
         prefix=`echo $procname | cut -d "/" -f2 | cut -d "/" -f1`
         temp=${procname#*/*/}
         path=${temp%/*}
         procpath=`echo "/"$prefix"/"$path`
         procname=$procbin
       fi

       ### Fix procname for FG
       if [ "$proctype" = 'oracle' ] && [ `echo $procname | cut -c1-6` = 'oracle' ]; then
         sidlengthoracle=`echo $procname | cut -d "(" -f1 | wc -m | tr -d ' '`
         let sidlengthoracle=sidlengthoracle-2
         SID=`echo $procname | cut -c7-$sidlengthoracle | sed s@+@@ | sed s@-MGMTDB@MGMTDB@ | grep -v sed`
         procname=ora_fg_$SID
       fi

       ### Find the right ORACLE_HOME by checking the oratab
       if [ $proctype = 'oracle' ] && [ `echo $procname | cut -c1-6` != 'oracle' ]
         then SID=`echo $procname | cut -d "_" -f3-5 | sed s@+@@ | sed s@-MGMTDB@MGMTDB@ | grep -v sed`
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/oratab ]
           then
             sid=$SID
             DBNAME=$sid
             ORATAB=$PRWDIR/PRW_SYS_$HOSTNAME/oratab
             findoratabentry
         fi
       fi

       ### Skip process if it's not a good SID
       if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/usesql_$SID ] && [ $proctype = 'oracle' ]; then
         continue
       fi

       ### Assign filename
      if [ $EXAMINE_CELL != 'true' ]; then
       if [ $proctype = 'oracle' ]
         then filenm=`echo "$PRWDIR/PRW_DB_$SID/prw_"$procname"_"$proc"_"``date +"%m-%d-%y" | tr -d ' '`
       else
         filenm=`echo "$PRWDIR/PRW_CLUSTER/prw_"$procname"_"$proc"_"``date +"%m-%d-%y" | tr -d ' '`
       fi
      else
       filenm=`echo "$PRWDIR/PRW_CELL/prw_"$procname"_"$proc"_"``date +"%m-%d-%y" | tr -d ' '`
      fi
       filename=`echo "$filenm" | tr -d ' '`

       ### Create file if it does not exist
       if [ ! -f $filename.out ]; then
         echo $banner >> $filename.out
         echo "Procwatcher Debugging for Process $proc $procname" >> $filename.out
         prwpermissions $filename.out
       fi

       ### Skip process if it is already being debugged
       if [ `ps -e -o args | grep $proc | grep -v grep | egrep "$debugprocs" | wc -l` -gt 0 ]
        then echo `date`: $procname $proc "is already being debugged, skipping..."
        continue
       fi

       ### Dump SQL Report Data to process files
       if [ $proctype = 'oracle' ]; then
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLvwaitchains$SID.out ] || [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLv111waitchains$SID.out ]; then
          if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLv*waitchains$SID.out | grep "PROC $proc" | wc -l` -gt 0 ]; then
           echo $banner >> $filename.out
           echo "SQL: Wait Chains Report for Process" $proc $procname >> $filename.out
           echo " " >> $filename.out
           egrep "Snapshot Taken At|SAMPLE_TIME|CHAIN|IN_WAIT_SECS|PROC $proc" $PRWDIR/PRW_SYS_$HOSTNAME/SQLv*waitchains$SID.out >> $filename.out
           echo " " >> $filename.out
          fi
         fi
         if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/usesql_$SID` = 'true' ] \
         && [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQL | grep sessionwait$SID.out | wc -l | tr -d ' '` -gt 0 ]; then
          if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*sessionwait$SID.out | grep "PROC $proc" | wc -l` -gt 0 ]; then
           echo $banner >> $filename.out
           echo "SQL: Session Wait Report for Process" $proc $procname >> $filename.out
           echo " " >> $filename.out
           egrep "Snapshot Taken At|EVENT|PROC $proc|---" $PRWDIR/PRW_SYS_$HOSTNAME/SQL*sessionwait$SID.out >> $filename.out
           echo " " >> $filename.out
          fi
         fi
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLash$SID.out ]; then
          if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLash$SID.out | grep "PROC $proc" | wc -l` -gt 0 ]; then
           echo $banner >> $filename.out
           echo "SQL: Active Session History Report for Process" $proc $procname >> $filename.out
           echo " " >> $filename.out
           egrep "Snapshot Taken At|SAMPLE_TIME|PROC $proc|---" $PRWDIR/PRW_SYS_$HOSTNAME/SQLash$SID.out >> $filename.out
           echo " " >> $filename.out
          fi
         fi
         if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/israc_$SID` = 'true' ] \
         && [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQL | grep gesenqueue$SID.out | wc -l | tr -d ' '` -gt 0 ]; then
           if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*gesenqueue$SID.out | grep "PROC $proc" | wc -l` -gt 0 ]; then
             echo $banner >> $filename.out
             echo "SQL: GES Enqueue Report for Process" $proc $procname >> $filename.out
             echo " " >> $filename.out
             egrep "Snapshot Taken At|RESOURCE_NAME|PROC $proc|---" $PRWDIR/PRW_SYS_$HOSTNAME/SQL*gesenqueue$SID.out >> $filename.out
             echo " " >> $filename.out
           fi
         fi
         if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQL | grep lock$SID.out | wc -l | tr -d ' '` -gt 0 ]; then
          if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*lock$SID.out | grep "PROC $proc" | wc -l` -gt 0 ]; then
           echo $banner >> $filename.out
           echo "SQL: Lock Report for Process" $proc $procname >> $filename.out
           echo " " >> $filename.out
           egrep "Snapshot Taken At|LMODE|PROC $proc|---" $PRWDIR/PRW_SYS_$HOSTNAME/SQL*lock$SID.out >> $filename.out
           echo " " >> $filename.out
          fi
         fi
         if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep SQL | grep latchholder$SID.out | wc -l | tr -d ' '` -gt 0 ]; then
          if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQL*latchholder$SID.out | grep "PROC $proc" | wc -l` -gt 0 ]; then
           echo $banner >> $filename.out
           echo "SQL: Latch Holder Report for Process" $proc $procname >> $filename.out
           echo " " >> $filename.out
           egrep "Snapshot Taken At|LADDR|PROC $proc|---" $PRWDIR/PRW_SYS_$HOSTNAME/SQL*latchholder$SID.out >> $filename.out
           echo " " >> $filename.out
          fi
         fi
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLsqltext$SID.out ]; then
          if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLsqltext$SID.out | grep "PROC $proc" | wc -l` -gt 0 ]; then
           echo $banner >> $filename.out
           echo "SQL: Current SQL Report for Process" $proc $procname >> $filename.out
           echo " " >> $filename.out
           egrep "Snapshot Taken At|SQL_TEXT|PROC $proc" $PRWDIR/PRW_SYS_$HOSTNAME/SQLsqltext$SID.out | sed 's@SQL_TEXT@ @' >> $filename.out
           echo " " >> $filename.out
          fi
         fi
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLvprocess_memory$SID.out ]; then
          if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLvprocess_memory$SID.out | grep "PROC $proc" | wc -l` -gt 0 ]; then
           echo $banner >> $filename.out
           echo "SQL: Process Memory Report for Process" $proc $procname >> $filename.out
           echo " " >> $filename.out
           egrep "Snapshot Taken At|BYTES|PROC $proc" $PRWDIR/PRW_SYS_$HOSTNAME/SQLvprocess_memory$SID.out >> $filename.out
           echo " " >> $filename.out
          fi
         fi
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLpgamemory$SID.out ]; then
          if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/SQLpgamemory$SID.out | grep "PROC $proc" | wc -l` -gt 0 ]; then
           echo $banner >> $filename.out
           echo "SQL: PGA Memory Report for Process" $proc $procname >> $filename.out
           echo " " >> $filename.out
           egrep "Snapshot Taken At|PROC $proc" $PRWDIR/PRW_SYS_$HOSTNAME/SQLpgamemory$SID.out >> $filename.out
           echo " " >> $filename.out
          fi
         fi
       fi

       ### Thread count
       if [ $proctype = 'oracle' ] || [ $platform = 'HP-UX' ] || [ $osversion = '5.10' ]; then
         threads=1
       else
         threads=`ps -p $proc -mo THREAD -o pid | wc -l | tr -d ' '`
         let threads=threads-2
       fi

       ### Big proc?
       if [ $proctype != 'oracle' ]; then
         if [ $threads -gt 5 ] || [ "$procname" = "crsd.bin" ] || [ "$procname" = "ohasd.bin" ] || [ "$procname" = "ocssd.bin" ] \
         || [ "$procname" = "oraagent" ] || [ "$procname" = "orarootagent.bin" ] || [ "$procname" = "cssdmonitor" ] \
         || [ "$procname" = "cssdagent" ] || [ "$procname" = "ons" ] || [ "$procname" = "evmd.bin" ]; then
           bigproc=true
         else
           bigproc=false
         fi
       else
         bigproc=false
       fi

       echo " " >> $filename.out
       echo $banner >> $filename.out
       date >> $filename.out
       if [ $platform = "Linux" ] || [ $platform = "SunOS" ]; then
         if [ $threads -gt 1 ]; then
           ps -p $proc -fl >> $filename.out
           echo " " >> $filename.out
           echo "Threads: " >> $filename.out
           ps -p $proc -flL >> $filename.out
           if [ $use_pmap = 'y' ]; then
             echo " " >> $filename.out
             echo "Pmap Output:" >> $filename.out
             pmap $proc >> $filename.out
             echo " " >> $filename.out
           fi
         else
           ps -p $proc -fl >> $filename.out
         fi
       elif [ $platform = "AIX" ] && [ $threads -gt 1 ]; then
            ps -p $proc -fl >> $filename.out
            echo " " >> $filename.out
            echo "Threads: " >> $filename.out
            ps -p $proc -mo THREAD -o pid | cut -c1-120 >> $filename.out
       else
           ps -p $proc -fl >> $filename.out
       fi
       echo " " >> $filename.out

       # Make sure we pass info to child prw.sh processes if need be
       if [ -z "$proctype" ]; then
          echo `date`: "WARNING: proctype is null, assuming Oracle..."
          proctype='oracle'
       fi
       if [ -z "$procname" ]; then
          echo `date`: "WARNING: procname is null"
          procname='proc_name_not_set'
       fi
       if [ -z "$OH" ]; then
          OH='OH_not_set'
       fi
       if [ -z "$procpath" ]; then
          procpath='procpath_not_set'
       fi

       throttlecontrol

       if [ $bigproc = 'true' ]; then
         ### Bigger process, more load restrictions
         halfthrottle
       fi

       # Run Debugger
       if [ $proctype = 'oracle' ] && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/shortstack_$SID` = 'true' ]; then
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
           nohup ksh -x $EXEDIR/prw.sh shortstack start $proc $user $SID $OH $filename
         else
           nohup ksh $EXEDIR/prw.sh shortstack start $proc $user $SID $OH $filename 2>&1 &
         fi
         debugger="using short_stack"
       elif [  "$proctype" = 'oracle' ] && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/shortstack_$SID` != 'true' ] && [ "$FALL_BACK_TO_OSDEBUGGER" = 'false' ]; then
         echo `date`: "No stack since short_stack is off and FALL_BACK_TO_OSDEBUGGER is false" >> $filename.out
         debugger="no debugger"
       elif [ "$USE_PSTACK" = 'true' ]; then
         nohup $PSTACK $proc >> $filename.out &
         debugger="using pstack"
       elif [ "$USE_PROCSTACK" = 'true' ]; then
         if [ "$proctype" != 'oracle' ]; then
           echo "SVMON Output:" >> $filename.out
           echo " "
           svmon -P $proc >> $filename.out
         fi
         nohup $PROCSTACK $proc >> $filename.out &
         debugger="using procstack"
       elif [ "$USE_GDB" = 'true' ]; then
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
           nohup ksh -x $EXEDIR/prw.sh gdbrun $GDB $platform $proc $proctype $procname $filename $OH $procpath
         else
           nohup ksh $EXEDIR/prw.sh gdbrun $GDB $platform $proc $proctype $procname $filename $OH $procpath > /dev/null  2>&1 &
         fi
         debugger="using gdb"
       elif [ "$USE_LADEBUG" = 'true' ] && [ $proctype = 'oracle' ]; then
         ladebugops="-i $PRWDIR/PRW_SYS_$HOSTNAME/prw_iladebug.cmd -c $PRWDIR/PRW_SYS_$HOSTNAME/prw_cladebug.cmd"
         nohup $LADEBUG $ladebugops -pid $proc $OH/bin/oracle | egrep "at |in |thread" >> $filename.out 2>&1 &
         debugger="using ladebug"
       elif [ "$USE_LADEBUG" = 'true' ] && [ $proctype != 'oracle' ]; then
         ladebugops="-i $PRWDIR/PRW_SYS_$HOSTNAME/prw_iladebug.cmd -c $PRWDIR/PRW_SYS_$HOSTNAME/prw_cladebug.cmd"
         nohup $LADEBUG $ladebugops -pid $proc $procpath/$procname | egrep "at |in |thread" >> $filename.out 2>&1 &
         debugger="using ladebug"
       elif [ "$USE_DBX" = 'true' ]; then
         if [ "$proctype" != 'oracle' ]; then
           echo "SVMON Output:" >> $filename.out
           echo " "
           svmon -P $proc >> $filename.out
         fi
         if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
           nohup ksh -x $EXEDIR/prw.sh dbxrun $DBX $platform $proc $proctype $procname $filename $OH $procpath
         else
           nohup ksh $EXEDIR/prw.sh dbxrun $DBX $platform $proc $proctype $procname $filename $OH $procpath > /dev/null 2>&1 &
         fi
         debugger="using dbx"
       else
         echo `date`: "Unable to find a debugger to use" >> $filename.out
         debugger="no debugger"
       fi
       echo " " >> $filename.out

       if [ "$debugger" != 'no debugger' ]; then
        if [ $threads -gt 1 ]; then
         echo `date`: "Getting stack for $procname $proc $debugger ($threads threads) in $filename.out"
        else
         echo `date`: "Getting stack for $procname $proc $debugger in $filename.out"
        fi
       fi

     if [ $bigproc = 'true' ]; then
       ### Bigger process, more load restrictions
       halfthrottle
     fi

     ### If PROCINTERVAL was manually set, sleep.
     if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/procinterval ]; then
       sleep $PROCINTERVAL
     fi

     ### Run pga oradebug if necessary
     if [ "$process_memory" = 'y' ] && [ $proctype = 'oracle' ] && [ "$LOWMEM" = 'y' ]; then
      if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/listSQLpgamemory$SID | grep $proc | wc -l | tr -d ' '` -gt 0 ]; then
       if [ `cat $filename.out | grep heapdump | wc -l | tr -d ' '` -lt 4 ] \
       && [ `cat prw*.log | grep "Running oradebug commands" | wc -l | tr -d ' '` -lt 16 ]; then
        echo `date`: "Running oradebug commands for $procname $proc"
        if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
           nohup ksh -x $EXEDIR/prw.sh oradebug start pga $proc $user $SID $OH $filename
        else
           nohup ksh $EXEDIR/prw.sh oradebug start pga $proc $user $SID $OH $filename 2>&1 &
        fi
       fi
      fi
     fi

     ### Run oradebug errorstack if necessary
     if [ $errorstack = 'y' ] && [ $proctype = 'oracle' ]; then
       if [ `cat $filename.out | grep errorstack | wc -l | tr -d ' '` -lt 11 ]; then
        echo `date`: "Running errorstack for $procname $proc"
        if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
           nohup ksh -x $EXEDIR/prw.sh oradebug start errorstack $proc $user $SID $OH $filename
        else
           nohup ksh $EXEDIR/prw.sh oradebug start errorstack $proc $user $SID $OH $filename 2>&1 &
        fi
       fi
     fi

     done
     fi

     # Wait until debug procs finished
     for i in 1 2 3
     do
       if [ `ps -e -o args | egrep "$debugprocs|prw.sh sqlrun" | grep -v grep | wc -l | tr -d ' '` -gt 0 ]; then
         sleep $PROCINTERVAL
       fi
     done
     if [ `ps -e -o args | egrep "$debugprocs|prw.sh sqlrun" | grep -v grep | wc -l | tr -d ' '` -gt 0 ]; then
       echo `date`: "Waiting for these debug procs to finish:"
       ps -e -o args | egrep "$debugprocs|prw.sh sqlrun" | grep -v grep
     fi
     until [ `ps -e -o args | egrep "$debugprocs|prw.sh sqlrun" | grep -v grep | wc -l | tr -d ' '` -eq 0 ]; do
       sleep $PROCINTERVAL
     done

     # Record stack timings
     PRWINTERVAL=`cat $PRWDIR/PRW_SYS_$HOSTNAME/prwinterval`
     let DATESECONDS=`date +'%y'`*31556926+`date +'%m'`*2629743+`date +'%d'`*86400+`date +'%H'`*3600+`date +'%M'`*60+`date +'%S'`
     if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/proclist | wc -w | tr -d ' '` -gt 0 ]; then
       proccount=`cat $PRWDIR/PRW_SYS_$HOSTNAME/proclist | wc -w | tr -d ' '`
     else
       proccount=0
     fi
     if [ -z "$SQLDATESECONDS" ]; then
        SQLDATESECONDS=$PRWINTERVAL
     fi
     if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/usesql` = 'true' ]; then
       let stacktime=$DATESECONDS-$SQLDATESECONDS
     else
       let stacktime=$DATESECONDS-$PRWINTERVAL
     fi
     if [ $proccount -gt 0 ]; then
       let stackavg=$stacktime/$proccount
       echo `date`: "Stacks complete after $stacktime seconds ($proccount stacks - average seconds: $stackavg)"
     fi

     # Fix permissions on anything missed
     prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/*

     # Dump $PRWDIR/PRW_SYS_$HOSTNAME files if in debug mode
     if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
       echo "DUMPING ORATAB FILE:"
       oratabplatform
       cat $ORATAB
       echo "DUMPING $PRWDIR/PRW_SYS_$HOSTNAME FILES:"
       find $PRWDIR/PRW_SYS_$HOSTNAME/* -exec cat {} \; -print
     fi

     # Sleep until next INTERVAL
     let CYCLE=$DATESECONDS-$PRWINTERVAL
     echo `date`: "Cycle complete after $CYCLE seconds"
     let PRWINTERVAL=PRWINTERVAL+$INTERVAL
     let MORESECONDS=$INTERVAL-$CYCLE
     if [ `echo $DATESECONDS` -lt $PRWINTERVAL ]; then
       echo `date`: "Sleeping $MORESECONDS seconds until time to run again per the INTERVAL setting ($INTERVAL seconds)"
       sleep $MORESECONDS
     else
       echo `date`: "Sleeping until time to run again - WARNING: cycle took longer than the INTERVAL ($INTERVAL seconds)"
       sleep $PROCINTERVAL
       sleep $PROCINTERVAL
     fi

     let DATESECONDS=`date +'%y'`*31556926+`date +'%m'`*2629743+`date +'%d'`*86400+`date +'%H'`*3600+`date +'%M'`*60+`date +'%S'`
     echo $DATESECONDS > $PRWDIR/PRW_SYS_$HOSTNAME/prwinterval
     prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/prwinterval
     echo $banner

    ### Check for relocate
    prwrelocate

  done
  ;;

'gdbrun')

  # Called to run gdb, set variables:
  GDB=$2
  platform=$3
  proc=$4
  proctype=$5
  procname=$6
  filename=$7
  OH=$8
  procpath=$9

  case $platform in
  Linux)
    if $GDB -nx --quiet --batch --readnever > /dev/null 2>&1; then
      gdboptions="-nx -batch --quiet --readnever -x $PRWDIR/PRW_SYS_$HOSTNAME/prw_gdb.cmd"
    else
      gdboptions="-nx -batch --quiet -x $PRWDIR/PRW_SYS_$HOSTNAME/prw_gdb.cmd"
    fi
    ;;
  HP-UX)
    gdboptions="-batch --quiet -nx -x $PRWDIR/PRW_SYS_$HOSTNAME/prw_gdb.cmd"
    ;;
    *)
    exit 0;
    ;;
  esac

  if [ $proctype = 'oracle' ]
    then nohup $GDB $gdboptions $OH/bin/oracle $proc | egrep "Thread | in " >> $filename.out 2>&1 &
  else
    if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/stack ] && [ $procname="ksh" ]; then
      $GDB $gdboptions $procpath/$procname $proc
    else
      nohup $GDB $gdboptions $procpath/$procname $proc | egrep "Thread | in " >> $filename.out 2>&1 &
    fi
  fi
  exit 0;
  ;;

'dbxrun')

  # Called to run dbx, set variables:
  DBX=$2
  platform=$3
  proc=$4
  proctype=$5
  procname=$6
  filename=$7
  OH=$8
  procpath=$9

  if [ `ps -p $proc -mo THREAD -o pid | wc -l | tr -d ' '` -gt 3 ]
    then
    # Process is multithreaded
    echo "dbx -a $proc << EOF" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd1
    echo "thread" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd1
    echo "detach" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd1
    echo "quit" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd1
    echo "EOF" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd1
    ksh $EXEDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd1 >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.out1

    cat $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.out1 | grep " no " | awk '{print $1}' | sed 's@>@@' | sed 's@$t@@' > $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.threads

    echo "dbx -a $proc << EOF" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd2
    echo "thread" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd2
    for thread in `cat $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.threads`
     do
     echo " " >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd2
     echo "prompt" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd2
     echo "thread current $thread" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd2
     echo " " >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd2
     echo "prompt" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd2
     echo "where" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd2
    done
   echo "detach" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd2
   echo "quit" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd2
   echo "EOF" >> $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd2
   nohup ksh $EXEDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd2 >> $filename.out

   rm $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd1
   rm $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.out1
   rm $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.threads
   rm $PRWDIR/PRW_SYS_$HOSTNAME/dbx_$proc.cmd2
   exit 0;

  else
    # Process is single threaded
    nohup $DBX -a $proc -c $PRWDIR/PRW_SYS_$HOSTNAME/prw_dbx.cmd | egrep "at |in |thread" >> $filename.out 2>&1 &
  fi
    exit 0;
  ;;

'shortstack')

  # Called to run shortstack, set variables:
  arg=$2
  proc=$3
  user=$4
  SID=$5
  OH=$6
  filename=$7

  # Find owner of pmon
  owner=`ps -e -o user,args | grep "_pmon" | grep $SID | egrep -v "$badlist" | awk '{print $1}'`

  if [ -z "$owner" ]; then
    echo "Could not find running instance..." >> $filename.out
    exit 1;
  fi

  # Make the shortstack .sql file
  buildshortstackscript()
  {
    # Build SQL Script
    stacks=1
    STACKCOUNTACT=`cat $PRWDIR/PRW_SYS_$HOSTNAME/stackcount_$SID`
    if [ -z "$STACKCOUNTACT" ]; then
      STACKCOUNTACT=$STACKCOUNT
      echo $STACKCOUNTACT > $PRWDIR/PRW_SYS_$HOSTNAME/stackcount_$SID
    fi
    echo "oradebug setospid $proc" > $PRWDIR/PRW_SYS_$HOSTNAME/ss_$proc.sql
    until [ $stacks -gt $STACKCOUNTACT ]; do
      echo "host date" >> $PRWDIR/PRW_SYS_$HOSTNAME/ss_$proc.sql
      echo "oradebug short_stack" >> $PRWDIR/PRW_SYS_$HOSTNAME/ss_$proc.sql
      let stacks=$stacks+1
    done
    echo "oradebug setmypid" >> $PRWDIR/PRW_SYS_$HOSTNAME/ss_$proc.sql
    echo "oradebug tracefile_name" >> $PRWDIR/PRW_SYS_$HOSTNAME/ss_$proc.sql
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/ss_$proc.sql
    chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/ss_$proc.sql
  }

  case $arg in
  'start')

    buildshortstackscript
    nohup ksh $EXEDIR/prw.sh shortstack run $proc $user $SID $OH $filename >> $filename.out 2>&1 &

    # If shortstack run process isn't around yet, sleep for 1 sec
    if [ `ps -e -o args | grep "prw.sh shortstack run $proc" | grep $SID | egrep -v "grep|COMM" | wc -l | tr -d ' '` -eq 0 ]; then
      sleep 1
    fi

    # Run on a timer, let short_stack go for 15 seconds before giving up
    for time in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
    do
      if [ `ps -e -o args | grep "prw.sh shortstack run $proc" | egrep -v "grep|COMM" | wc -l | tr -d ' '` -eq 0 ]; then
        # short stack is done?
        if [ `tail -15 $filename.out | egrep "ksedsts|fstk" | wc -l | tr -d ' '` -gt 0 ]; then

          # Short stack is done, get trace file info if need be
          if [ `tail -2 $filename.out | grep ".trc" | wc -l | tr -d ' '` -gt 0 ]; then
            tracefilename=`tail -2 $filename.out | grep ".trc"`
            tracefile2name=`echo "$tracefilename" | sed 's@.trc@.trm@'`
            if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/version_$SID ]; then
             if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/version_$SID | cut -d "." -f1` -gt 10 ]; then
              for n in 1 2 3
              do
              if [ ! -f $tracefilename ]; then
                sleep $PROCINTERVAL
              else
                break
              fi
              done
             fi
            fi
            # Remove trace file if need be
            if [ -f $tracefilename ]; then
              echo "Cleaning up trc file $tracefilename" >> $filename.out
              rm -f $tracefilename
            fi
            if [ -f $tracefile2name ]; then
              echo "Cleaning up trm file $tracefile2name" >> $filename.out
              rm -f $tracefile2name
            fi
          fi

          # Calculate avg stack time
          let avgstack=$time/$STACKCOUNTACT
          echo " " >> $filename.out
          echo "Average stack time: $avgstack seconds (rounded)" >> $filename.out
          echo " " >> $filename.out

          # Adjust stackcount if shortstack took too long
          STACKCOUNTACT=`cat $PRWDIR/PRW_SYS_$HOSTNAME/stackcount_$SID`
          if [ $avgstack -gt 1 ] && [ $STACKCOUNTACT -gt 1 ]; then
            let STACKCOUNTACT=$STACKCOUNTACT-1
            echo `date`: "Avg stack time is $avgstack seconds, adjusting STACKCOUNT down to $STACKCOUNTACT"
            echo $STACKCOUNTACT > $PRWDIR/PRW_SYS_$HOSTNAME/stackcount_$SID
          # If stackcount is good, raise stack count back up if need be
          elif [ $avgstack -lt 1 ] && [ $STACKCOUNTACT -lt $STACKCOUNT ]; then
            let STACKCOUNTACT=$STACKCOUNTACT+1
            echo `date`: "Avg stack time is $avgstack seconds, adjusting STACKCOUNT up to $STACKCOUNTACT"
            echo $STACKCOUNTACT > $PRWDIR/PRW_SYS_$HOSTNAME/stackcount_$SID
          fi

          # All done, exit
          exit 0;
        fi
      fi
      sleep 1
    done
    # The loop finished and still no short_stack, that is bad, set short_stack to false
    # ..if the process is still around
    if [ `ps -p $proc -o args | grep -v COMM | wc -l | tr -d ' '` -eq 0 ]; then
      # process is gone, exit
      exit 0
    fi

    if [ `ps -e -o args | grep "prw.sh shortstack run $proc" | grep $SID | egrep -v "grep|COMM" | wc -l | tr -d ' '` -gt 0 ]
    then
      # Debug the debugger...
      shortstackproc=`$findprocname | grep "prw.sh shortstack run $proc" | grep $SID | egrep -v "grep|COMM" | awk '{print $1}'`
      echo `date`: "Shortstack timeout, debugging shortstack process $shortstackproc"
      odbfilename=`echo "$PRWDIR/PRW_DB_$SID/prw_oradebug_"$shortstackproc"_"``date +"%m-%d-%y" | tr -d ' '`
      echo `date`: "Getting stack for oradebug pid $shortstackproc using short_stack in $odbfilename.out"
      ### Create file if it does not exist
      if [ ! -f $odbfilename.out ]; then
        echo $banner >> $odbfilename.out
        echo "Procwatcher Debugging for Process $proc $procname" >> $odbfilename.out
        prwpermissions $odbfilename.out
      fi
      if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
         nohup ksh -x $EXEDIR/prw.sh shortstack start $shortstackproc $user $SID $OH $odbfilename
      else
         nohup ksh $EXEDIR/prw.sh shortstack start $shortstackproc $user $SID $OH $odbfilename 2>&1 &
      fi
    fi

    sleep $PROCINTERVAL

    if [ `ps -e -o args | grep "prw.sh shortstack run $proc" | grep $SID | egrep -v "grep|COMM" | wc -l | tr -d ' '` -gt 0 ]
    then
      echo `date`: "WARNING: There was a problem with oradebug shortstack ($filename.out), it is disabled for sid $SID." >> $PRWDIR/prw_$HOSTNAME.log
      echo "false" > $PRWDIR/PRW_SYS_$HOSTNAME/shortstack_$SID

      psoutput=`ps -e -o args | grep "prw.sh shortstack run $proc" | egrep -v "grep|COMM"`
      echo "ps output: $psoutput"
      echo "last 15 lines of $filename.out: "
      tail -15 $filename.out
    fi

    exit 1
    ;;

  'run')
    # Fix ASM string
    if [ `echo $SID | cut -c1-3` = 'ASM' ]; then
      SID=`echo $SID | sed 's@ASM@+ASM@'`
    fi
    # Fix APX string
    if [ `echo $SID | cut -c1-3` = 'APX' ]; then
      SID=`echo $SID | sed 's@APX@+APX@'`
    fi
    # Fix MGMTDB string
    if [ `echo $SID | wc -m | tr -d ' '` -gt 6 ]; then
     if [ `echo $SID | cut -c1-6` = 'MGMTDB' ]; then
      SID=`echo $SID | sed 's@MGMTDB@-MGMTDB@'`
     fi
    fi

    # Set variables
    export ORACLE_SID=$SID
    export ORACLE_HOME=$OH
    export LD_LIBRARY_PATH=$OH/lib:usr/lib:$OH/db_1/rdbms/lib
    export PATH=$ORACLE_HOME/bin:$PATH
    export ORA_SERVER_THREAD_ENABLED=FALSE

    # Run
    if [ $user = 'root' ]; then
      PRWTMPDIR=`eval echo "~$owner"/prw`
      makeprwtmpdir $owner $PRWTMPDIR
      cp $PRWDIR/PRW_SYS_$HOSTNAME/ss_$proc.sql $PRWTMPDIR/ss_$proc.sql
      chown $owner $PRWTMPDIR/ss_$proc.sql
      # Switch to owner
      su $owner << UEOF
      sqlplus -prelim << DBEOF
      /as sysdba
      @$PRWTMPDIR/ss_$proc.sql
      exit
DBEOF
UEOF
      rm -f $PRWTMPDIR/ss_$proc.sql
    else
      sqlplus -prelim << DBEOF
      /as sysdba
      @$PRWDIR/PRW_SYS_$HOSTNAME/ss_$proc.sql
      exit
DBEOF
    fi

    rm -f $PRWDIR/PRW_SYS_$HOSTNAME/ss_$proc.sql
    exit 0;
    ;;

  'test')
    # Test to see if we can turn shortstack back on
    SIDLIST=`cat $PRWDIR/PRW_SYS_$HOSTNAME/sidlist | tr "|" " "`

    for SID in $SIDLIST
    do
    if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/shortstack_$SID` = 'false' ] \
    && [ `ps -e -o pid,args | grep "_pmon" | grep $SID | grep "shortstack run" | wc -l | tr -d ' '` -eq 0 ]; then
      proc=`ps -e -o pid,args | grep "_pmon" | grep $SID | egrep -v "$badlist" | awk '{print $1}'`
      user=`cat $PRWDIR/PRW_SYS_$HOSTNAME/user`
      # Set OH
       sid=$SID
       DBNAME=$sid
       ORATAB=$PRWDIR/PRW_SYS_$HOSTNAME/oratab
       findoratabentry

      buildshortstackscript
      nohup ksh $EXEDIR/prw.sh shortstack run $proc $user $SID $OH > $PRWDIR/PRW_SYS_$HOSTNAME/shortstack_$SID_test 2>&1 &
      prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/shortstack_$SID_test
      # Sleep 5 seconds then check...
      sleep 5
      if [ `tail -15 $PRWDIR/PRW_SYS_$HOSTNAME/shortstack_$SID_test | egrep "ksedsts|fstk" | wc -l | tr -d ' '` -gt 0 ]; then
        # Looks good, turn shortstack back on
        echo "true" > $PRWDIR/PRW_SYS_$HOSTNAME/shortstack_$SID
        echo `date`: "Shortstack re-enabled for sid $SID" >> $PRWDIR/prw_$HOSTNAME.log
        rm -f $PRWDIR/PRW_SYS_$HOSTNAME/shortstack_$SID_test
      fi
    fi
    done
    exit 0;
    ;;

  *)
    echo "Unrecognized Option, Exit" >> $filename.out
    exit 1;
  esac
  ;;

'oradebug')

  # Called to run oradebug, set variables:
  arg=$2
  ooption=$3
  proc=$4
  user=$5
  SID=$6
  OH=$7
  filename=$8

  # Find owner of pmon
  owner=`ps -e -o user,args | grep "_pmon" | grep $SID | egrep -v "$badlist" | awk '{print $1}'`

  if [ -z "$owner" ]; then
    echo "Could not find running instance..." >> $filename.out
    exit 1;
  fi

  # Make the oradebug .sql file
  buildoradebugscript()
  {
    # Build SQL Script
    echo "host date" >> $PRWDIR/PRW_SYS_$HOSTNAME/oradebug_$proc.sql
    echo "oradebug setospid $proc" >> $PRWDIR/PRW_SYS_$HOSTNAME/oradebug_$proc.sql
    echo "oradebug unlimit" >> $PRWDIR/PRW_SYS_$HOSTNAME/oradebug_$proc.sql
    echo "set echo on" >> $PRWDIR/PRW_SYS_$HOSTNAME/oradebug_$proc.sql
    if [ $ooption = 'pga' ]; then
      echo "oradebug dump heapdump 536870917" >> $PRWDIR/PRW_SYS_$HOSTNAME/oradebug_$proc.sql
    fi
    if [ $ooption = 'pga' ] || [ $ooption = 'errorstack' ]; then
      echo "oradebug dump errorstack 3" >> $PRWDIR/PRW_SYS_$HOSTNAME/oradebug_$proc.sql
    fi
    echo "oradebug tracefile_name" >> $PRWDIR/PRW_SYS_$HOSTNAME/oradebug_$proc.sql
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/oradebug_$proc.sql
    chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/oradebug_$proc.sql
  }

  case $arg in
  'start')

  buildoradebugscript
  sleep 1
  if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
    nohup ksh -x $EXEDIR/prw.sh oradebug run blah $proc $user $SID $OH $filename >> $filename.out
  else
    nohup ksh $EXEDIR/prw.sh oradebug run blah $proc $user $SID $OH $filename >> $filename.out
  fi
  exit 0

  ;;

  'run')

    # Fix ASM string
    if [ `echo $SID | cut -c1-3` = 'ASM' ]; then
      SID=`echo $SID | sed 's@ASM@+ASM@'`
    fi
    # Fix APX string
    if [ `echo $SID | cut -c1-3` = 'APX' ]; then
      SID=`echo $SID | sed 's@APX@+APX@'`
    fi
    # Fix MGMTDB string
    if [ `echo $SID | wc -m | tr -d ' '` -gt 6 ]; then
     if [ `echo $SID | cut -c1-c6` = 'MGMTDB' ]; then
      SID=`echo $SID | sed 's@MGMTDB@-MGMTDB@'`
     fi
    fi

    # Set variables
    export ORACLE_SID=$SID
    export ORACLE_HOME=$OH
    export LD_LIBRARY_PATH=$OH/lib:usr/lib:$OH/db_1/rdbms/lib
    export PATH=$ORACLE_HOME/bin:$PATH
    export ORA_SERVER_THREAD_ENABLED=FALSE

    # Run
    if [ $user = 'root' ]; then
      PRWTMPDIR=`eval echo "~$owner"/prw`
      makeprwtmpdir $owner $PRWTMPDIR
      cp $PRWDIR/PRW_SYS_$HOSTNAME/oradebug_$proc.sql $PRWTMPDIR/oradebug_$proc.sql
      chown $owner $PRWTMPDIR/oradebug_$proc.sql
      # Switch to owner
      su $owner << UEOF
      sqlplus -prelim << DBEOF
      /as sysdba
      @$PRWDIR/PRW_SYS_$HOSTNAME/oradebug_$proc.sql
      exit
DBEOF
UEOF
      rm -f $PRWTMPDIR/oradebug_$proc.sql
    else
      sqlplus -prelim << DBEOF
      /as sysdba
      @$PRWDIR/PRW_SYS_$HOSTNAME/oradebug_$proc.sql
      exit
DBEOF
    fi

    rm -f $PRWDIR/PRW_SYS_$HOSTNAME/oradebug_$proc.sql
    exit 0;
   ;;
   esac

  ;;

'deploy')

 if [ `$findprocname | grep ocssd.bin | egrep -v "$badlist" | wc -l` -gt 0 ]; then
   ### Clusterware is running
   NODECOUNT=`$CRS_HOME_BIN/./olsnodes | wc -l | tr -d ' '`
   if [ $NODECOUNT = 0 ] ; then
    NODECOUNT=1;
   fi
   if [ `$findprocname | grep "ohasd.b" | grep -v grep | wc -l` -gt 0 ]; then
     ### Newer clusterware
     CLUSTER=newcluster
     if [ `$CRS_HOME_BIN/./crsctl stat res -t | grep procwatcher | wc -l` -gt 0 ]; then
       echo "Procwatcher already registered, deregistering"
       $CRS_HOME_BIN/./crsctl stop resource procwatcher
       $CRS_HOME_BIN/./crsctl delete resource procwatcher -f
     fi
     ### If upgraded from old clusterware:
     NODELIST=`$CRS_HOME_BIN/./olsnodes | tr '\n' ' '`
     if [ `$CRS_HOME_BIN/./crs_stat | grep "procwatcher_" | wc -l | tr -d ' '` -gt 0 ]; then
      CRSPROFILEDIR=`echo $CRS_HOME_BIN | sed s@bin@crs/public@`
      for prwnode in $NODELIST
      do
       if [ `ssh $prwnode $CRS_HOME_BIN/./crs_stat | grep procwatcher_$prwnode | wc -l | tr -d ' '` -gt 0 ]; then
         echo "Procwatcher already registered, deregistering"
         $CRS_HOME_BIN/./crs_stop procwatcher_$prwnode -f
         ssh $prwnode $CRS_HOME_BIN/./crs_unregister procwatcher_$prwnode
         ssh $prwnode rm -f $CRSPROFILEDIR/procwatcher_$prwnode.cap
       fi
      done
     fi
     ### Register
     echo "Registering clusterware resource"
     $CRS_HOME_BIN/./crsctl add resource procwatcher -type application -attr "ACTION_SCRIPT=$PRWDIR/prw.sh,AUTO_START=always,STOP_TIMEOUT=300,CARDINALITY=$NODECOUNT,PLACEMENT=favored,SERVER_POOLS=*"
   else
     ### Older clusterware
     CLUSTER=oldcluster
     CRSPROFILEDIR=`echo $CRS_HOME_BIN | sed s@bin@crs/public@`
     NODELIST=`$CRS_HOME_BIN/./olsnodes | tr '\n' ' '`
     for prwnode in $NODELIST
     do
       if [ `ssh $prwnode $CRS_HOME_BIN/./crs_stat | grep procwatcher_$prwnode | wc -l | tr -d ' '` -gt 0 ]; then
         echo "Procwatcher already registered, deregistering"
         $CRS_HOME_BIN/./crs_stop procwatcher_$prwnode -f
         ssh $prwnode $CRS_HOME_BIN/./crs_unregister procwatcher_$prwnode
         ssh $prwnode rm -f $CRSPROFILEDIR/procwatcher_$prwnode.cap
       fi
       ### Register
       echo "Registering clusterware resource procwatcher_$prwnode"
       ssh $prwnode $CRS_HOME_BIN/./crs_profile -create procwatcher_$prwnode -t application -p restricted -h $prwnode -a $PRWDIR/prw.sh -o as=always,pt=15
       ssh $prwnode $CRS_HOME_BIN/./crs_register procwatcher_$prwnode
     done
   fi
   sleep 1

   NODELIST=`$CRS_HOME_BIN/./olsnodes | tr '\n' ' '`
   for prwnode in $NODELIST
   do
     echo "SETTING UP NODE $prwnode"
     if [ $prwnode != $HOSTNAME ]; then
       ssh $prwnode << EOF > /dev/null 2>&1
       if [ ! -d $PRWDIR ]; then
         mkdir -p $PRWDIR
         chmod $PRWPERM $PRWDIR
         chgrp $PRWGROUP $PRWDIR
         touch $PRWDIR/.prwdeployed
         chmod $PRWPERM $PRWDIR/.prwdeployed
         chgrp $PRWGROUP $PRWDIR/.prwdeployed
       fi
       if [ -f $PRWDIR/prw.sh ]; then
         $PRWDIR/prw.sh stop > /dev/null 2>&1
       fi
EOF
       echo "Copying Procwatcher to Node $prwnode"
       scp -p $PRWDIR/prw.sh $prwnode:$PRWDIR/prw.sh
       scp -p $PRWDIR/prwinit.ora $prwnode:$PRWDIR/prwinit.ora
      else
       touch $PRWDIR/.prwdeployed
       chmod $PRWPERM $PRWDIR/.prwdeployed
       chgrp $PRWGROUP $PRWDIR/.prwdeployed
       if [ $PRWDIR != $EXEDIR ]; then
         cp $EXEDIR/prw.sh $PRWDIR/prw.sh
         chmod $PRWPERM $PRWDIR/prw.sh
         chgrop $PRWGROUP $PRWDIR/prw.sh
         chmod u+x $PRWDIR/prw.sh
       fi
       if [ -f $PRWDIR/prw.sh ]; then
         $PRWDIR/prw.sh stop > /dev/null 2>&1
       fi
     fi
   done
   if [ $CLUSTER = 'newcluster' ]; then
     $CRS_HOME_BIN/./crsctl start res procwatcher
   else
     for prwnode in $NODELIST
     do
       $CRS_HOME_BIN/./crs_start procwatcher_$prwnode
     done
   fi
 else
   echo "Clusterware must be running with adequate permissions to deploy, exiting"
   exit
 fi

 ### Cell deploy
  if [ -f /etc/oracle/cell/network-config/cellip.ora ] && [ -f $PRWDIR/PRW_SYS_$HOSTNAME/exadatacells ]; then
   PRWDIR=/opt/oracle.procwatcher
   user=`id | cut -d "(" -f2 | cut -d ")" -f1`
   if [ $user != 'root' ]; then
     echo "Must deploy as root to examine cell nodes.  Exiting..."
     exit
   fi
   CELLNODES=`cat /etc/oracle/cell/network-config/cellip.ora | tr -d '"' | tr -d 'cell='`
   for prwcellnode in $CELLNODES
   do
     echo " "
     echo "SETTING UP CELL NODE $prwcellnode"
     ssh $prwcellnode << EOF > /dev/null 2>&1
     if [ ! -d $PRWDIR ]; then
       mkdir -p $PRWDIR
       chmod $PRWPERM $PRWDIR
       chgrp $PRWGROUP $PRWDIR
     fi
     if [ -f $PRWDIR/prw.sh ]; then
       $PRWDIR/prw.sh stop > /dev/null 2>&1
     fi
EOF
     echo "Copying Procwatcher to Node $prwcellnode"
     scp -p $EXEDIR/prw.sh $prwcellnode:$PRWDIR/prw.sh
     scp -p $EXEDIR/prwinit.ora $prwcellnode:$PRWDIR/prwinit.ora
     echo "Starting Procwatcher on Cell Node $prwcellnode"
     ssh $prwcellnode $PRWDIR/prw.sh start > /dev/null 2>&1
   done
 fi

# Assign master node to local node
touch $PRWDIR/.prw_masternode
chmod $PRWPERM $PRWDIR/.prw_masternode
chgrp $PRWGROUP $PRWDIR/.prw_masternode

# if we just relocated end it
if [ -f $HOME/.prwrelocate ]; then
  rm -f $HOME/.prwrelocate
fi

echo " "
echo "PROCWATCHER DEPLOYED"
echo " "
echo "Checking Procwatcher Status:"
echo " "
ksh $EXEDIR/prw.sh stat

 ;;

'deinstall')

cleandir()
{
echo "Cleaning up Procwatcher Directory"
echo "Copying $PRWDIR/prw.sh to $HOME/prw"
makeprwtmpdir $user $HOME/prw
cp -f $PRWDIR/prw.sh $HOME/prw 
if [ "$2" = 'pack' ]; then
 ksh $EXEDIR/prw.sh pack
 echo "Copying packed files Procwatcher_Files_`date +"%m-%d-%y"` to $HOME/prw"
 cp -f $PRWDIR/Procwatcher_Files_`date +"%m-%d-%y"`.* $HOME/prw 
 rm -f $PRWDIR/Procwatcher_Files_`date +"%m-%d-%y"`.*
fi
echo "Removing Procwatcher Files from $PRWDIR"
if [ `ls -l $PRWDIR | grep PRW_ | wc -l | tr -d ' '` -gt 0 ]; then
  rm -rf $PRWDIR/PRW_*
fi
if [ `ls -al $PRWDIR | grep .prw | wc -l | tr -d ' '` -gt 0 ]; then
  rm -rf $PRWDIR/.prw*
fi
if [ `ls -l $PRWDIR | grep prw | wc -l | tr -d ' '` -gt 0 ]; then
  rm -rf $PRWDIR/prw*
fi
# is this a TFA dir?
if [ `echo $PRWDIR | grep "/tfa" | wc -l | tr -d ' '` -gt 0 ]; then
  TFADIR=true
else
  TFADIR=false
fi
# is directory empty?
if [ `ls -l $PRWDIR | wc -l | tr -d ' '` -lt 2 ] && [ "$TFADIR" = 'false' ]; then
  echo "Removing Procwatcher Directory $PRWDIR on Node $1"
  cd ..
  rm -rf $PRWDIR
else
  if [ "$TFADIR" = 'false' ]; then
    echo "Procwatcher Directory $PRWDIR on Node $1 is not empty, unable to remove"
  else
    echo "This is a TFA directory so not removing the directory itself"
    cp $HOME/prw//prw.sh $PRWDIR
  fi
fi
}

 if [ "$2" = 'cleandir' ]; then
   cleandir $HOSTNAME
   exit
 fi

 if [ -w $HPRWINIT ]; then
   rm -f $HPRWINIT
 fi

 if [ -w $PRWDIR/.prwdeployed ]; then
  rm -f $PRWDIR/.prwdeployed
 fi

 user=`id | cut -d "(" -f2 | cut -d ")" -f1`
 if [ -f /etc/oracle/cell/network-config/cellip.ora ] && [ $user = 'root' ] && [ $EXAMINE_CELL = 'true' ]; then
   ### Cell node deinstall
   CELLNODES=`cat /etc/oracle/cell/network-config/cellip.ora | tr -d '"' | tr -d 'cell='`
   for prwcellnode in $CELLNODES
   do
     echo "Stopping and de-configuring Procwatcher on cell node $prwcellnode"
     ssh $prwcellnode /opt/oracle.procwatcher/prw.sh stop > /dev/null 2>&1
     ssh $prwcellnode rm -rf /opt/oracle.procwatcher
   done
 fi

 if [ `$findprocname | grep ocssd.bin | egrep -v "$badlist" | wc -l` -gt 0 ] && [ "$2" != 'cleandir' ]; then
   ### Clusterware is running
   if [ `$findprocname | grep "ohasd.b" | grep -v grep | wc -l` -gt 0 ]; then
     if [ `$CRS_HOME_BIN/./crs_stat | grep procwatcher | wc -l | tr -d ' '` -gt 0 ]; then
       ### Newer clusterware
       $CRS_HOME_BIN/./crsctl stop res procwatcher
       echo "De-registering procwatcher resource"
       $CRS_HOME_BIN/./crsctl delete resource procwatcher -f
     fi
   else
     ### Older clusterware
     NODELIST=`$CRS_HOME_BIN/./olsnodes | tr '\n' ' '`
     CRSPROFILEDIR=`echo $CRS_HOME_BIN | sed s@bin@crs/public@`
     for prwnode in $NODELIST
     do
       if [ `ssh $prwnode $CRS_HOME_BIN/./crs_stat | grep procwatcher_$prwnode | wc -l | tr -d ' '` -gt 0 ]; then
         echo "De-registering resource procwatcher_$prwnode"
         $CRS_HOME_BIN/./crs_stop procwatcher_$prwnode -f
         ssh $prwnode $CRS_HOME_BIN/./crs_unregister procwatcher_$prwnode
         ssh $prwnode rm -f $CRSPROFILEDIR/procwatcher_$prwnode.cap
       fi
     done
   fi
   NODELIST=`$CRS_HOME_BIN/./olsnodes | tr '\n' ' '`
   for prwnode in $NODELIST
   do
     echo "DECONFIGURING NODE $prwnode"
     if [ $prwnode != $HOSTNAME ]; then
       ssh $prwnode << EOF > /dev/null 2>&1
       if [ -f $PRWDIR/prw.sh ]; then
         $PRWDIR/prw.sh stop  > /dev/null 2>&1
       fi
EOF
     fi
   done
   if [ "$2" = 'clean' ]; then
     if [ $CLUSTERWARE = 'true' ]; then
       NODELIST=`$CRS_HOME_BIN/./olsnodes | tr '\n' ' '`
       for prwnode in $NODELIST
       do
        if [ $prwnode != $HOSTNAME ]; then
          echo "Cleaning up Procwatcher Directory on Node $prwnode"
          ssh $prwnode << EOF > /dev/null 2>&1
          ksh $PRWDIR/prw.sh deinstall cleandir
EOF
        fi
       done
     fi
     cleandir $HOSTNAME pack
   fi

   echo "Procwatcher Deinstalled"
 else
   if [ -f $PRWDIR/prw.sh ]; then
     $PRWDIR/prw.sh stop  > /dev/null 2>&1
   fi
   cleandir $HOSTNAME pack
   exit
 fi
;;

'start')

  if [ ! -f $PRWDIR/prwinit.ora ]; then
   ksh prw.sh init
  fi

  user=`id | cut -d "(" -f2 | cut -d ")" -f1`

  ### Start PRW if it isn't started already
  if [ `$findprocname | grep "prw.sh r" | grep -v grep | wc -l` -gt 0 ]
    then echo `date`: "ERROR: Procwatcher is already running"
    exit 1;
  else

  ### Don't start if this user doesn't own prw.sh
  prwowner=`ls -l $PRWDIR/prw.sh | awk '{print $3}'`
  if [ "$prwowner" != "$user" ]; then
    echo `date`: "ERROR: Procwatcher is owned by $prwowner, you are $user"
    echo " "
    echo `date`: "To run Procwatcher as $user, create a new dir and copy prw.sh to that directory"
    echo `date`: "The directory and prw.sh should be owned by $user."
    exit 1;
  fi

  ### Debug mode?
  if [ "$2" = 'debug' ]; then
      echo "debug" > $PRWDIR/PRW_SYS_$HOSTNAME/debug
      prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/debug
  fi

  ### Trace mode? (linux only right now)
  if [ "$3" = 'strace' ]; then
      echo "strace" > $PRWDIR/PRW_SYS_$HOSTNAME/strace
      prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/strace
  fi
  if [ "$3" = 'stack' ]; then
      echo "stack" > $PRWDIR/PRW_SYS_$HOSTNAME/stack
      prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/stack
  fi

    if [ $CLUSTERWARE = 'true' ] && [ "$3" != 'strace' ] &&
    [ `$findprocname | grep $PPID | grep -v grep | egrep "appagent.bin|crsd.bin" | wc -l` -eq 0 ]; then
      if [ `$findprocname | grep "ohasd.b" | grep -v grep | wc -l` -gt 0 ]; then
        ### Newer clusteware
        if [ `$CRS_HOME_BIN/./crsctl stat res -t | grep procwatcher | wc -l` -gt 0 ]; then
          ### Resource exists
          if [ "$2" = 'all' ]; then
            $CRS_HOME_BIN/./crsctl start resource procwatcher
          else
            $CRS_HOME_BIN/./crsctl start resource procwatcher -n $HOSTNAME
          fi
          exit
        else
           if [ "$2" = 'all' ]; then
             echo ""
             echo `date`: "WARNING: Procwatcher is not deployed/registered so cannot start on all nodes."
             echo `date`: "Starting on local node only."
             echo ""
           fi
        fi
      else
        ### Older clusterware
       if [ -x $CRS_HOME_BIN/./crs_stat ]; then
        if [ `$CRS_HOME_BIN/./crs_stat | grep procwatcher_$HOSTNAME | wc -l | tr -d ' '` -gt 0 ]; then
            ### Resource exists
            if [ "$2" = 'all' ]; then
              NODELIST=`$CRS_HOME_BIN/./olsnodes | tr '\n' ' '`
              for prwnode in $NODELIST
              do
                $CRS_HOME_BIN/./crs_start procwatcher_$prwnode
              done
            else
              $CRS_HOME_BIN/./crs_start procwatcher_$HOSTNAME
            fi
            exit
        fi
       fi
      fi
    fi

    echo `date`: "Starting Procwatcher as user $user"

    ### Cell startup
    if [ "$2" = 'all' ] && [ -f /etc/oracle/cell/network-config/cellip.ora ] &&
    [ -f $PRWDIR/PRW_SYS_$HOSTNAME/exadatacells ]; then
      CELLNODES=`cat /etc/oracle/cell/network-config/cellip.ora | tr -d '"' | tr -d 'cell='`
      for prwcellnode in $CELLNODES
      do
        echo "Starting Procwatcher on cell node $prwcellnode"
        ssh $prwcellnode /etc/oracle.procwatcher/prw.sh start > /dev/null 2>&1
      done
    fi

    ### Create Sys Folder if it doesn't exist
    if [ ! -d $PRWDIR/PRW_SYS_$HOSTNAME ]
      then mkdir $PRWDIR/PRW_SYS_$HOSTNAME
      prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME
    fi
    if [ ! -d $PRWDIR/PRW_SYS_$HOSTNAME ]
      then echo `date`: "ERROR: Could not make $PRWDIR/PRW_SYS_$HOSTNAME directory, check permissions.
      Exiting..."
      exit 1;
    fi

    if [ "$CLUSTERWARE" = 'false' ] && [ ! -f $PRWDIR/.prwdeployed ] && [ ! -f $PRWDIR/.prw_masternode ]; then
      # Assign master node to local node since it seems to be the only one
      touch $PRWDIR/.prw_masternode
      prwpermissions $PRWDIR/.prw_masternode
    fi

    for a in 8 7 6 5 4 3 2 1
    do
      let b=$a+1
      if [ -f $PRWDIR/prw_"$HOSTNAME".l0"$a" ]; then
        mv $PRWDIR/prw_"$HOSTNAME".l0$a $PRWDIR/prw_"$HOSTNAME".l0$b
      fi
    done
    if [ -f $PRWDIR/prw_$HOSTNAME.log ]; then
      mv $PRWDIR/prw_$HOSTNAME.log $PRWDIR/prw_"$HOSTNAME".l01
    fi
    touch $PRWDIR/prw_$HOSTNAME.log
    prwpermissions $PRWDIR/prw_$HOSTNAME.log

    if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
      nohup ksh -x $PRWDIR/prw.sh run $2 >> $PRWDIR/prw_$HOSTNAME.log 2>&1 &
      if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/stack ]; then
        sleep 1
        echo "Stack output is being written to $PRWDIR/prw_stack.out"
        nohup ksh $PRWDIR/prw.sh trace > $PRWDIR/prw_stack.out 2>&1 &
      fi
    else
      nohup ksh $PRWDIR/prw.sh run >> $PRWDIR/prw_$HOSTNAME.log 2>&1 &
    fi
    echo " "
    echo `date`: $preamble1
    echo `date`: $preamble2
    echo `date`: $preamble3
    echo " "
    echo "Procwatcher files will be written to: $PRWDIR"
    echo " "
    echo `date`: "Started Procwatcher"
    if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/strace ]; then
      sleep 1
      echo " "
      echo "Procwatcher is using strace to debug itself"
      echo "Strace output is being written to $PRWDIR/prw_strace.out"
      echo "Cntrl-C to stop strace after diags collected"
      echo " "
      echo "After completing, run the following to clean up procwatcher processes:"
      echo "kill "`$findprocname | grep prw.sh | grep -v grep | awk '{print $1}'`
      prwrunpid=`$findprocname | grep "prw.sh run" | grep -v grep | awk '{print $1}'`
      strace -p $prwrunpid -Tttqfo $PRWDIR/prw_strace.out
    fi
    # Did prw really start?
    if [ `$findprocname | grep "prw.sh run" | grep -v grep | wc -l` -eq 0 ]; then
      sleep 1
      if [ `$findprocname | grep "prw.sh run" | grep -v grep | wc -l` -eq 0 ]; then
        # Procwatcher didn't start correctly
        exit 1;
      fi
    else
      exit 0;
    fi
  fi
  ;;

'trace')

  # Linux only at this time
  while [ 0 -ne 1 ]; do
    prwrunpid=`$findprocname | grep "prw.sh run" | egrep -v "prw.sh trace|grep" | awk '{print $1}'`
    prwpids=`ps -e -o pid,ppid,args | egrep "prw.sh|$prwrunpid" | egrep -v "prw.sh trace|grep" | awk '{print $1}'`
    echo "Procwatcher pids:"
    ps -efl | egrep "prw.sh|$prwrunpid" | egrep -v "prw.sh trace|grep"
    echo " "
    for prwpid in $prwpids
    do
      date
      echo "Gathering data for pid $prwpid"
      ps -p $prwpid -fl
      echo " "
      echo "Open File Descriptors:"
      ls -l /proc/$prwpid/fd
      echo " "
      echo "Stack for pid $prwpid :"
      if [ -f /usr/bin/pstack ]; then
       /usr/bin/pstack $prwpid
      else
       ksh $EXEDIR/prw.sh gdbrun $GDB $platform $prwpid ksh ksh $PRWDIR/prw_stack /usr/bin /usr/bin
      fi
      echo " "
      sleep 1
    done
    sleep 5
  done
  ;;

'stop'|'clean')

cleanprocwatcher_pids()
{
  if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
    set -x
  fi

  if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/sidlist ] && [ -f $PRWDIR/PRW_SYS_$HOSTNAME/SQLdrop_procwatcher_pids.sql ]; then
    for sid in `cat $PRWDIR/PRW_SYS_$HOSTNAME/sidlist | tr "|" " "`
    do
      sqlsid=$sid
      isinstanceup
      if [ $isinstanceup -gt 0 ] && [ `echo $sqlsid | cut -c1-3` != 'ASM' ]; then
        echo `date`: "Cleaning up temp table on SID $sid"
        DBNAME=$sid
        ORATAB=$PRWDIR/PRW_SYS_$HOSTNAME/oratab
        findoratabentry
       if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
        ksh -x $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLdrop_procwatcher_pids $user $sid $OH 2>&1
       else
        ksh $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/SQLdrop_procwatcher_pids $user $sid $OH 2>&1 &
       fi
      fi
    done
    for i in 1 2 3
    do
      if [ `$findprocname | grep "prw.sh sqlstart" | grep SQLdrop_procwatcher_pids | grep -v grep | wc -l | tr -d ' '` -gt 0 ]; then
        sleep 1
      fi
    done
  fi
}

  if [ `$findprocname | grep "prw.sh run" | grep -v grep | wc -l` -eq 0 ]
    then echo `date`: "Procwatcher is not running"
  else
    user=`id | cut -d "(" -f2 | cut -d ")" -f1`
    if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/user ]; then
      prwuser=`cat $PRWDIR/PRW_SYS_$HOSTNAME/user`
    else
      prwuser=$user
    fi
    if [ "$user" != "$prwuser" ] && [ "$user" != 'root' ]; then
      echo `date`: "Procwatcher was started as user $prwuser, you are user $user..."
      if [ "$prwuser" = 'root' ]; then
        echo `date`: "Please stop Procwatcher with the root user"
      else
        echo `date`: "Please stop Procwaatcher with user $prwuser or root"
      fi
      exit 1
    fi

    if [ $CLUSTERWARE = 'true' ] &&
    [ `$findprocname | grep $PPID | grep -v grep | egrep "appagent.bin|crsd.bin" | wc -l` -eq 0 ]; then
      cleanprocwatcher_pids
      if [ `$findprocname | grep "ohasd.b" | grep -v grep | wc -l` -gt 0 ]; then
        ### Newer clusteware
        if [ `$CRS_HOME_BIN/./crsctl stat res -t | grep procwatcher | wc -l` -gt 0 ]; then
          ### Resource exists
          if [ "$2" = 'all' ]; then
            $CRS_HOME_BIN/./crsctl stop resource procwatcher
          else
            $CRS_HOME_BIN/./crsctl stop resource procwatcher -n $HOSTNAME
          fi
          exit
        fi
      else
        ### Older clusterware
       if [ -x $CRS_HOME_BIN/./crs_stat ]; then
        if [ `$CRS_HOME_BIN/./crs_stat | grep procwatcher_$HOSTNAME | wc -l | tr -d ' '` -gt 0 ]; then
          ### Resource exists
            if [ "$2" = 'all' ]; then
              NODELIST=`$CRS_HOME_BIN/./olsnodes | tr '\n' ' '`
              for prwnode in $NODELIST
              do
                $CRS_HOME_BIN/./crs_stop procwatcher_$prwnode
              done
            else
              $CRS_HOME_BIN/./crs_stop procwatcher_$HOSTNAME
            fi
          exit
        fi
       fi
      fi
     fi

    if [ $CLUSTERWARE != 'true' ]; then
      cleanprocwatcher_pids
    fi

    kill `$findprocname | egrep "prw.sh r|prw.sh h|prw.sh g|prw.sh o|strace -fo PRW" | grep -v egrep | awk '{print $1}'`
    if [ $HOSTNAME == `hostname | cut -d '.' -f1` ]; then
      echo $banner >> $PRWDIR/prw_$HOSTNAME.log
      echo `date`: "END PROCWATCHER" >> $PRWDIR/prw_$HOSTNAME.log
      echo `date`: "Stopping Procwatcher"
      echo " "
    fi
  fi

    if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
      set -x
    fi

  count=1
  echo `date`: "Checking for stray debugging sessions...(waiting 1 second)"
  sleep 1
  until test $count -eq 6
  do
    if [ `$findprocname | egrep "$debugprocs" | grep -v grep | wc -l` -gt 0 ]
    then
     echo `date`: "There are debugging sessions still running:"
     echo " "
     $findprocname | egrep "$debugprocs|COMMAND" | grep -v grep
     echo " "
     echo `date`: "Checking again for stray debugging sessions...(waiting 2 seconds)"
     sleep 2
     let count=count+1
    else
     echo `date`: "No debugging sessions found, all good, exiting..."
     if [ `$findprocname | grep "prw.sh" | egrep -v "grep|stop" | wc -l` -gt 0 ]; then
       kill -9  `$findprocname | grep "prw.sh" | egrep -v "grep|stop|deploy|deinstall" |  awk '{print $1}'`
     fi
    rm -f $PRWDIR/PRW_SYS_$HOSTNAME/*
    touch $PRWDIR/PRW_SYS_$HOSTNAME/proclist
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/proclist
    echo " "
    echo `date`: $preamble1
    echo `date`: $preamble2
    echo `date`: $preamble3
    echo " "
    echo `date`: "Procwatcher Stopped"
    exit 0;
    fi
  done
  echo `date`: "WARNING: Debug sessions may need to be killed, Exiting..."
  if [ `$findprocname | grep "prw.sh" | egrep -v "grep|stop|deploy|deinstall" | wc -l` -gt 0 ]; then
    kill -9  `$findprocname | grep "prw.sh" | egrep -v "grep|stop|deploy|deinstall" |  awk '{print $1}'`
  fi
rm -f $PRWDIR/PRW_SYS_$HOSTNAME/*
touch $PRWDIR/PRW_SYS_$HOSTNAME/proclist
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/proclist
    echo " "
    echo `date`: "Procwatcher Stopped"
exit 0;
  ;;

'dir'|'directory')
echo "Procwatcher Directory is: $PRWDIR"
  ;;

'help'|'-h'|'h')
echo " "
echo "Usage:  prw.sh <verb>"
echo "TFA Syntax: tfactl prw <verb>"
echo " "
echo "Verbs are:"
echo " "
if [ $CLUSTERWARE = 'true' ]; then
echo "deploy [directory] - Register Procwatcher in Clusterware and propagate to all nodes"
fi
echo "start [all] - Start Procwatcher on local node, if 'all' is specified, start on all nodes"
echo "stop [all] - Stop Procwatcher on local node, if 'all' is specified, stop on all nodes"
echo "stat - Check the current status of Procwatcher"
echo "pack - Package up Procwatcher files (on all nodes) to upload to support"
echo "param - Check current Procwatcher parameters"
if [ $CLUSTERWARE = 'true' ]; then
  echo "deinstall [clean] - Deregister Procwatcher from Clusterware and optionally remove the Procwatcher directory (clean)"
else
  echo "deinstall [clean] - Stop Procwatcher and remove the Procwatcher directory (clean)"
fi
echo "log [number] - See the last [number] lines of the procwatcher log file"
echo "log [runtime] - See contiuous procwatcher log file info - use Cntrl-C to break"
echo "init [directory] - Create a default prwinit.ora file"
echo "dir - Display Procwatcher directory"
echo "help - What you are looking at..."
echo " "
  ;;

'param'|'parameters')
echo `date`: PROCWATCHER VERSION: $VERSION
if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
  echo `date`: KSH Version:
  ksh --version
fi
logparametersettings
  ;;

'log')
LINES=$2
if [ -z "$LINES" ]; then
  LINES=20
fi
if [ -f $PRWDIR/prw_$HOSTNAME.log ]; then
 if [ "$LINES" = 'runtime' ]; then
  tail -f $PRWDIR/prw_$HOSTNAME.log
 else
  tail -$LINES $PRWDIR/prw_$HOSTNAME.log
 fi
else
 echo `date`: "Procwatcher log $PRWDIR/prw_$HOSTNAME.log does not exist"
fi
  ;;

'stat'|'check'|'status')

$PRWDIR/prw.sh parameters
echo " "

  if [ `$findprocname | grep "prw.sh run" | grep -v grep | wc -l | tr -d ' '` -gt 0 ]; then
   STATE=0
   echo `date`: "Procwatcher is currently running on local node $HOSTNAME"
  else
   STATE=1
   echo `date`: "Procwatcher is not running on local node $HOSTNAME"
   $findprocname | grep "prw.sh run" | grep -v grep
  fi
   echo `date`: "Procwatcher files are be written to: $PRWDIR"
   echo " "
  if [ "$STATE" = 0 ]; then
   echo `date`: "There are `ps -e -o args | egrep "$debugprocs" | grep -v grep | wc -l | tr -d ' '` concurrent debug sessions running..."
   if [ `ps -e -o args | egrep "$debugprocs" | grep -v grep | wc -l | tr -d ' '` -gt 0 ]; then
     echo `date`: "Debug sessions:"
     ps -e -o args | egrep "$debugprocs" | grep -v grep
   fi
  fi
   if [ `$findprocname | grep ocssd.bin | egrep -v "$badlist" | wc -l` -gt 0 ]; then
     ### Clusterware is running
     NODELIST=`$CRS_HOME_BIN/./olsnodes | tr '\n' ' '`
    if [ `$findprocname | grep $PPID | grep -v grep | egrep "appagent.bin|crsd.bin" | wc -l` -eq 0 ]; then
     echo " "
     echo `date`: "PROCWATCHER CLUSTERWARE STATUS:"
     echo " "
     if [ `$findprocname | grep "ohasd.b" | grep -v grep | wc -l` -gt 0 ] && [ "$CRSREGISTERED" = 'true' ]; then
       $CRS_HOME_BIN/./crsctl stat res procwatcher
     else
       for prwnode in $NODELIST
       do
         $CRS_HOME_BIN/./crs_stat procwatcher_$prwnode
       done
     fi
    fi

     if [ -f /etc/oracle/cell/network-config/cellip.ora ] && [ -f $PRWDIR/PRW_SYS_$HOSTNAME/exadatacells ]; then
       CELLNODES=`cat /etc/oracle/cell/network-config/cellip.ora | tr -d '"' | tr -d 'cell='`
       for prwcellnode in $CELLNODES
       do
         cellhost=`ssh $prwcellnode hostname | cut -d '.' -f1`
         if [ `ssh $prwcellnode $findprocname | grep "prw.sh run" | grep -v grep | wc -l; exit` -gt 0 ]; then
           echo `date`: "Procwatcher is currently running on cell node $cellhost $prwcellnode"
         else
           echo `date`: "Procwatcher is not running on cell node $cellhost $prwcellnode"
         fi
       done
     fi

   fi

  exit $STATE;

  ;;

'pack')

  echo `date`: "Packing Procwatcher Files..."

  LOCALDIR=`pwd`
  cd $PRWDIR
  filename=prw_"$HOSTNAME"_`date +"%m-%d-%y"`
  source="prw.sh prwinit.ora prw*log prw*.l0* PRW_*/*"
  prwpack
  cd $LOCALDIR

  if [ $CLUSTERWARE = 'true' ]; then
    CRS_HOME_BIN=`$findprocname | grep ocssd.bin | egrep -v "$badlist" | awk '{print $2}' | sed s@/ocssd.bin@@ | grep -v sed`
    NODELIST=`$CRS_HOME_BIN/./olsnodes | tr '\n' ' '`
    for prwnode in $NODELIST
    do
     typeset -l HOSTNAME
     if [ $prwnode != $HOSTNAME ]; then
      echo "Getting files from node $prwnode"
      cd $PRWDIR
      filename=prw_"$prwnode"_`date +"%m-%d-%y"`
      ssh $prwnode $PRWDIR/prw.sh packlocal $filename
      scp -p $prwnode:$PRWDIR/$filename* $PRWDIR
     fi
    done
  fi

  if [ -f /etc/oracle/cell/network-config/cellip.ora ] && [ -f $PRWDIR/PRW_SYS_$HOSTNAME/exadatacells ]; then
    CELLNODES=`cat /etc/oracle/cell/network-config/cellip.ora | tr -d '"' | tr -d 'cell='`
    for prwcellnode in $CELLNODES
    do
      cellhost=`ssh $prwcellnode hostname | cut -d '.' -f1`
      echo "Getting files from cell node $cellhost"
      cd $PRWDIR
      filename=prw_"$cellhost"_`date +"%m-%d-%y"`
      ssh $prwcellnode /opt/oracle.procwatcher/prw.sh packlocal $filename
      scp -p $prwcellnode:/opt/oracle.procwatcher/$filename* $PRWDIR
    done
  fi

  if [ $CLUSTERWARE = 'true' ]; then
    cd $PRWDIR
    filename=$LOCALDIR/Procwatcher_Files_`date +"%m-%d-%y"`
    source="prw_*`date +"%m-%d-%y"`*"
    prwpack
    rm -rf $LOCALDIR/prw_*`date +"%m-%d-%y"`*
  fi

  echo " "
  echo `date`: $preamble1
  echo `date`: $preamble2
  echo `date`: $preamble3
  echo " "
  echo "File name is $filename$suffix"
  echo " "
  echo "ls -l $filename$suffix"
  ls -l $filename$suffix
  echo " "
  echo "If necessary, upload this file to Oracle Support Services"
  echo " "
  ;;

'packlocal')

  cd $PRWDIR
  filename="$2"
  source="prw.sh prwinit.ora prw*log prw*.l0* PRW_*/*"
  prwpack
  ;;

'starthousekeeper')

  if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
    nohup ksh -x $EXEDIR/prw.sh housekeeper $RETENTION >> $PRWDIR/prwhkdebug.log 2>&1 &
    if [ ! -f $EXEDIR/prwhkdebug.log ]; then
      sleep 1
    fi
    prwpermissions prwhkdebug.log
  else
     nohup ksh $EXEDIR/prw.sh housekeeper $RETENTION >> $PRWDIR/prw_$HOSTNAME.log 2>&1 &
  fi
  exit

;;

'housekeeper')
  keeplogtime=$RETENTION
  ### Wake up every 2*INTERVAL and clean up logs older than $keeplogtime
  while [ 1 -ne 0 ]; do
    let HKINTERVAL=$INTERVAL*2
    sleep $HKINTERVAL
    echo `date`: "Housekeeper: Cleaning up old files and directories > "$keeplogtime" days old"
    if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/sidlist ]; then
      for sid in `cat $PRWDIR/PRW_SYS_$HOSTNAME/sidlist | tr "|" " "`
      do
        if [ -d $PRWDIR/PRW_DB_$sid ]; then
          find $PRWDIR/PRW_DB_$sid -mtime +$keeplogtime -exec rm -rf {} \;
        fi
      done
    fi
    if [ -d $PRWDIR/PRW_CLUSTER ]; then
      find $PRWDIR/PRW_CLUSTER -mtime +$keeplogtime -exec rm -rf {} \;
    fi
    if [ -d $PRWDIR/PRW_CELL ]; then
      find $PRWDIR/PRW_CELL -mtime +$keeplogtime -exec rm -rf {} \;
    fi
    if [ `ls -l | grep $PRWDIR/PRW_DB | wc -l` -gt 0 ]; then
      find $PRWDIR/PRW_DB_* -mtime +$keeplogtime -exec rm -rf {} \;
    fi
    find $PRWDIR/prw_"$HOSTNAME"* -mtime +$keeplogtime -exec rm -f {} \;

    restartprw()
    {
      LASTREBOOT=0
      let DATESECONDS=`date +'%y'`*31556926+`date +'%m'`*2629743+`date +'%d'`*86400+`date +'%H'`*3600+`date +'%M'`*60+`date +'%S'`
      if [ -f  $PRWDIR/PRW_SYS_$HOSTNAME/lastreboot ]; then
         LASTREBOOT=`cat $PRWDIR/PRW_SYS_$HOSTNAME/lastreboot`
      fi
      let BOOTDIFF=$DATESECONDS-$LASTREBOOT
      if [ $BOOTDIFF -gt 3600 ]; then
        kill `$findprocname | egrep "prw.sh r" | grep -v egrep | awk '{print $1}'`
        if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
          nohup ksh -x $EXEDIR/prw.sh run $2 >> $PRWDIR/prw_$HOSTNAME.log 2>&1 &
        else
          nohup ksh $EXEDIR/prw.sh run >> $PRWDIR/prw_$HOSTNAME.log 2>&1 &
        fi
        echo $DATESECONDS > $PRWDIR/PRW_SYS_$HOSTNAME/lastreboot
        prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/lastreboot
        echo `date`: "WARNING: Procwatcher run process appears to be stuck, re-starting"
        echo `date`: "Procwatcher run process restarted"
      fi
    }

    ### Kick prw.sh run if it's stuck
    if [ `tail -3 $PRWDIR/prw_"$HOSTNAME".log | grep "Housekeeper: Cleaning up" | wc -l` -eq 3 ]; then
      restartprw
    fi
    ## Scenario 2
    if [ "$user" != 'root' ]; then
      if [ `$findprocnameuser | grep "_pmon" | grep "$user" | grep -v grep | wc -l | tr -d ' '` -gt 0 ]; then
         if [ `tail -40 $PRWDIR/prw_"$HOSTNAME".log | grep "any SIDs to debug" | wc -l | tr -d ' '` -gt 3 ]; then
           # PRW has nothing to do, maybe errneously
           restartprw
         fi
      fi
    else
      if [ `$findprocnameuser | grep "_pmon" | grep -v grep | wc -l | tr -d ' '` -gt 0 ]; then
         if [ `tail -40 $PRWDIR/prw_"$HOSTNAME".log | grep "any SIDs to debug" | wc -l | tr -d ' '` -gt 3 ]; then
           # PRW has nothing to do, maybe errneously
           restartprw
         fi
      fi
    fi

    ### Archive log if greater than 20mb
    if [ `du -k $PRWDIR/prw_"$HOSTNAME".log | awk '{print $1}'` -gt 20000 ]; then
      ### Wait until the end of the interval to do this...
      until [ `tail -10 $PRWDIR/prw_"$HOSTNAME".log | grep "until time to run again" | wc -l` -gt 0 ]; do
       sleep 1
      done
      ### Archive...
      for a in 8 7 6 5 4 3 2 1
      do
        let b=$a+1
        if [ -f $PRWDIR/prw_"$HOSTNAME".l0$a ]; then
          mv $PRWDIR/prw_"$HOSTNAME".l0$a $PRWDIR/prw_"$HOSTNAME".l0$b
        fi
      done
      cp $PRWDIR/prw_"$HOSTNAME".log $PRWDIR/prw_"$HOSTNAME".l01
      echo $banner > $PRWDIR/prw_"$HOSTNAME".log
      echo "Procwatcher Version $VERSION Resuming (new log)" >> $PRWDIR/prw_$HOSTNAME.log
      if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
        echo `date`: KSH Version:
        ksh --version
      fi
      SIDLIST=`cat $PRWDIR/PRW_SYS_$HOSTNAME/sidlist`
      logparametersettings
      prwpermissions $PRWDIR/prw*log
    fi

    for SID in `cat $PRWDIR/PRW_SYS_$HOSTNAME/sidlist | tr "|" " "`
    do
      ### Testing to see if we can turn shortstack back on
     if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/shortstack_$SID ] && [ -f $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$SID ]; then
      if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/shortstack` = 'true' ] && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/shortstack_$SID` = 'false' ]; then
        nohup ksh $EXEDIR/prw.sh shortstack test none none _pmon 2>&1
      fi
      ### See if we can turn gv$ views back on
      if [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$SID` = 'v' ] && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/israc_$SID` = 'true' ] && [ "$use_gv" = 'y' ] && [ "$USE_SQL" = 'true' ]; then
        if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep disabled_SQL | grep "$SID"SQLgv | wc -l | tr -d ' '` -gt 0 ]; then
          for sqlfile in `ls $PRWDIR/PRW_SYS_$HOSTNAME | grep "disabled_SQL_"$SID"SQLgv" | tr '\n' ' '`
          do
            let DOUBLEIDLECPU=$IDLECPU*2
            sqlname=`grep SQL $PRWDIR/PRW_SYS_$HOSTNAME/$sqlfile | awk '{print $1}'`
            failcount=`grep $sqlname $PRWDIR/PRW_SYS_$HOSTNAME/$sqlfile | awk '{print $2}'`
            lastfail=`grep $sqlname $PRWDIR/PRW_SYS_$HOSTNAME/$sqlfile | awk '{print $3}'`
            let DATESECONDS=`date +'%y'`*31556926+`date +'%m'`*2629743+`date +'%d'`*86400+`date +'%H'`*3600+`date +'%M'`*60+`date +'%S'`
            let timesincelastfail=$DATESECONDS-$lastfail
            if [ $failcount -lt 3 ] && [ $timesincelastfail -gt 7200 ]; then
              #Wait until end of cycle and load is low...or give up and better luck next time
              throttlecontrol
              halfthrottle
              count=1
              until [ `tail -10 $PRWDIR/prw_"$HOSTNAME".log | grep "until time to run again" | wc -l` -gt 0 ] \
              && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/idlecpu` -gt $DOUBLEIDLECPU ] \
              && [ `tail -10 $PRWDIR/prw_"$HOSTNAME".log | grep "Collecting" | wc -l` -eq 0 ] || [ $count -gt $INTERVAL ]
              do
                sleep 1
                let count=count+1
              done
              if [ $count -lt $INTERVAL ] && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/idlecpu` -gt $DOUBLEIDLECPU ]; then
                # Finally have clearance to test
                echo `date`: "Housekeeper: Testing to see if gv$ views can be re-enabled." >> $PRWDIR/prw_$HOSTNAME.log
                echo "gv" > $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$SID
                # Set OH
                sid=$SID
                DBNAME=$sid
                ORATAB=$PRWDIR/PRW_SYS_$HOSTNAME/oratab
                findoratabentry

                user=`cat $PRWDIR/PRW_SYS_$HOSTNAME/user`
                nohup ksh $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/$sqlname $user $SID $OH novdollar 2>&1 &
              fi
            fi
          done
        fi
      fi
     fi
    done

  ### Check for relocate
  prwrelocate

  done
  ;;

'sqlstart')

  sqlfile=$2
  user=$3
  SID=$4
  OH=$5
  vname=$6
  sqlname=`echo $sqlfile | sed 's@'$PRWDIR'/PRW_SYS_'$HOSTNAME'/@@'`

  if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
    set -x
  fi

  ### BEGIN FUNCTIONS
  ### If there is a SQL Failure do this...
  sqlfailure()
  {
  let DATESECONDS=`date +'%y'`*31556926+`date +'%m'`*2629743+`date +'%d'`*86400+`date +'%H'`*3600+`date +'%M'`*60+`date +'%S'`
  ### Add failed SQL to the disabled list.
  if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_$SID$sqlname ]; then
    echo "$sqlname 1 $DATESECONDS" >> $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_$SID$sqlname
    prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_$SID$sqlname
  else
    ### If failed SQL was already on the disabled list, increment the failcount
    failcount=`grep $sqlname $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_$SID$sqlname | awk '{print $2}'`
    let failcount=$failcount+1
    echo "$sqlname $failcount $DATESECONDS" > $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_$SID$sqlname
  fi
  echo `date`: "$sqlname.sql is disabled for SID $SID"
  if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep disabled_SQL_$SID | grep SQLgv | wc -l | tr -d ' '` -gt 0 ]; then
    if [ `ls -l $PRWDIR/PRW_SYS_$HOSTNAME | grep disabled_SQL_$SID | grep SQLgv | wc -l | tr -d ' '` -gt 1 ] && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$SID` = 'gv' ]; then
    # 2 or more gv$ failures, disable gv$
      echo `date`: "WARNING: Too many GV$ failures, falling back to V$ views"
      echo "v" > $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$SID
    fi
  fi
  if [ `ps -e -o args | grep "prw.sh sqlrun $sqlfile" | grep $SID | egrep -v "grep|COMM" | wc -l | tr -d ' '` -gt 0 ]
  then
    sqlrunproc=`$findprocname | grep "prw.sh sqlrun $sqlfile" | grep $SID | egrep -v "grep|COMM"`
    echo `date`: "Killing sqlrun process: $sqlrunproc"
    kill `$findprocname | grep "prw.sh sqlrun $sqlfile" | grep $SID | egrep -v "grep|COMM" | awk '{print $1}'`
  fi
  echo "Contents of $sqlfile$SID.out :"
  cat $sqlfile$SID.out
  exit
  }
  ### END FUNCTIONS

  ### If SQL is disabled skip it unless it's time to re-test
  # Get corresponding v/gv name
  if [ `echo $sqlname | grep "SQLgv" | wc -l` -gt 0 ]; then
    gvname=$sqlname
    if [ -z "$vname" ]; then
      vname=`echo $sqlname | sed 's@SQLgv@SQLv@'`
    else
      vname=
    fi
  else
    gvname=`echo $sqlname | sed 's@SQLgv@SQLv@'`
    vname=$sqlname
  fi
  # Something related to this query is disabled...figure out what to do...
  if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_$SID$vname ] || [ -f $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_$SID$gvname ]; then
    for sql in $gvname $vname
    do
      if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/$sql.sql ]; then
        # This is probably because no corresponding gv$ view exists
        continue
      fi
      if [ `echo $sql | grep "SQLgv" | wc -l` -gt 0 ] && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/viewtype_$SID` = 'v' ]; then
        # This is a gv$ query and gv$ views are disabled
        continue
      fi
      if [ ! -f $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_$SID$sql ]; then
        # SQL is fine, run it
        retest=na
        break
      fi
      let DATESECONDS=`date +'%y'`*31556926+`date +'%m'`*2629743+`date +'%d'`*86400+`date +'%H'`*3600+`date +'%M'`*60+`date +'%S'`
      LASTFAILSECONDS=`grep $sqlname $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_$SID$sql | awk '{print $3}'`
      let RETESTSECONDS=$DATESECONDS-$LASTFAILSECONDS
      failcount=`grep $sql $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_$SID$sql | awk '{print $2}'`
      # Set the time for our next test
      if [ $failcount -eq 1 ]; then
        retestseconds=600
      elif [ $failcount -eq 2 ]; then
        retestseconds=7200
      fi
      # SQL is completely disabled
      if [ $failcount -gt 2 ]; then
        # If this is gv$, try v$ instead
        if [ `echo $sql | grep "SQLgv" | wc -l` -gt 0 ]; then
          continue
        else
          # If this is v$ and it's broken, skip it...
          echo `date`: "Skipping SQL $sqlname.sql for $SID - after 3 failures it is disabled until Procwatcher is restarted."
          exit
        fi
      else
        if [ $IDLECPU -lt 30 ]; then
          let IDLECPU=30
        fi
        if [ $RETESTSECONDS -gt $retestseconds ] && [ `cat $PRWDIR/PRW_SYS_$HOSTNAME/idlecpu` -gt $IDLECPU ]; then
          # Time to re-test
          retest=true
          break
        else
          # Not time to re-test
          # If this is gv$, use v$ instead
          if [ `echo $sql | grep "SQLgv" | wc -l` -gt 0 ]; then
            continue
          else
            retest=false
            let nexttest=$retestseconds-$RETESTSECONDS
            break
          fi
        fi
      fi
    done
  else
    retest=na
  fi

  if [ -n "$sql" ]; then
    sqlname=$sql
    sqlfile=$PRWDIR/PRW_SYS_$HOSTNAME/$sqlname
  fi

  ### Run SQL if we have the right status
  if [ "$retest" = 'true' ]; then
    echo `date`: "Testing $sqlname.sql to see if it can be re-enabled"
    nohup ksh $EXEDIR/prw.sh sqlrun $sqlfile $user $SID $OH > $sqlfile$SID.out 2>&1 &
 elif [ "$retest" = 'false' ]; then
    if [ $nexttest -gt 0 ]; then
      echo `date`: "Skipping disabled $sqlname.sql for $SID, it will be eligable for re-test in $nexttest seconds"
    else
      echo `date`: "Skipping disabled $sqlname.sql for $SID, it will be eligable for re-test when idlecpu is high enough ($IDLECPU)"
    fi
    exit
  elif [ "$retest" = 'na' ]; then
    echo `date`: "..SQL: Running $sqlname.sql on SID $SID"
    nohup ksh $EXEDIR/prw.sh sqlrun $sqlfile $user $SID $OH > $sqlfile$SID.out 2>&1 &
  else
    echo `date`: "Retest SQL Unknown (retest $retest), exiting..."
    exit
  fi

  # Set the SQL timeout based on the INTERVAL or if it's a GV$ SQL
  if [ $INTERVAL -lt 120 ]; then
    sqltimeout=60
  elif [ $INTERVAL -gt 360 ]; then
    sqltimeout=180
  else
    let sqltimeout=$INTERVAL/2
  fi
  if [ `echo $sqlname | grep "SQLgv" | wc -l` -gt 0 ]; then
    # It's not worth using gv$ if it's not fast.
    let sqltimeout=$sqltimeout/4
    let sqlwarning=$sqltimeout/2
  else
    let sqlwarning=$sqltimeout/4
  fi

  # If sqlrun process isn't around yet, sleep for 1 sec
  if [ `ps -e -o args | grep "prw.sh sqlrun $sqlfile" | grep $SID | egrep -v "grep|COMM" | wc -l | tr -d ' '` -eq 0 ]; then
    sleep 1
  fi

  # Run on a timer, let SQL run for sqltimeout before giving up and disabling SQL for this instance
  count=0
  while [ $count -lt $sqltimeout ]
  do
    if [ $count -eq $sqlwarning ] && [ `grep Elapsed $sqlfile$SID.out | wc -l | tr -d ' '` -eq 0 ]; then
      elapsed=`grep Elapsed $sqlfile$SID.out`
      sqlrunprocess=`ps -e -o args | grep "prw.sh sqlrun $sqlfile" | grep $SID | egrep -v "grep|COMM"`
      if [ -f $sqlfile$SID.out ]; then
        sqloutputfile="sql_output_file_exists"
      else
        sqloutputfile="sql_output_file_does_not_exist"
        elapsed="no_elapsed"
      fi
      echo `date`: "WARNING: $sqlname.sql for SID $SID still running after $sqlwarning seconds (Elapsed: $elapsed $sqloutputfile Process: $sqlrunprocess)"
    fi
    if [ `ps -e -o args | grep "prw.sh sqlrun $sqlfile" | grep $SID | egrep -v "grep|COMM" | wc -l | tr -d ' '` -eq 0 ] \
    && [ `grep Elapsed $sqlfile$SID.out | wc -l | tr -d ' '` -gt 0 ] && [ -f $sqlfile$SID.out ]; then
      ### Look for errors
      if [ `egrep -i "ORA-|SP2-" $sqlfile$SID.out | egrep -v "ORA-00942|ORA-00955|ORA-04043" | wc -l | tr -d ' '` -eq 0 ]; then
        ### SQL Successful
        if [ "$sqlname" = "SQLprocwatcher_pids" ]; then
          echo "$sqlname$SID " >> $PRWDIR/PRW_SYS_$HOSTNAME/ppids
        fi
        if [ $count -gt $sqlwarning ]; then
          elapsed=`grep Elapsed $sqlfile$SID.out`
          echo `date`: "Long running SQL $sqlname.sql on SID $SID finished: $elapsed"
        fi
        if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_$SID$sqlname ]; then
          echo `date`: "$sqlname.sql re-enabled for SID $SID"
          rm -f $PRWDIR/PRW_SYS_$HOSTNAME/disabled_SQL_$SID$sqlname
        fi
        exit
      else
        echo `date`: "WARNING: There was an error when running $sqlname.sql"
        sqlfailure
      fi
    fi
    sleep 1
    let count=$count+1
  done

  if [ `ps -e -o args | grep "prw.sh sqlrun $sqlfile" | grep $SID | egrep -v "grep|COMM" | wc -l | tr -d ' '` -gt 0 ] \
  && [ `grep Elapsed $sqlfile$SID.out | wc -l | tr -d ' '` -eq 0 ]; then
    if [ `echo $sqlfile | grep "SQLgv" | wc -l | tr -d ' '` -gt 0 ] && [ -n "$vname" ]; then
      # Try v$ view instead
      echo `date`: "GV$ view $sqlname.sql timed out. Will try $vname.sql instead..."
      throttlecontrol
      nohup ksh $EXEDIR/prw.sh sqlstart $PRWDIR/PRW_SYS_$HOSTNAME/$vname $user $SID $OH 2>&1 &
      sqlfailure
    else
      # The loop finished and still no SQL result, that is bad, disable the SQL
      echo `date`: "WARNING: There was a SQL timeout ($sqltimeout seconds) for SID $SID ($sqlname.sql)"
      sqlfailure
    fi
  fi

  ;;

'sqlrun')

  sqlfile=$2
  user=$3
  SID=$4
  OH=$5

if [ -f $PRWDIR/PRW_SYS_$HOSTNAME/debug ]; then
  set -x
fi

  # Echo custom SQL
  if [ "$sqlfile" = "$PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom1" ] || [ "$sqlfile" = "$PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom2" ] || [ "$sqlfile" = "$PRWDIR/PRW_SYS_$HOSTNAME/SQLcustom3" ]; then
    sqloptions="set echo on"
  fi

  # Find owner of pmon
  owner=`ps -e -o user,args | grep "_pmon" | grep $SID | egrep -v "$badlist" | awk '{print $1}'`

  # Fix ASM string
  if [ `echo $SID | cut -c1-3` = 'ASM' ]; then
    SID=`echo $SID | sed 's@ASM@+ASM@'`
  fi
  # Fix APX string
  if [ `echo $SID | cut -c1-3` = 'APX' ]; then
    SID=`echo $SID | sed 's@APX@+APX@'`
  fi
  # Fix MGMTDB string
  if [ `echo $SID | wc -m | tr -d ' '` -gt 6 ]; then
   if [ `echo $SID | cut -c1-6` = 'MGMTDB' ]; then
    SID=`echo $SID | sed 's@MGMTDB@-MGMTDB@'`
   fi
  fi

set -x

  # Set variables
  export ORACLE_SID=$SID
  export ORACLE_HOME=$OH
  export LD_LIBRARY_PATH=$OH/lib:usr/lib:$OH/db_1/rdbms/lib
  export PATH=$ORACLE_HOME/bin:$PATH
  export ORA_SERVER_THREAD_ENABLED=FALSE

  if [ $user = 'root' ]; then
    PRWTMPDIR=`eval echo "~$owner"/prw`
    makeprwtmpdir $owner $PRWTMPDIR
    sqlfile1=`echo $sqlfile | awk -F"/" '{print $NF}'`
    tsqlfile=$PRWTMPDIR/$sqlfile1
    cp $sqlfile.sql $tsqlfile.sql
    chown $owner $tsqlfile.sql
    # Switch to owner
    su $owner << UEOF
    sqlplus << DBEOF
    /as sysdba
    $sqloptions
    @$tsqlfile
    exit
DBEOF
UEOF
    rm -f $tsqlfile
  else
    sqlplus << DBEOF
    /as sysdba
    $sqloptions
    @$sqlfile
    exit
DBEOF
  fi
 ;;

'init')

if [ -n "$2" ]; then
  # PRWDIR is specified
  PRWDIR=$2
fi

if [ -f $EXEDIR/prwinit.ora ]; then
  cp $EXEDIR/prwinit.ora $EXEDIR/prwinit.old.bak
fi

echo `date`: "Building default prwinit.ora at $PRWDIR/prwinit.ora"
$ECHO "
#
# PROCWATCHER PARAMETERS - REVIEW CAREFULLY:
#
######################### CONFIG SETTINGS #############################
# Set EXAMINE_CLUSTER variable if you want to examine clusterware processes (default is false - or set to true):
# Note that if this is set to true you must deploy/run procwatcher as root unless using oracle restart
EXAMINE_CLUSTER=false

# Set EXAMINE_BG variable if you want to examine all BG processes (default is true - or set to false):
EXAMINE_BG=true

# Set permissions on Procwatcher files and directories (default: 764):
PRWPERM=764

# Set group on Procwatcher files and directories (default: oinstall)
PRWGROUP=oinstall

# Set RETENTION variable to the number of days you want to keep historical procwatcher data (default: 7)
RETENTION=7

# Warning e-mails are sent to which e-mail addresses?
# \"mail\" must work on the unix server
# Example: WARNINGEMAIL=john.doe@mycompanyemail.com,jane.doe@mycompanyemail.com
WARNINGEMAIL=
######################## PERFORMANCE SETTINGS #########################
# Set INVERVAL to the number of seconds between runs (default 60):
# Probably should not set below 60 if EXAMINE_CLUSTER=true
INTERVAL=60

# Set THROTTLE to the max # of stack trace sessions or SQLs to run at once (default 5 - minimum 2):
THROTTLE=5

# Set IDLECPU to the percentage of idle cpu remaining before PRW sleeps (default 3 - which means PRW will sleep if the machine is more than 97% busy - check vmstat every 5 seconds)
IDLECPU=3

# Set SIDLIST to the list of SIDs you want to examine (default is derived - format example: RAC1|ASM1|SID3)
# If setting for multiple instances for the same DB, specify each SID - example: ASM1|ASM2|ASM3
# Default: If root is starting prw, get all sids found running at the time prw was started.
#          If another user is starting prw, get all sids found running owned by that user.
SIDLIST=
#######################################################################
### Advanced Parameters: Set these if you know specifically what you are looking for

# Procwatcher log directory
# Default is $GRID_HOME/log/procwatcher if clusterware is running and this is not set
# Default is the directory where prw.sh is run if no clusterware and this is not set
PRWDIR=

# SQL Control
# Set USE_SQL variable if you want to use SQL to troubleshoot (default is true - or set to false):
# Note that v$instance will still be used to check the version on startup if USE_SQL=false.
# Also note that stack collection will always be done with USE_SQL=false.
USE_SQL=true
# Set to y to enable SQL, n to disable
sessionwait=y
lock=y
latchholder=y
gesenqueue=y
waitchains=y
rmanclient=n
sqltext=y
ash=y
# Below will take an errorstack in addition to short stacks - could write a lot of trace
# if turned on so use caution.  Set to maximum of 10 errorstacks per process per day
errorstack=n

# SGA Memory watch (default: off).  Valid values are:
# off = no SGA memory diagnostics
# diag = collect SGA memory diagnostics
# avoid4031 = collect SGA memory diagnostics and flush the shared pool to avoid ORA-4031
#             if memory fragmentation occurs
# Note that setting sgamemwatch to diag or avoid4031 will query x$ksmsp
# which may increase shared pool latch contention in some environments.
# Please keep this in mind and test in a test environment
# with load before using this setting in production.
sgamemwatch=off

# Levels for debugging before a flush if sgamemwatch=avoid4031 (default: 0 for both)
heapdump_level=0
lib_cache_dump_level=0

# Suspect Process Threshold (if # of suspect procs > <value> then collect BG process stacks)
# 2 = Get query and stack output if there is at least 2 suspect proc (default)
# 0 = Get all diags each cycle
suspectprocthreshold=2

# Warning Process Threshold (if # of suspect procs > <value> then issue a WARNING) default=10
warningprocthreshold=10

# Levels for debugging if warningprocthreshold is reached (default: 0 for both)
# If using this feature recommended values are (hanganalyze_level=3, systemstate_level=258)
# Flood control limits the dumps to a maximum of 3 per hour
hanganalyze_level=0
systemstate_level=0

# Cluster Process list for examination (seperated by \"|\"):
# Default: \"crsd.bin|evmd.bin|evmlogge|racgimon|racge|racgmain|racgons.b|ohasd.b|oraagent|oraroota|gipcd.b|mdnsd.b|gpnpd.b|gnsd.bi|diskmon|octssd.b|tnslsnr\"
# - The processes oprocd, cssdagent, and cssdmonitor are intentionally left off the list because of high reboot danger.
# - The ocssd.bin process is off the list due to moderate reboot danger.  Only add this if your css misscount is the
# - default or higher, your machine is not highly loaded, and you are aware of the tradeoff.
CLUSTERPROCS=\"crsd.bin|evmd.bin|evmlogge|racgimon|racge|racgmain|racgons.b|ohasd.b|oraagent|oraroota|gipcd.b|mdnsd.b|gpnpd.b|gnsd.bi|diskmon|octssd.b|tnslsnr\"

# DB Process list for examination (seperated by \"|\"):
# Default: \"_dbw|_smon|_pmon|_lgwr|_lmd|_lms|_lck|_lmon|_ckpt|_arc|_rvwr|_gmon|_lmhb|_rms0\"
# - To examine ALL oracle DB and ASM processes on the machine, set BGPROCS=\"ora|asm\" (not typically recommended)
BGPROCS=\"_dbw|_smon|_pmon|_lgwr|_lmd|_lms|_lck|_lmon|_ckpt|_arc|_rvwr|_gmon|_lmhb|_rms0\"

# Set to y to enable gv$views, set to n to disable gv$ views
# (makes queries a little faster in RAC but can't see other instances in reports)
# Default is derived based on if waitchains is used
use_gv=

# Set to y to get pmap data for clusterware processes.
# Only available on Linux and Solaris
use_pmap=n

# DB Versions enabled, set to y or n (this will override the SIDLIST setting)
VERSION_10_1=y
VERSION_10_2=y
VERSION_11_1=y
VERSION_11_2=y
VERSION_12_1=y
VERSION_12_2=y
VERSION_18_0=y
VERSION_19_0=y
VERSION_20_0=y

# Should we fall back to an OS debugger if oradebug short_stack fails?
# OS debuggers are less safe per bug 6859515 so default is false (or set to true)
FALL_BACK_TO_OSDEBUGGER=false

# Number of oradebug shortstacks to get on each pass
# Will automatically lower if stacks are taking too long
STACKCOUNT=3

# Point this to a custom .sql file for Procwatcher to capture every cycle.
# Don't use big or long running SQL.  The .sql file must be executable.
# Only 1 SQL per file.
# Example: CUSTOMSQL1=/home/oracle/test.sql
CUSTOMSQL1=
CUSTOMSQL2=
CUSTOMSQL3=
#######################################################################
" > $PRWDIR/prwinit.ora
prwpermissions $PRWDIR/prwinit.ora

if [ -n "$2" ]; then
  # PRWDIR is specified
  if [ $platform == 'SunOS' ] || [ $platform == 'AIX' ]; then
    # no sed -i on SunOS or AIX
    makeprwtmpdir $user $HOME/prw
    sed "s@PRWDIR=.*@PRWDIR=$PRWDIR@" $PRWDIR/prwinit.ora > $HOME/prw/prw.ora
    mv $HOME/prw/prw.ora $PRWDIR/prwinit.ora
  else
    sed -i "s@PRWDIR=.*@PRWDIR=$PRWDIR@" $PRWDIR/prwinit.ora
  fi
  cp $PRWDIR/prwinit.ora $PRWDIR/.prwinit.ora
fi

if [ "$PRWDIR" != "$EXEDIR" ]; then
  # find a writable location for hidden prwinit.ora file
  if [ -w $EXEDIR ]; then
    HPRWINIT=$EXEDIR/.prwinit.ora
  else 
    HPRWINIT=$HOME/.prwinit.ora
  fi
  cp $PRWDIR/prwinit.ora $HPRWINIT
  prwpermissions $HPRWINIT
fi

 ;;

'sqlbuilder')

$ECHO "
DROP DIRECTORY \"prwsysdir_$HOSTNAME\";
set timing on
drop table procwatcher_pids;
drop table \"procwatcher_pids_$HOSTNAME\"; " > $PRWDIR/PRW_SYS_$HOSTNAME/SQLdrop_procwatcher_pids.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLdrop_procwatcher_pids.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLdrop_procwatcher_pids.sql

$ECHO "
CREATE OR REPLACE DIRECTORY \"prwsysdir_$HOSTNAME\" as '$PRWDIR/PRW_SYS_$HOSTNAME';
set timing on
CREATE TABLE \"procwatcher_pids_$HOSTNAME\"
                   (prwpid       NUMBER(10))
     ORGANIZATION EXTERNAL
     (
       TYPE ORACLE_LOADER
       DEFAULT DIRECTORY \"prwsysdir_$HOSTNAME\"
       ACCESS PARAMETERS
       (
         records delimited by \" \"
         nologfile
         nobadfile
       )
       LOCATION ('proclist')
     )
     REJECT LIMIT UNLIMITED; " > $PRWDIR/PRW_SYS_$HOSTNAME/SQLprocwatcher_pids.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLprocwatcher_pids.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLprocwatcher_pids.sql

$ECHO "
host $ECHO \"GV SESSIONWAIT Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
set timing on
column INST format a15 tru
column PROC format a20 tru
column state format a10 tru
column event format a30 tru
column wait_class format a12 tru
select 'PROC '||spid PROC, 'INST '||instance_name INST, sw.state, sw.event, sw.p1, sw.p2, sw.p3, sw.seconds_in_wait sec
from gv\$session_wait sw, gv\$session s, gv\$process p, gv\$instance i
where (sw.sid = s.sid and sw.inst_id = s.inst_id)
and (s.paddr = p.addr and s.inst_id = p.inst_id)
and (p.inst_id = i.inst_id) and sw.wait_class != 'Idle' and sw.seconds_in_wait > 1
order by inst, sw.wait_class, sw.state, sec desc;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvsessionwait.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvsessionwait.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvsessionwait.sql

$ECHO "
host $ECHO \"V SESSIONWAIT Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
set timing on
column INST format a15 tru
column PROC format a20 tru
column state format a10 tru
column event format a30 tru
column wait_class format a12 tru
select 'PROC '||spid PROC, 'INST '||i.instance_name INST, sw.state, sw.event, sw.p1, sw.p2, sw.p3, sw.seconds_in_wait sec
from v\$session_wait sw, v\$session s, v\$process p, v\$instance i
where (sw.sid = s.sid)
and (s.paddr = p.addr)
and sw.wait_class != 'Idle' and sw.seconds_in_wait > 1
order by sw.wait_class, sw.state, sec desc;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLvsessionwait.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLvsessionwait.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLvsessionwait.sql

$ECHO "
host $ECHO \"GV LOCK Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
set timing on
column PROC format a20 tru
column INST format a15 tru
select 'PROC '||p.spid PROC, 'INST '||i.instance_name PROC, l.type, l.id1, l.id2, l.lmode, l.request, l.block
from gv\$lock l, gv\$session s, gv\$process p, gv\$instance i
where (l.request > 0 or l.block = 1)
and (l.sid = s.sid and l.inst_id = s.inst_id)
and (s.paddr = p.addr and s.inst_id = p.inst_id)
and (p.inst_id = i.inst_id)
order by type, id1, id2, l.block desc, l.lmode desc;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvlock.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvlock.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvlock.sql

$ECHO "
host $ECHO \"V LOCK Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
set timing on
column PROC format a20 tru
column INST format a15 tru
select 'PROC '||p.spid PROC, 'INST '||i.instance_name PROC, l.type, l.id1, l.id2, l.lmode, l.request, l.block
from v\$lock l, v\$session s, v\$process p, v\$instance i
where (l.request > 0 or l.block = 1)
and (l.sid = s.sid)
and (s.paddr = p.addr)
order by type, id1, id2, l.block desc, l.lmode desc;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLvlock.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLvlock.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLvlock.sql

$ECHO "
host $ECHO \"GV LATCHHOLDER Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
set timing on
column name format a40 tru
column PROC format a20 tru
column INST format a15 tru
select 'PROC '||p.spid PROC, 'INST '||i.instance_name INST, lh.laddr, lh.name, lh.gets
from gv\$latchholder lh, gv\$process p, gv\$instance i
where (lh.pid = p.pid and lh.inst_id = p.inst_id)
and p.inst_id = i.inst_id
order by 1, lh.name;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvlatchholder.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvlatchholder.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvlatchholder.sql

$ECHO "
host $ECHO \"V LATCHHOLDER Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
set timing on
column PROC format a20 tru
column INST format a15 tru
column name format a40 tru
select 'PROC '||p.spid PROC, 'INST '||i.instance_name INST, lh.laddr, lh.name, lh.gets
from v\$latchholder lh, v\$process p, v\$instance i
where (lh.pid = p.pid)
order by 1, lh.name;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLvlatchholder.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLvlatchholder.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLvlatchholder.sql

$ECHO "
host $ECHO \"V INSTANCE Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
set timing on
select 'DBVERSION '||version vers from v\$instance;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLvinstance.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLvinstance.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLvinstance.sql

$ECHO "
host $ECHO \"SGASTAT (top 20 allocations) Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
column pool format a16 tru
column name format a32 tru
column bytes format 99999999999
set timing on
select * from
(select 'POOL '||pool POOL, name, bytes from v\$sgastat
where bytes > 100000 order by bytes desc)
where rownum < 21;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgastat.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgastat.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgastat.sql

$ECHO "
host $ECHO \"HEAPDETAILS (top 20 allocations + free allocations) Snapshot Taken At:\" \`date\`
set timing on
set lines 150
set pages 100
column average_size format 9999999999.9
column max_size format 9999999999999
column avg format a4 tru
column max format a4 tru
column cmnt format a30 tru
column type format a12 tru
column duration format a12 tru
SELECT * FROM (
 SELECT ksmchidx subpool,
 'DURATION:'||ksmchdur duration,
 'CMNT: '||ksmchcom cmnt,
 ksmchcls type,
 SUM(ksmchsiz) total_size,
 COUNT(*) allocations,
 'AVG:' avg,AVG(ksmchsiz) average_size,
 MIN(ksmchsiz) min_size,
 'MAX:' max,MAX(ksmchsiz) max_size
 FROM x\$ksmsp
 GROUP BY ksmchidx, ksmchdur, ksmchcom, ksmchcls
 ORDER BY SUM(ksmchsiz))
WHERE (ROWNUM < 21 AND total_size > 10000 AND cmnt NOT LIKE 'CMNT:
free%') OR cmnt LIKE 'CMNT: free%'
order by 3,4,1,2;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMheapdetails.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMheapdetails.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMheapdetails.sql

$ECHO "
host $ECHO \"SGA Dynamic Components Snapshot Taken At:\" \`date\`
set timing on
set echo off
set lines 140
set pages 100
column pool format a40 tru
column current_size format 99999999999999999
column min_size format 99999999999999999
column max_size format 99999999999999999
column user_specified_size format 999999999999999
select current_size, min_size, max_size, user_specified_size, 'POOL:'||component pool
from v\$sga_dynamic_components order by 1 desc;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgadynamic.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgadynamic.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMsgadynamic.sql

$ECHO "
host $ECHO \"Top 20 SQL Strings Snapshot Taken At:\" \`date\`
set timing on
set lines 120
set pages 100
column sql: format a45 tru
select * from (
select 'SQL:'||substr(kglnaobj,1,40) \"SQL:\", count(*)
from x\$kglob group by substr(kglnaobj,1,40) order by 2 desc)
where rownum < 21;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMtop20sqls.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMtop20sqls.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMtop20sqls.sql

$ECHO "
host $ECHO \"SGA LRU Snapshot Taken At:\" \`date\`
set timing on
set echo off
column subpool format a10 tru
column lrunum format a20 tru
select 'MAXKSMLRNUM:'||max(KSMLRNUM) LRUNUM, 'SUBPOOL:'||KSMLRIDX subpool, KSMLRDUR duration
from x\$ksmlru
group by KSMLRIDX,KSMLRDUR
order by 2;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMlru.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMlru.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMlru.sql

$ECHO "set timing on
set echo on" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMflush.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMflush.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMflush.sql
if [ $heapdump_level -gt 0 ]; then
  $ECHO "alter session set events 'immediate trace name heapdump level $heapdump_level';" >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMflush.sql
fi
if [ $lib_cache_dump_level -gt 0 ]; then
  $ECHO "alter session set events 'immediate trace name library_cache level $lib_cache_dump_level';" >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMflush.sql
fi
$ECHO "alter system flush shared_pool;" >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLMEMflush.sql

$ECHO "set timing on
set echo on" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLhang.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLhang.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLhang.sql
if [ $hanganalyze_level -gt 0 ]; then
  $ECHO "alter session set events 'immediate trace name hanganalyze level $hanganalyze_level';" >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLhang.sql
fi
if [ $systemstate_level -gt 0 ]; then
   $ECHO "alter session set events 'immediate trace name systemstate level $systemstate_level';" >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLhang.sql
fi

$ECHO "set timing on
set echo on" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLRAChang.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLhang.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLhang.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLRAChang.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLRAChang.sql
$ECHO "oradebug setmypid" >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLRAChang.sql
if [ $hanganalyze_level -gt 0 ]; then
   $ECHO "oradebug -g all hanganalyze $hanganalyze_level" >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLRAChang.sql
fi
if [ $systemstate_level -gt 0 ]; then
   $ECHO "oradebug -g all dump systemstate $systemstate_level" >> $PRWDIR/PRW_SYS_$HOSTNAME/SQLRAChang.sql
fi

$ECHO "
host $ECHO \"V WAITCHAINS (top 100 rows) Snapshot Taken At:\" \`date\`
set pages 10000
set timing on
set lines 120
set heading off
column w_proc format a25 tru
column sid_ser format a24 tru
column instance format a20 tru
column inst format a28 tru
column ref1 format a14 tru
column ref2 format a12 tru newline
column ref3 format a12 tru newline
column ref4 format a12 tru newline
column ref5 format a12 tru newline
column ref6 format a12 tru newline
column ref7 format a30 tru newline
column wait_event format a50 tru
column p1 format a16 tru
column p2 format a16 tru
column p3 format a15 tru
column Seconds format a50 tru
column sincelw format a50 tru
column blocker_proc format a50 tru
column waiters format a50 tru
column chain_signature format a100 wra
column blocker_chain format a100 wra
select * from (
select 'PROC '||osid||' : ' REF1, 'Current Process: '||osid W_PROC,
'SID: '||SID||' SER#: '||SESS_SERIAL# SID_SER,
'INST '||i.instance_name INSTANCE, 'INST #: '||instance INST,
'PROC '||osid||' : '  REF2, 'Blocking Process: '||decode(blocker_osid,null,'<none>',blocker_osid)|| ' from Instance '||blocker_instance BLOCKER_PROC,
'Number of waiters: '||num_waiters waiters,
'PROC '||osid||' : '  REF3, 'Wait Event: ' ||wait_event_text wait_event, 'P1: '||p1 p1, 'P2: '||p2 p2, 'P3: '||p3 p3,
'PROC '||osid||' : '  REF4, 'Seconds in Wait: '||in_wait_secs Seconds, 'Seconds Since Last Wait: '||time_since_last_wait_secs sincelw,
'PROC '||osid||' : '  REF5, 'Wait Chain: '||chain_id ||': '||chain_signature chain_signature,
'PROC '||osid||' : '  REF6, 'Blocking Wait Chain: '||decode(blocker_chain_id,null,'<none>',blocker_chain_id) blocker_chain,
'-----------------------------------' ref7
from v\$wait_chains wc, v\$instance i
where wc.instance = i.instance_number (+)
AND chain_id in (select distinct chain_id from v\$wait_chains where
(( num_waiters > 0 AND (in_wait_secs > 0 OR time_since_last_wait_secs > 0))
OR ( blocker_osid IS NOT NULL
AND in_wait_secs > 5 ) ))
order by chain_id, num_waiters desc)
where rownum < 101;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLv111waitchains.sql;
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLv111waitchains.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLv111waitchains.sql

$ECHO "
host $ECHO \"V WAITCHAINS (top 100 rows) Snapshot Taken At:\" \`date\`
set pages 10000
set timing on
set lines 120
set heading off
column w_proc format a25 tru
column sid_ser format a24 tru
column instance format a20 tru
column inst format a28 tru
column ref1 format a12 tru
column ref2 format a12 tru newline
column ref3 format a12 tru newline
column ref4 format a12 tru newline
column ref5 format a12 tru newline
column ref6 format a12 tru newline
column ref7 format a12 tru newline
column ref8 format a30 tru newline
column FBLOCKER_PROC format a50 tru
column IMAGE format a50 tru
column wait_event format a50 tru
column p1 format a16 tru
column p2 format a16 tru
column p3 format a15 tru
column Seconds format a50 tru
column sincelw format a50 tru
column blocker_proc format a50 tru
column waiters format a50 tru
column chain_signature format a100 wra
column blocker_chain format a100 wra
select * from (
select 'PROC '||osid||' : ' REF1, 'Current Process: '||osid W_PROC,
'SID: '||WC.SID||' SER#: '||SESS_SERIAL# SID_SER,
'INST '||i.instance_name INSTANCE,
 'INST #: '||instance INST,
'PROC '||osid||' : '  REF2,'Blocking Process: '||decode(blocker_osid,null,'<none>',blocker_osid)||
 ' from Instance '||blocker_instance BLOCKER_PROC,
 'Number of waiters: '||num_waiters waiters,
'PROC '||osid||' : '  REF3, 'Final Blocking Process: '||decode(p.spid,null,'<none>',
 p.spid)||' from Instance '||s.final_blocking_instance FBLOCKER_PROC,
 'Program: '||p.program image,
'PROC '||osid||' : '  REF4,'Wait Event: ' ||wait_event_text wait_event, 'P1: '||wc.p1 p1, 'P2: '||wc.p2 p2, 'P3: '||wc.p3 p3,
'PROC '||osid||' : '  REF5,'Seconds in Wait: '||in_wait_secs Seconds, 'Seconds Since Last Wait: '||time_since_last_wait_secs sincelw,
'PROC '||osid||' : '  REF6,'Wait Chain: '||chain_id ||': '||chain_signature chain_signature,
'PROC '||osid||' : '  REF7,'Blocking Wait Chain: '||decode(blocker_chain_id,null,
 '<none>',blocker_chain_id) blocker_chain,
'-----------------------------------' ref8
FROM v\$wait_chains wc,
 gv\$session s,
 gv\$session bs,
 gv\$instance i,
 gv\$process p
WHERE wc.instance = i.instance_number (+)
 AND (wc.instance = s.inst_id (+) and wc.sid = s.sid (+)
 and wc.sess_serial# = s.serial# (+))
 AND (s.final_blocking_instance = bs.inst_id (+) and s.final_blocking_session = bs.sid (+))
 AND (bs.inst_id = p.inst_id (+) and bs.paddr = p.addr (+))
 AND chain_id in (select distinct chain_id from v\$wait_chains where
 (( num_waiters > 0 AND (in_wait_secs > 0 OR time_since_last_wait_secs > 0))
 OR ( blocker_osid IS NOT NULL
 AND in_wait_secs > 5 ) ))
ORDER BY chain_id,
 num_waiters DESC)
WHERE ROWNUM < 101;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLvwaitchains.sql;
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLvwaitchains.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLvwaitchains.sql

$ECHO "
host $ECHO \"RMAN Client Snapshot Taken At:\" \`date\`
set lines 140
set pages 100
set timing on
column PROC format a15 tru
column program format a35 wra
column client_info format a35 wra
column INST format a15 tru
SELECT 'PROC '||spid, 'INST '||i.instance_name INST, client_info, p.program
FROM v\$process p, v\$session s, v\$instance i
WHERE p.addr = s.paddr
AND (lower(s.client_info) LIKE '%rman%'
or lower(p.program) like '%rman%');" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLrmanclient.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLrmanclient.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLrmanclient.sql

$ECHO "
host $ECHO \"Process Memory Snapshot Taken At:\" \`date\`
set lines 140
set pages 100
set timing on
set heading off
column name format a30 tru
column value format a30 tru
select 'PARAM: '||name,value from v\$parameter 
where name like 'sga_%' or name like 'pga_%'
or name like '_sga%' or name like '_pga_%'
or name = 'processes'
order by name;
SELECT 'MINIMUM PGA_AGGREGATE_LIMIT RECOMMENDATION: '||MAX(PL)/1024/1024||'M'
FROM (
    SELECT value*3145728 AS PL
    FROM v\$parameter where name = 'processes' 
    UNION ALL
    SELECT value*2 AS PL
    FROM v\$parameter where name = 'pga_aggregate_target'
    UNION ALL
    SELECT 2147483648 As PL
    FROM dual);
column PROC format a15 tru
set heading on
SELECT * from (
SELECT 'PROC '||spid PROC, 'INST '||i.instance_name INST, username, program, pga_used_mem, pga_alloc_mem
FROM v\$process p, v\$instance i
ORDER BY pga_used_mem desc);
SELECT 'SGA:'||sum(value) from v\$sga;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLpgamemory.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLpgamemory.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLpgamemory.sql

### RAC ONLY:

$ECHO "
host $ECHO \"GV GESENQUEUE Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
set timing on
column PROC format a20 tru
column INST format a15 tru
column resource_name format a28 tru
column grant_level format a13 tru
column request_level format a13 tru
select decode(ges.pid,0,null,'PROC '||ges.pid) PROC,
'INST '||instance_name INST, ges.resource_name1 resource_name, ges.grant_level, ges.request_level
from gv\$ges_enqueue ges, gv\$instance i
where ges.inst_id = i.inst_id
and (ges.blocked=1 or ges.blocker=1)
order by ges.resource_name1, ges.blocker desc;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvgesenqueue.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvgesenqueue.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLgvgesenqueue.sql

$ECHO "
host $ECHO \"V GESENQUEUE Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
set timing on
column PROC format a20 tru
column INST format a15 tru
column resource_name format a28 tru
column grant_level format a12 tru
column request_level format a12 tru
select decode(ges.kjilkftpid,0,null,'PROC '||ges.kjilkftpid) "PROC",
'INST '||i.instance_name INST, ges.kjilkftrn1 resource_name,
ges.kjilkftgl grant_level, ges.kjilkftrl request_level
from x\$kjilkft ges, v\$instance i
where (ges.kjilkftblked=1 or ges.kjilkftblker=1)
order by ges.kjilkftrn1, ges.kjilkftblker desc;" > $PRWDIR/PRW_SYS_$HOSTNAME/SQLvgesenqueue.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLvgesenqueue.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLvgesenqueue.sql

### Make proclist query
$ECHO "
set pages 1000
set timing on
select 'PROC '||pid pid from v\$process where
spid in
(select prwpid from procwatcher_pids_$HOSTNAME);" | sed 's@,)@)@' > $PRWDIR/PRW_SYS_$HOSTNAME/SQLvProcess.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLvProcess.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLvProcess.sql

### Make sqltext query
$ECHO "
host echo \"Snapshot Taken At:\" \`date\`
set lines 1000
set pages 1000
set timing on
column sql_text format a980 tru
select distinct 'PROC '||p.spid||' - '||sq.sql_text sql_text
from v\$process p, v\$session s, v\$sql sq
where sq.sql_id = s.sql_id and s.paddr = p.addr
and p.spid in
(select prwpid from procwatcher_pids_$HOSTNAME);" | sed 's@,)@)@' > $PRWDIR/PRW_SYS_$HOSTNAME/SQLsqltext.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLsqltext.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLsqltext.sql

### Make ASH query
$ECHO "
host echo \"Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
set timing on
column inst format a15 tru
column PROC format a20 tru
column sample_time format a18 tru
column state format a10 tru
column event format a30 tru
column wait_class format a12 tru
select 'PROC '||spid PROC, ash.sample_time, ash.event, ash.p1, ash.p2, ash.p3, ash.wait_class, ash.time_waited
from v\$active_session_history ash, v\$session s, v\$process p
where ash.session_id = s.sid and s.paddr = p.addr
and sample_time > sysdate-0.0002
and p.spid in (select prwpid from procwatcher_pids_$HOSTNAME)
order by session_id, sample_time;" | sed 's@,)@)@' > $PRWDIR/PRW_SYS_$HOSTNAME/SQLash.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLash.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLash.sql

### Make ASM proclist query
$ECHO "
set pages 1000
set timing on
select 'PROC '||pid pid from v\$process;" | sed 's@,)@)@' > $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMvProcess.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMvProcess.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMvProcess.sql

### Make ASM sqltext query
$ECHO "
host echo \"Snapshot Taken At:\" \`date\`
set lines 1000
set pages 1000
set timing on
column sql_text format a980 tru
select distinct 'PROC '||p.spid||' - '||sq.sql_text sql_text
from v\$process p, v\$session s, v\$sql sq
where sq.sql_id = s.sql_id and s.paddr = p.addr;" | sed 's@,)@)@' > $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMsqltext.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMsqltext.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMsqltext.sql

### Make ASM ASH query
$ECHO "
host echo \"Snapshot Taken At:\" \`date\`
set lines 140
set pages 10000
set timing on
column inst format a15 tru
column PROC format a20 tru
column sample_time format a18 tru
column state format a10 tru
column event format a30 tru
column wait_class format a12 tru
select 'PROC '||spid PROC, ash.sample_time, ash.event, ash.p1, ash.p2, ash.p3, ash.wait_class, ash.time_waited
from v\$active_session_history ash, v\$session s, v\$process p
where ash.session_id = s.sid and s.paddr = p.addr
and sample_time > sysdate-0.0002
order by session_id, sample_time;" | sed 's@,)@)@' > $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMash.sql
prwpermissions $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMash.sql
chmod u+x $PRWDIR/PRW_SYS_$HOSTNAME/SQLASMash.sql

exit;

;;

*)
  echo `date`: "ERROR: Unrecognized Command, Valid user commands are: (start|stop|stat|pack|deploy|param|deinstall|init|help)"
  echo " "
  $EXEDIR/prw.sh help
  exit;
  ;;

esac
