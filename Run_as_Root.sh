#!/bin/sh
BACKUPDIR=/opt/informix/backups
BASEDIR=$BACKUPDIR/EXPORTS
LOG=$BASEDIR/DAY1Init.LOG
mkdir -p $BASEDIR/RUN_INDICATORS
chown informix:informix $BASEDIR/RUN_INDICATORS
chmod 755 $BASEDIR/RUN_INDICATORS
INDIR=$BASEDIR/RUN_INDICATORS

clear
echo "RUN_AS_ROOT: Change ownership and mode of /opt/informix/backups and archive Directories " | tee -a $LOG
sleep 5

#Check for User 
function checkuser
{
 _username=`echo $USER`
if [ $_username != "root" ]
then
echo
echo "  E R R O R : SCRIPT ${_scriptName} MUST BE RUN AS USER ROOT"
echo "  YOUR ARE CURRENTLY: $_username "
echo
echo "  ====== ABORTING RUN ======"
exit 100
fi
}

checkuser

#Checking for prior run of the script - we assume that the crond daemon had been stopped in prior run 
#Prompt user to restart the cron daemon

if [ -r  $INDIR/runasroot.FLG ]
then
echo 
tput smso
echo "The Run_as_root script has been run already" | tee -a $LOG
tput rmso
echo -n  "Do you want to RESTART the CROND Cron Daemon (recommended) ? (y or n) ===> "
while [ 1 = 1 ] 
do
read answer
if [ $answer = "y" ]
then 
echo "OK - Proceeding to start the Crond Daemon " | tee -a $LOG
systemctl start crond.service
echo "DONE...The Cron Daemon has been STARTED " | tee -a $LOG
ps -eaf|grep crond
break
elif  [ $answer = "n" ]
then
echo "OK..Will not stop the CROND Daemon" | tee -a $LOG
echo "You Must START the Crond Daemon manually " | tee -a $LOG
echo "RUN: systemctl start crond.service as user Root"
break
else
clear
echo "Invalid Response"
echo
tput smso
echo -n  "Do you want to START the CROND Cron Daemon (recommended) ? (y or n) ===> "
tput rmso
fi
done
exit
fi



cd /opt/informix
chown informix:informix /opt/informix/backups
chown informix:informix /opt/informix/archive
chown informix:informix /opt/informix/csdk
chown informix:informix /opt/informix/server

echo  "Completed changing owner:group to Informix for /opt/informix/backups and /opt/informix/arhive" | tee -a $LOG
echo "                                                        "
sleep 2
echo "Setting Up the .rhosts file for USER SENSU" | tee -a $LOG
cp /home/informix/.rhosts /home/sensu/.rhosts

echo  "Run_as_Root.sh: Has Ended" | tee -a $LOG
touch $INDIR/runasroot.FLG
echo "Setting Indicator " | tee -a $LOG
sleep 10
clear
tput smso
echo -n  "Do you want to STOP the CROND Cron Daemon (reccommended) ? (y or n) ===> "
tput rmso
while [ 1 = 1 ] 
do
read answer
if [ $answer = "y" ]
then 
echo "OK - Proceeding to stop the Cron Daemon " | tee -a $LOG
systemctl stop crond.service
echo "DONE...The Cron Daemon has been STOPPED "
echo "IMPORTANT NOTE: Do not forget to START the CROND Daemon After the Build is Completed"
echo "RUN: \" systemctl start crond.service \""
break
elif  [ $answer = "n" ]
then
echo "OK..Will not stop the CROND Daemon" | tee -a $LOG
echo "You Must STOP the Crond Daemon manually " | tee -a $LOG
echo "In order to Proceed with the Build"
echo "RUN: systemctl stop crond.service as user Root"
break
else
clear
echo "Invalid Response"
echo
tput smso
echo -n  "Do you want to STOP the CROND Cron Daemon (reccommended) ? (y or n) ===> "
tput rmso
fi
done

chown informix:informix $LOG
