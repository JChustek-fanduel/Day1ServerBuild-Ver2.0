#!/bin/sh

###########################################################################################
#change_mode_of_deployedscripts.sh  Makes Sure that the deployed scripts run correctly    #
###########################################################################################
BACKUPDIR=/opt/informix/backups
BASEDIR=$BACKUPDIR/EXPORTS
LOG=$BASEDIR/DAY1Init.LOG

echo "CHANGING MODE OF DEPLOYED SCRIPTS is RUNNING" | tee $LOG
###Deployed Scripts - We assume they are owned by Informix
chmod 750 Allocate_Storage_on_Secondary
chmod 750 Create_secondary_cluster.sh
chmod 750 Bring_Secondary_DB_Offline.sh
chmod 750 informix-restore.sh 
chmod 750 diff_config.sh

