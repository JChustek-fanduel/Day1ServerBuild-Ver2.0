#!/bin/sh

#Script pre-requisite is to have the name of the secondary server thru the first parmsince we may not know what
#condition the secondary server is in and therefore not be able to effectively grab that info
BASEDIR=$BACKUPDIR/EXPORTS
SERVERNAMEnode2=$1
THISSERVER=`echo $HOSTNAME`
LOG=$BASEDIR/DAY1Init.LOG
INFORMIXHOME=/home/informix
DAY1_deployDir=$BASEDIR/Day1binScripts
#SET INFORMIX ENVIRONMENT
_envFile=/etc/profile.d/informix.environment.sh
. ${_envFile}

echo "BRINGING THE SECONDARY SERVER to OFFLINE MODE...Please Wait"  | tee -a $LOG
echo 
onmode -ky

if [ $? -eq 0 }
then
echo 
echo "THE SECONDARY SERVER IS NOW OFFLINE "  | tee -a $LOG
exit 0
else
echo
echo "THE SECONDARY SERVER ENCOUNTERED POTENTIAL ISSUE WHILE GOING OFFLINE - INVESTIGATE"  | tee -a $LOG
fi

