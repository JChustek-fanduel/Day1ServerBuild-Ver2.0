#!/bin/sh
###############################################################################################################
########Create_secondary_cluster.sh                                                                ############ 
########This will help create the Mach11 cluster and define node 2 as the secondary in the cluster ############ 
###############################################################################################################

###MAIN RUN DIRECTORY - where the day 1 script is placed
DAY1_deployDir=$BASEDIR/Day1binScripts
THISSERVER=`echo $HOSTNAME`
LOG=$BASEDIR/DAY1Init.LOG
INFORMIXHOME=/home/informix
$1=Primary_ServerName
#SET INFORMIX ENVIRONMENT
_envFile=/etc/profile.d/informix.environment.sh
. ${_envFile}




#Parameters passed
if [[ $# -ne 1 ]] ; then
    echo "Expecting 1 Parameter: 
    echo "USAGE: Create_secondary_cluster.sh Primary ServerName"
    
fi
##############################################################################################################

echo "CREATING SECODNARY IN HDR CLUSTER..PLEASE WAIT" | tee -a $LOG 
echo "Running command : onmode -d secondary $Primary_ServerName" | gee -a $LOG
onmode -d secondary $Primary_ServerName
onstat - > /dev/null 

if [ $? -eq 2 ]
then
onstat -  | tee -a $LOG
echo "Successfully Promoted $THISSERVER to SECONDARY in HDR CLUSTER" | tee -a $LOG
else
echo "WARNING: Somehting may have gone wrong....unexpected return code - investigate" | tee -a $LOG
exit 3
fi

exit 0





