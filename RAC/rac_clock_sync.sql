Clock Synchronization across the cluster nodes

cd $GRID_HOME/bin
cluvfy comp clocksync -n all

 Check whether ctss or ntp is running

crsctl check ctss
CRS-4700: The Cluster Time Synchronization Service is in Observer mode.

Observer means - Time sync between nodes are taken care by NTP
Active means - Time sync between nodes are taken care by CTS
