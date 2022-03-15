# SCRIPT
# ---------
#
# Set environment variables for ORACLE_HOME, ORACLE_SID,
# and DUMPDIR -- in case of datapump --, as well as PATH if needed.
#
#

trap '' 1 # to use nohup in a shell script

# Set these to appropriate values if needed:
#
#ORACLE_HOME=
#ORACLE_SID=
#DUMPDIR=

# Customize PATH if needed
#
#PATH=/bin:/usr/bin:${ORACLE_HOME}/bin:/usr/local/bin:/usr/lbin

#export ORACLE_HOME ORACLE_SID PATH

echo "Exporting $ORACLE_SID database. start `date`"
#
expdp system/password dumpfile=scott.dmp directory=DUMPDIR schemas=scott logfile=scott.log
#
echo "Export of $ORACLE_SID database completed at `date`"

#End of Script
