-- enable and disable autorestart of CRS
Run as root user

$GRID_HOME/bin/crsctl enable crs
CRS-4622: Oracle High Availability Services autostart is enabled.

$GRID_HOME/bin/crsctl disable crs
CRS-4621: Oracle High Availability Services autostart is disabled.




-- find cluster name
$GRID_HOME/bin/cemutlo -n

or

$GRID_HOME/bin/olsnodes -c




-- stop and start CRS
-- stop crs ( run from root)

$GRID_HOME/bin/crsctl stop crs

-- start crs( run from root)

$GRID_HOME/bin/crsctl start crs



--location of OCR and Voting Disk

Find voting disk location

$GRID_HOME/bin/crsctl query css votedisk

Find OCR location.

$GRID_HOME/bin/ocrcheck




-- check cluster coponent status
$GRID_HOME/bin/crsctl stat res -t

$GRID_HOME/bin/crsctl check crs

$GRID_HOME/bin/crsctl check cssd

$GRID_HOME/bin/crsctl check crsd

$GRID_HOME/bin/crsctl check evmd



-- Get cluster interconnect status
$GRID_HOME/bin/oifcfg getif

app-ipmp0 172.21.39.128 global public
loypredbib0 172.16.3.192 global cluster_interconnect
loypredbib1 172.16.4.0 global cluster_interconnect

 

select NAME,IP_ADDRESS from v$cluster_interconnects;

NAME IP_ADDRESS
--------------- ----------------
loypredbib0 172.16.3.193
loypredbib1 172.16.4.1




-- ocr manual backups
List down the backups of OCR

$GRID_HOME/bin/ocrconfig -showbackup


Take manual OCR backup

$GRID_HOME/bin/ocrconfig -manualbackup




-- Move voting disk to new diskgroup
$GRID_HOME/bin/crsctl replace votedisk +NEW_DG

Check the status using below command

$GRID_HOME/bin/crsctl query css votedisk







--- OLS commands

-- List of nodes in the cluster
olsnodes

-- Nodes with node number
olsnodes -n

-- Node with vip
olsnodes -i
olsnodes -s -t

-- Leaf or Hub
olsnodes -a

-- Getting private ip details of the local node
olsnodes -l -p

-- Get cluster name
olsnodes -c







-- get clster full info
$ crsctl get cluster configuration
Name          : dbaclass-cluster
Configuration : Cluster
Class         : Standalone Cluster
Type          : flex
The cluster is not extended.
--------------------------------------------------------------------------------
MEMBER CLUSTER INFORMATION

Name             Version             GUID            Deployed           Deconfigured
================================================================================
================================================================================

 

$ crsctl get node role status -all
Node 'hostnode1' active role is 'hub'
Node 'hostnode2' active role is 'hub'







-- get OLR info
-- OLR(ORACLE LOCAL REGISTRY)

Get current OLR location:(run from root only)

$GRID_HOME/bin/ocrcheck -local

List the OLR backups:

$GRID_HOME/bin/ocrconfig -local -showbackup

Take manual OLR backup:

$GRID_HOME/bin/ocrconfig -local -manualbackup
