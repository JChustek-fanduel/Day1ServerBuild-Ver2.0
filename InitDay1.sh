#!/bin/sh
################################################################################################################################################################################
################################################################################################################################################################################
#
#        InitDay1.sh - Linux version
#
#       Script facilitates the automation of the building of a new Informix Server Database Instance
#
#
#	Steps  Performed:
###
############### Phase I -  Build the database instance 
###############
###             1.Safety check to make sure you are running on the server you intended
#               1a. Download the last good Level 0 Archive Backup from S3 (Colorado) - Background process 
#		2.Checks to make sure the onconfig file on both Primary and Secondary have the correct parameters and are the same
#               2a. Stops the crons from running.
#               3.Optional step to try to fix differences in onconfig if found (Ver 2.0)  - currently the script will abort with an error 
#		3.Brings both instances in the cluster offline	
#               4.Allocates the Storage expected for the Chunks on the Database Server Instance to Restore and Checks to make sure permissions are correct  
#               5.Allocates the Datadbs Dbspace chunks in /opt/informix/data/datadbs/ - The number of chunks created is set in the _numDataChunks variable
#               6.Runs Check to make sure all necessary files are in place and sqlhosts,onconfig,latest version of alarmprogram.sh and exclude files are present
#                7.Restores the Level 0 Archive Backup to recover the appropriate golden image for the next steps 
###            ----  The script gracefully exits here for manual inspection  
################ Phase II - Prepare the OPENBET database refresh
################
##              8.Exports the openbet schema
#               9.Strips the Triggers from the OPENBET schema - creating separate trigger statement file and deleting them from the original openbet schema file 
#               10. Creates sequences and edits the sequences file to start at 1 
#               11. Runs the customized unload scripts provided by openbet: unloadEnvData.sh and unloadData.sh   
#               12. Drops the legacy OPENBET database 
#               13. Creates the database openbet on the server instance
#               14. Creates the openbet schema (without triggers) that was previously captured
#               15. Creates the openbet sequences that were previously captured and reset to 1 
#               16. Loads the data to the new openbet database  - this is done as a background job that will not hang up - main script monitors this and can be restarted at this step 
#               17 Loads the Environment data to the openbet database
#               18. Recreates the triggers on the openbet database
#               19. Sets the openbet database to buffered logging 
#               20. Grant user ‘sensu’ resource  permissions in the utilsdb database
#               21. Update the utilsdb: tclusternode table to reflect the correct node names
#               22. Purge the utilsdb:tadminjobruns  run table of stale entries 
#               23. Create the dostats_exclude_openbet file in $INFORMIXDIR/etc with correct ownership and permissions
#               24. Check the kernel parameter settings on the VM
#             --- The script gracefully exits here for manual inspection and can be restarted when desired for Phase III                  
#              25. Restarts the cron jobs
#                 Display pre-requisite next steps for cluster createion
###                   - create the SSH keys for user informix and user sensu on primary server ==> secondary server
##             26.  Create the basic structure for the Tevocprice purge  - check to make sure the necessary scripts are in place
############### Phase III - Create the Mach 11 HDR Cluster  - Separate Script (Restartable from this phase)
###############
###               InitDay1Cluster.sh          
#              1. Prompts to insure informix ssh keys are created 
#              2. Runs the restore from Primary to Secondary
#              3. Attempts to establish the server as HDR Primary (ver 3.0) 
#              4. Attempts to establish the secondary server as HDR SECONDARY (ver 3.0)
#
#
#
#
#       Usage:
#
#               InitDay1.sh  PARMS=  NODE1-PRIMARY-SERVERNAME  NODE2-SECONDARY-SERVERNAME Num_SPACE_Chunks  Primary_ServerName  Secondary_ServerName node1_ip node2_ip 
#                                            Note:  parms #6 and #7 are optional - program will use them if set for scp and connection to secondary server 
#
#
#
#       Return Code:
#
#               0   - OK / GREEN
#               2   - CRITICAL / Problem Encountered - diagnostics will be issued
#
#
#       Author:     Jerry Chustek (May 2021)
#
#
#       Last Modifications:
#
#
################################################################################################################################################################################
################################################################################################################################################################################

#Script Name
_scriptName=$(basename $0)

#Function to show the usage and then exit
function showUsage {
    echo "Usage: ${_scriptName} SERVERNAME-node1  SERVERNAME-node2  Num_SPACE_Chunks  Primary_ServerName  Secondary_ServerName restart(opt) node1_ip (opt) node2_ip (opt)"
    echo "NOTE: PARAMETERS #1 through # 5 are Required"
    exit 100
}


#...parameters passed
if [[ $# -lt 5 ]] ; then
    echo "Expecting at least 5 Parameter "
    showUsage
fi

if [ ! -z $6 ]
then
 if [ $6 = "restart" ]
  then
    THIS_IS_RESTART="restart"
    tput smso
    echo "INIT DAY 1 is STARTING IN RESTART MODE WITH THE DATABASE LOAD PROCEDURE"
    tput rmso
    sleep 5
 else
    echo "The 6th Parameter has an invalid value - must be either blank or restart - aborting run"
    showUsage 
   fi
else
tput smso
    echo "STARTING INIT DAY 1 BUILD IN NORMAL MODE - not a restart"
tput rmso
sleep 3
fi
 
########SET DEFAULTS ##########
#### Number of Dbspace Chunks to Allocate for Storage Pool
#### If the number of chunks parameter is not set
##The Base Directory is the home of the Automated Script Repository including main script, subprocedures and AWS downloads scripts
BACKUPDIR=/opt/informix/backups
BASEDIR=$BACKUPDIR/EXPORTS
NUMCHUNKS=150
#####DATABASE DATA FILE SYSTEM
DATADIR=/opt/informix/data
## INDICATOR SUBDIRECTORY
INDIR=$BASEDIR/RUN_INDICATORS
download_level_0=1
awsdir=$BACKUPDIR/awsfiles
###DIRECTORY for OB INDIT DAY1 SCRIPTS and misc Data Unloads/Reloads created by scripts   
BUILDIR=$BASEDIR/OBSCRIPTS
SCHEMADATE=$(date '+%m%d%Y')
SERVERNAMEnode1=$1
SERVERNAMEnode2=$2
MAXCHUNKS=$3
PRIMARY_SERVERNAME=$4
SECONDARY_SERVERNAME=$5
###restartmode=$6
NODE1_IP=$7
NODE2_IP=$8
THISSERVER=`echo $HOSTNAME`
LOG=$BASEDIR/DAY1Init.LOG
INFORMIXHOME=/home/informix
RUN_ONLY_ON_PRIMARY=0
BYPASS_CFG_CHECK=0
special_load_restart=0
######COLORS#########
RED='\033[0;41;30m'
GREEN='\033[0;42;30m'
YELLOW='\033[0;43;30m'
BLUE='\033[0;44;30m'
PURPLE='\033[0;45;30m'
LIGHTBLUE='\033[0;46;30m'
WHITE='\033[0;47;30m'
STD='\033[0;0;39m'

##### Directory where the authoratitive onconfig Template resides 
CONFIG_TEMPLATEDIR=$BASEDIR/golden_source


###MAIN RUN DIRECTORY - where the day 1 script is placed
DAY1_deployDir=$BASEDIR/Day1binScripts

#######Check That User is INFORMIX
#####
function checkuser
{
export _username=`echo $USER`
if [ $_username != "informix" ]
then
echo
echo "  E R R O R : SCRIPT ${_scriptName} MUST BE RUN AS USER INFORMIX"
echo "  YOUR ARE CURRENTLY: $_username "
echo 
echo "  ====== ABORTING RUN ======"
exit 100
fi

}

#...Configuration part
#

#SET INFORMIX ENVIRONMENT
_envFile=/etc/profile.d/informix.environment.sh
. ${_envFile}

####_informix_env=$HOME/.bash_profile
####. ${_informix_env} > /dev/null 2>&1

#...should script run both phase one and two without exiting 
_RunThruPhase2=1



function printit ()
{
echo -n "`date` : " | tee -a  $LOG
echo $1 | tee -a $LOG
}




###FUNCTION TO MAKE SURE WE  ARE RUNNING ON THE RIGHT SERVERS
function CheckServers {


###################################################################################################################################

export is_primary_server=$(onstat - | grep On-Line | wc -l)
export HostName_base=$(hostname | cut -d '-' -f 1,2 )
export WORKDIR=/tmp
###Safety check - NOW CHECK TO MAKE SURE WE ARE ON THE CORRECT HOST VM###

if [ $SERVERTYPE = "PRIMARY" ]
then
   if [ $THISSERVER = $SERVERNAMEnode1 ]
    then 
     printit "SERVER Check Has Passed - Running on Primary HOST VM $THISSERVER" 
    else
     printit "WARNING: WRONG SERVER - Please Check Server and PARMS - ABORTING"
     exit 2
    fi
    fi

if [ $SERVERTYPE = "SECONDARY" ]
then
   if [ $THISSERVER = $SERVERNAMEnode2 ]
    then 
     printit "SERVER Check Has Passed - Running on SECONDARY HOST VM $THISSERVER" 
    else
     printit "WARNING: WRONG SERVER - Please Check Server and PARMS - ABORTING"
     exit 2
    fi
    fi

}

#Create sub-directories under the Basedir if they don't exist
function create_directories
{
mkdir -p $BUILDIR/messages
mkdir -p $BASEDIR/RUN_INDICATORS
mkdir -p $CONFIG_TEMPLATEDIR
mkdir -p $BACKUPDIR/full
mkdir -p $BACKUPDIR/logs
mkdir -p $BACKUPDIR/awsfiles
mkdir -p $BASEDIR/Day1binScripts  

if [ $SERVERTYPE = "PRIMARY" ]
then

#Move scripts from BASEDIR into appropriate directory - will be deployed to secondary from here
cp $BASEDIR/informix-restore.sh           $DAY1_deployDir 
cp $BASEDIR/Bring_Secondary_DB_Offline.sh $DAY1_deployDir
cp $BASEDIR/Create_secondary_cluster.sh   $DAY1_deployDir
cp $BASEDIR/download_lvl0_S3.sh           $DAY1_deployDir
cp $BASEDIR/diff_config.sh                $DAY1_deployDir
#cp $BASEDIR/check_config.sh               $DAY1_deployDir
cp $BASEDIR/Run_as_Root.sh                $DAY1_deployDir
cp $BASEDIR/Allocate_Storage_on_Secondary $DAY1_deployDir
cp $BASEDIR/change_mode_of_deployedscripts.sh  $DAY1_deployDir
else
cp $BASEDIR/informix-restore.sh           /home/informix 

fi
}

function check_cron_daemon
{
#Checks to make sure the crond deamon is not running -if it finds it running will prompt
CRONDCOUNT=`ps -eaf|grep -c crond` 
if [ $CRONDCOUNT -gt 1 ]
then
tput smso
echo "ERROR: CROND is still running"   | tee -a $LOG 
echo "Use the \"SYSTEMCTL stop crond.service\" command to stop the Cron Service" | tee -a $LOG
tput rmso
exit 2
fi

}

##Check to make sure onconfigs are up to date and consistent across the servers
function check_Onconfig_Files()
{

if [[ $BYPASS_CFG_CHECK -eq 1 ]]
then
echo "WARNING: BYPASSING CONFIG CHECK SET BY INDICATOR BYPASS-CFG-CHECK =1" | tee -a $LOG 
else
#Create the local servers cfg file from onstat command in advance of diff
#pull latest server parameters or (future version) use the ones resident on NJDEV
onstat -g cfg > $BASEDIR/onconfig.$THISSERVER
if [ $? -eq 0 ]
then
echo "ONCONFIG from LOCAL SERVER $THISSSERVER Created Successfully" | tee -a $LOG
else
tput smso
echo "ERROR: The Creation of the onconfig.$THISSERVER CFG FILE FAILED: onstat -g command Failed " | tee -a $LOG
echo "This is an important FILE used in the DIFF of the onconfig files"  | tee -a  $LOG
echo "NOTE: Please check to make sure the database is still online or create the file manually and bypass this check  " | tee -a $LOG
tput rmso
exit 2
fi
#We assume that we have 2 good CFG files at this point

if [ -r $BASEDIR/Goldconfig.cfg ] 
then
$DAY1_deployDir/diff_config.sh N
else
tput smso
echo "ERROR: Golden Source Configuration file Goldconfig.cfg is missing"  | tee -a $LOG
tput rmso
exit 2
fi
fi

}

##Fix for onconfig files that have differences
function fix_Onconfig_Files()
{
printit "Fixing Onconfig File Differences"



}

##Checks for sqlhosts, exclude files, alarmprogarm etc
function Check_otherConfig_Files ()
{

if [ ! -r $INFORMIXDIR/etc/alarmprogram.sh ]
then
tput smso
printit "ERROR: alarmprogram.sh  NOT FOUND"
printit "This is an important script and must be installed in the $INFORMXIDR/etc Directory. "
printit "NOTE:  The valid version of alarmprogram must be copied to the $INFORMIXDIR/etc/ Directory"
printit
printit "Continuing with vallidation checks and install -                                          "
tput rmso
sleep 10
else
grep ifx $INFORMIXDIR/etc/alarmprogram.sh >/dev/null
if [ $? -eq 1 ]
then
tput smso
echo "ERROR: in alarmprogram.sh  The BACKUP_CMD that executes \"ifx-backup log\" NOT FOUND"  | tee -a $LOG
echo "This is NOT A VALID version of the alarmprogram.sh. " | tee -a $LOG
echo "NOTE:  The valid version of alarmprogram must be copied to the $INFORMIXDIR/etc/ Directory" | tee -a $LOG
echo                                                                                              | tee -a $LOG  
echo "Continuing with vallidation checks and install -                                          " | tee -a $LOG
tput rmso
sleep 10
fi
fi

if [ ! -s $INFORMIXDIR/etc/dostats_exclude_openbet ]
then
tput smso
echo "ERROR: The \"dostats_exclude_openbet\" file is NOT FOUND or has zero size in $INFORMIXDIR/etc" | tee -a $LOG
echo "       THIS IS A VERY IMPORTANT FILE AND A VALID FILE MUST BE INSTALLED IN THE $INFORMIXDIR/etc DIRECTORY" | tee -a $LOG
echo                                                                                                             | tee -a $LOG  
echo "Continuing with vallidation checks                                          "                              | tee -a $LOG
tput rmso
else
echo 
printit "PLEASE VALIDATE CHECK THE CURRENT \"dostats_exclude_openbet\" file in $INFORMIXDIR/etc"
more $INFORMIXDIR/etc/dostats_exclude_openbet
sleep 20
fi

####Now Validate that the entries in the exclude file are valid - Compare against this Hardcode list
####################  EXCLUDE FILE EDIT LIST HERE ####################################################

queuetables=(
tbetfairjmsqueue
tofresqueue
tdwreporterqueue
toximsg
tliabengmsg
txsyssyncqueue
)

for table in "${queuetables[@]}"
do
grep $table $INFORMIXDIR/etc/dostats_exclude_openbet > /dev/null
if [ $? -eq 1 ]
then
tput smso
echo "*********** Designated Queue Table $table NOT FOUND ****************"
tput rmso

printit "WARNING: The $table  Queue Table was NOT FOUND in the dostats exclude file: dostats_exclude_openbet" 
printit "Please Investigate and Correct ! "
sleep 4
fi
done

###############################EXCLUDE FILE CHECKING  END#############################################
######################################################################################################
####Now continue checking for the sqlhosts file

if [ ! -s $INFORMIXDIR/etc/sqlhosts ]
then
tput smso
echo "ERROR: The \"sqlhosts\" file is NOT FOUND or has zero size in $INFORMIXDIR/etc" | tee -a $LOG
echo "       THIS IS A VERY IMPORTANT FILE AND A VALID FILE MUST BE INSTALLED IN THE $INFORMIXDIR/etc DIRECTORY" | tee -a $LOG
echo                                                                                                             | tee -a $LOG
echo "Continuing with Day 1 Build                                          "                                     | tee -a $LOG
tput rmso
sleep 10
else
printit
printit "The sqlhosts file has been found "
echo
sleep 10
fi


}


##Bring down Primary or Secondary Server of HDR cluster to offline mode
function Bring_cluster_Offline
{
printit "Bringing Server on Host: $THISSERVER to OFFLINE MODE" 

onmode -ky


printit "Server on Host: $THISSERVER has been brought down to OFFLINE MODE"


}


##Allocated Storage for the Database  MAIN DBSPACES   
function allocate_storage       
{
#run allocations

###NOTE: The Default Location for the DATADIR is /opt/informix/data
if [ ! -d $DATADIR ]
then
mkdir $DATADIR
fi

if [ ! -d $DATADIR/llogdbs ]
then
mkdir -p $DATADIR/llogdbs
fi

if [ ! -d $DATADIR/tempdbs01 ]
then
mkdir -p $DATADIR/tempdbs01
fi

if [ ! -d $DATADIR/tempdbs02 ]
then
mkdir -p $DATADIR/tempdbs02
fi

if [ ! -d $DATADIR/tempdbs03 ]
then
mkdir -p $DATADIR/tempdbs03
fi

if [ ! -d $DATADIR/datadbs ]
then
mkdir -p $DATADIR/datadbs
fi


cd $DATADIR
#SPECIAL CASE FOR ROOTDBS NOT EXISTING
if [ ! -r $DATADIR/rootdbs ]
then
fallocate -l 2G $DATADIR/rootdbs
chown informix:informix $DATADIR/rootdbs
chmod 660  $DATADIR/rootdbs
fi

rm -rf tempdbs04 tempdbs05 tempdbs06
fallocate -l 4G $DATADIR/llogdbs/llogdbs_chk001
fallocate -l 4G $DATADIR/llogdbs/llogdbs_chk002
fallocate -l 5G $DATADIR/physdbs
fallocate -l 4G $DATADIR/tempdbs01/tempdbs01_chk001
fallocate -l 4G $DATADIR/tempdbs02/tempdbs02_chk001
fallocate -l 4G $DATADIR/tempdbs03/tempdbs03_chk001
 

#####All chunks to be allocated to the database need to be owner and group informix and 660 permissions
chown informix:informix $DATADIR/llogdbs/llogdbs_chk001
chmod 660  $DATADIR/llogdbs/llogdbs_chk001
chown informix:informix $DATADIR/llogdbs/llogdbs_chk002
chmod 660  $DATADIR/llogdbs/llogdbs_chk002
chown informix:informix $DATADIR/physdbs  
chmod 660  $DATADIR/physdbs
chown informix:informix $DATADIR/tempdbs01/tempdbs01_chk001
chmod 660  $DATADIR/tempdbs01/tempdbs01_chk001
chown informix:informix $DATADIR/tempdbs02/tempdbs02_chk001
chmod 660  $DATADIR/tempdbs02/tempdbs02_chk001
chown informix:informix $DATADIR/tempdbs03/tempdbs03_chk001
chmod 660  $DATADIR/tempdbs03/tempdbs03_chk001



##Check allocation of storage


#Check ownership and mode


}

##Allocate Storage for the Datadbs Dbspace chunks
function allocate_datadbs_chunks       
{
printit "ALLOCATE DATABASE CHUNK FILES on  /opt/informix/data/datadbs"

for i in $(seq -f "%04g" 1 $MAXCHUNKS)
do 
  FILE=/opt/informix/data/datadbs/datadbs_chk${i}
  if [ ! -f ${FILE} ]
  then
    echo "fallocate -l 4G ${FILE}"   
    fallocate -l 4G ${FILE} 
    chmod 660 ${FILE}
    chown informix:informix ${FILE}
  fi
done

}

##Restore Level 0 ARchive on New Primary
function Restore_Level0 () 
{

if [ $download_level_0 = 0 ]
then
touch $INDIR/level_0_downloaded
printit "Indicator was set for bypassing download of Level 0 this run - setting indicator that it was previously downloaded"
fi

clear
printit "Checking to Make Sure the Level 0 backup has completed download from S3" 
#Kill some time while waiting for the download to complete
while [ ! -r $INDIR/level_0_downloaded ]
do 

printit "The Level 0 Backup has not Completed Downloading - please wait...."
sleep 60

done

printit "The Backup has Successfully download from S3"

GOODLEVEL0=`cat /opt/informix/backups/awsfiles/last_good_backup.txt`

if [ -r /opt/informix/backups/awsfiles/$GOODLEVEL0 ]
then
printit "RESTORING THE LEVEL 0 BACKUP ON PRIMARY: $GOODLEVEL0" 

nohup cat $awsdir/$GOODLEVEL0 | pigz -d | ontape -r -t STDIO

printit "LEVEL 0 BACKUP RESTORE COMPLETED"
###NOW BRING THE DATABASE INSTANCE TO ON-LINE MODE
onmode -m
sleep 10
onstat - > /dev/null 
   if [ $? -eq 5 ]
   then
   printit "THE DATABASE INSTANCE IS NOW ONLINE IN MULTI-USER MODE"
   sleep 5
   else
   printit "THE DATABASE INSTANCE HAS RETURNED AN UNKNOW RETURN CODE " 
   fi
else
printit "ERROR IN DOWNLOADING LEVEL 0 ARCHIVE FILE: $GOODLEVEL0 - FILE NOT FOUND - ABORTING RESTORE"
exit 2
fi

}

function export_OB_schema ()
{

printit "Exporting OB Database Schema"
dbschema -ss -d openbet > $BUILDIR/c_openbet_schema_prod$SCHEMADATE.sql

if [ $? = 0 ]
then
printit "OB DB SCHEMA SUCCESSFULLY CREATED"
else
printit "DBSCHEMA FOR OB DATABASE FAILED"
exit 2
fi

printit "SCHEMA Export Completed"
}

function create_sequences ()
{
printit "Creating Sequences"
#CREATE SEQUENCE SCHEMA
dbschema -d openbet -seq all > $BUILDIR/c_sequences.sql 
#Change sequences to start at 1
sed -i '/create sequence/d' sequences.sql
sed -i '/DBSCHEMA Schema Utility/d' sequences.sql
##delete the blank lines
sed -i '/^$/d' sequences.sql
#change restart sequence command to 1
sed -i 's/restart with .*/restart with 1;/g' sequences.sql
printit "Sequence Creation Completed"
}


function strip_triggers ()
{
cd $BUILDIR
printit "Saving off Triggers and Stripping them from Schema File"
#Strip the Triggers from the schema and create a separate file
echo "END-OF-FILE" > $BUILDIR/eof-delimitfile
cp $BUILDIR/c_openbet_schema_prod$SCHEMADATE.sql $BUILDIR/c_openbet_schema_prod$SCHEMADATE.sql-ORIG

###Insert an eof pattern into the end of the schema file
cat $BUILDIR/c_openbet_schema_prod$SCHEMADATE.sql $BUILDIR/eof-delimitfile >openbet_newschema_prod$SCHEMADATE.sql
##CREATE FILE WITH TRIGGERS
awk '/create trigger "openbet"/{flag=1} /END-OF-FILE/{flag=0} flag' $BUILDIR/openbet_newschema_prod$SCHEMADATE.sql > $BUILDIR/ob-triggers.sql

####Strip the DBSCHEMA heading line from the schema file
sed -i '/DBSCHEMA Schema Utility/d' $BUILDIR/openbet_newschema_prod$SCHEMADATE.sql

#STRIP THE TRIGGERS FROM THE SCHEMA FILE
sed -i '/create trigger "openbet"/,/END-OF-FILE/d' $BUILDIR/openbet_newschema_prod$SCHEMADATE.sql
##$BUILDIR/c_openbet_RECREATEschema_prod$SCHEMADATE.sql - This is the schema used to re-create the OB Database
printit "Trigger Save and Stripping process Completed"

}


##RUN the CUSTOMIZED UNLOAD SCRIPTS 
function Unload_OB_ENV ()
{
cd $BUILDIR
#Unload the Env Data 
#Make sure the dbaccess command line in the unload script is correct and fix if necessary
sed -i 's/- \/opt\/openbet\/release\/db\/connect.sql/openbet/g' $BUILDIR/unloadEnvData.sh

printit "UNLOADING OB Database ENV Data"
nohup $BUILDIR/unloadEnvData.sh 2>$BUILDIR/unloadEnvData.sh.out 2>1& 
printit "Unload of OB Database ENV Data COmpleted"

}


##Checks the unload return codes
##Only drop the OB DB is the return codes are good
function check_unload_integrity ()
{
printit "UNLOAD Integrity Checker"




}


function Unload_OB_DB ()

{
cd $BUILDIR
#Make sure the dbaccess command line in the unload script is correct and fix if necessary
sed -i 's/- \/opt\/openbet\/release\/db\/connect.sql/openbet/g' $BUILDIR/unloadData.sh
echo "Unload_OB_DB STARTING" > $INDIR/PROGRESS_DETAILED_checkpoint.txt 
#Unload the Openbet Database

echo  "The Unload of the OPENBET Database is Starting"    | tee -a $LOG

nohup $BUILDIR/unloadData.sh 2 > $BUILDIR/messages/unloadData.sh.out 2>&1

echo  "The Unload of the OPENBET Database has ENDED"    | tee -a $LOG
echo "Unload_OB_DB ENDED" > $INDIR/PROGRESS_DETAILED_checkpoint.txt 



}


##Drop the old OB legacy DB
function Drop_OB_DB ()
{
#Reasonability check to make sure that unload appears to have run correctly
#Else exit from the entire process to check what has happened - correct and rerun in restart mode
unlfilecount=`ls -l $BUILDIR/unload|wc -l`
if [ $unlfilecount -gt 149 ]
then
printit "Dropping the  openbet database "
sleep 2
echo "drop database if exists openbet;"|dbaccess sysmaster > $BUILDIR/messages/dropdb.out 2>&1
echo " Drop_OB_DB" > $INDIR/PROGRESS_DETAILED_checkpoint.txt 
else
printit "WARNING:  NOT DROPPING THE OPENBET DATABASE DUE TO FAILURE OF REASONABILITY CHECK OF UNLOAD FILES " 
printit "INvestigate issue and then restart the DAY 1 Process from the Database Refresh - using restart parm"
sleep 2
fi

}

###Re-Create the openbet database
function create_OB_DB ()
{
printit "Creating openbet database "
sleep 2
echo "create database openbet in datadbs01_8k;"|dbaccess sysmaster  > $BUILDIR/messages/createOBdb.out 2>&1

echo " create_OB_DB" > $INDIR/PROGRESS_DETAILED_checkpoint.txt 
}

#Create the OB Schema and re-create sequences reset to 1
function create_OB_SCHEMA 
{
cd $BUILDIR
#Create OB schema
printit "Creating OB Schema"
sleep 2
dbaccess openbet $BUILDIR/openbet_newschema_prod$SCHEMADATE.sql > $BUILDIR/messages/openbet_newschema_prod$SCHEMADATE.out  2>&1

printit "Running reset to 1 Sequence Alter sql"
#Run the  reset to 1 sequences sql on OB Schema
dbaccess openbet $BUILDIR/sequences.sql >  $BUILDIR/messages/openbet_sequences.out  2>&1

}

##Loads the Data to the newly re-created OB database
function load_OB_data ()
{
#Load the OB Database - NOTE:  This may take 3 -4 hours

printit "STARTING THE OB DATABASE LOAD"
tput smso
echo  "LOADING THE OPENBET DATABASE- This can take 3+ Hours" | tee -a $LOG
tput rmso

##########################################################################
### Check if this is a Restart and the Load is Already in Progress     ###
#########################################################################
if [ $special_load_restart = 1 ]
then
printit "Special Restart of the Load Process is Detected - Load Process Should already be in progress"
CHECKLOAD=`ps -eaf|grep -c  loadData.sql`
  if [ $CHECKLOAD = 2 ]
    then
      printit "OK- The LoadData.sql Process is STill Running "
      sleep 5
  else
     Printit "WARNING: The Data Load Process is no longer running - it may have completed or there may be further progress in the Stream - Check logs"
  fi
else 
###### Not a restart where the Load was already running   #####
###### We can submit the Job from the beginning        #####
####NOTE: THE LOAD RUNS AS A BACKGROUND JOB

nohup dbaccess openbet  $BUILDIR/loadData.sql > $BUILDIR/messages/loadData.out 2>&1 &
sleep 2
echo "OB DB LOAD STARTING" > $INDIR/PROGRESS_DETAILED_checkpoint.txt
fi

LOADPROCESS=`ps -eaf|grep -c  loadData.sql`
clear

while [ $LOADPROCESS = 2 ]
do
##LOADPROCESS=`ps -eaf|grep -c  dbaccess`
LOADPROCESS=`ps -eaf|grep -c  loadData.sql`
tput cup 15 45
echo "The OPENBET Database Load is still in Progress...... "
sleep 60
done
########Repeat the Waiter Process to Make sure that the process has really ended and not just a glitch ##############
sleep 2
LOADPROCESS=`ps -eaf|grep -c  dbaccess`

while [ $LOADPROCESS = 2 ]
do
LOADPROCESS=`ps -eaf|grep -c  dbaccess`
tput cup 15 45
echo "The OPENBET Database Load is still in Progress...... "
sleep 60
done

clear 
printit "THE OB DATABASE LOAD is no longer Running" 
tput smso
echo  "The OPENBET Database Load has ENDED" | tee -a $LOG
tput rmso
sleep 10

echo "OB_DB LOAD_COMPLETED" > $INDIR/PROGRESS_DETAILED_checkpoint.txt


}


function load_OB_Env_data ()
{

dbaccess openbet $BUILDIR/loadEnvData.sql > $BUILDIR/messages/load-ENVData.out 2>&1
printit "The Load Env for the OB Database has ENDED" 
sleep 2

echo "OB_DB_ENV_Load COMPLETED" > $INDIR/PROGRESS_DETAILED_checkpoint.txt

}

function recreate_triggers ()
{
printit "Re-Creating Triggers on the OB Database"
dbaccess openbet $BUILDIR/ob-triggers.sql > $BUILDIR/messages/ob_triggers.out 2>&1
printit "Re-Creating Triggers on the OB Database has ENDED"
echo "recreate_triggers COMPLETED" > $INDIR/PROGRESS_DETAILED_checkpoint.txt

}


function change_config_todevnull
{
sed -i 's/TAPEDEV \/opt\/informix\/backups\/full/TAPEDEV \/dev\/null/g' $INFORMIXDIR/etc/onconfig

}

function change_config_back
{

sed -i 's/TAPEDEV \/dev\/null/TAPEDEV \/opt\/informix\/backups\/full/g' $INFORMIXDIR/etc/onconfig

}


function set_OB_DB_Buff_Logging ()
{

#SET OB DATABASE TO BUFFERED LOGGING
printit "Setting OB Database to BUFFERED LOGGING"
sleep 2
###BRING DB Briefly to Single User to Flush out any potential locks 

onmode -jy
sleep 1
#Now Bring back to multi user mode
onmode -m
printit "CHECKING THE INSTANCE HEALTH - MUST BE ON-LINE MODE "
sleep 5

onstat - > /dev/null
UPSTAT=`echo $?`

if [ $UPSTAT = 5 -o $UPSTAT = 0 ]
then
printit "THE Database Instance is Healthy and On-Line"
else
printit "WARNING: THE Database Instance is NOT ON-LINE "
printit "THE INIT DAY1 Process must abort - Investigate and then Restart"
echo "     "
tput smso
echo "WARNING: ABORTING RUN DUE TO DATABASE INSTAANCE BEING OFFLINE"
tput rmso
exit 2
fi

change_config_todevnull
###Sleep 90 seconds to give time to server for finishing up starting internal processes
sleep 90
ontape -s -L 0 -B openbet > $BUILDIR/messages/changeDBLOGGING.out 2>&1
if [ $? -eq 0 ]
then
RETCODE=0
printit "SUCCESSFULLY Changed OB DB to BUFFERED LOGGING"
else
RETCODE=1
printit "WARNING: The Change of the OB DB to BUFFERED LOGGING FAILED "
fi

change_config_back
##########################################################################
######Test for the Successful Change of Logging to Buffered Logging  #####
####### IF IT IS NOT SUCCESSFUL WE MUST ABORT THE RUN               ######
####### In this case investigate the reason - correct it and restart######
######## The script will now re-try the change automatically        ######
######### but if it fails a second time then it will abort          ######
##########################################################################

grep Error $BUILDIR/messages/changeDBLOGGING.out > /dev/null
if [ $? = 0 ]
then 
RETCODE2=1
else
RETCODE2=0
fi

if [ $RETCODE = 1 -o $RETCODE2 = 1 ]
then
printit "ERROR IN CHANGING LOGGING MODE TO BUFFERED LOGGING - Going to Re-Try Operation"
######## Re-try the operation - if it fails again then abort run ##########

change_config_todevnull
ontape -s -L 0 -B openbet > $BUILDIR/messages/changeDBLOGGING.out 2>&1

if [ $? -eq 0 ]
then
RETCODE=0
printit "SUCCESSFULLY Changed OB DB to BUFFERED LOGGING"
else
RETCODE=1
printit "WARNING: The Change of the OB DB to BUFFERED LOGGING FAILED TWICE - SCRIPT MUS ABORT - INVESTIGATE"
change_config_back
exit 2
fi
else
printit "Successful Change of the OPENBET Database to BUFFERED LOGGING"
fi

change_config_back

echo "set_OB_DB_Buff_Logging COMPLETED" > $INDIR/PROGRESS_DETAILED_checkpoint.txt

}

function Update_utilsdb_cluster_nodes ()
{

printit "Updating UTILSDB Cluster Nodes"
sleep 2
dbaccess utilsdb << !  > $BUILDIR/messages/clusternode.out 2>&1

update tclusternode
set cluster_node_alias_lc = "$SERVERNAMEnode1"
where cluster_node_id=1;

update tclusternode
set cluster_node_alias_lc = "$SERVERNAMEnode2"
where cluster_node_id=2;

!



}

#Purge utilsdb:tadminjobruns of stale entries 

function purge_tadminjobruns ()
{
printit "PURGING UTILSDB: tadminjobruns of stale entries"
sleep 2
##(removes stale entries in table copied over from the archive)

echo "truncate table tadminjobruns" | dbaccess utilsdb > $BUILDIR/messages/tadminjobrun.out 2>&1


}

function grant_resource_tosensu
{

printit "Granting RESOURCE Permissions to SENSU on UTILSDB"
sleep 2

echo "grant resource to sensu" | dbaccess utilsdb  > $BUILDIR/messages/grantsensu 2>&1 

}

function seed_golden_distributions
{

printit "Seeding Golden Distributions for Statistical Update"
sleep 2

$INFORMIXHOME/dist/load.sh >> $LOG 2>&1 

}

function update_low_storage_monitor
{

printit "Updating the Low Storage Monitor on Storage Pool to 1 minute Frequency"
sleep 2
echo "update ph_task set tk_frequency = '0 00:01:00' where tk_name = 'mon_low_storage'" | dbaccess sysadmin >> $LOG 2>&1

}

function create_dostats_exclude_file ()
{
#Checks for dostats.exclude file with updated number of exntries - if doesnt't exist then copies it from $BUILDIR/$INIT-DAY1-SOURCELIB
printit "Checking dostats_exclude_file for the correct number of entries"
printit "Coming Soon in Version 2"
sleep 2


}

function check_kernel_parmeters ()
{
printit "Checking Kernel Parmeters defined in UTILSDB  align with VM Kernel Parameters"
sleep 2

sh /opt/informix/scripts/sensu/check_kernel_parameters.sh  

if [ $? -eq o ]
then
printit "PASSED KERNEL PARAMETERS CHECK"
else
printit "WARNING :  The Server Did NOT Pass the Kernel Parameters Check" 
echo
fi

}

#CHECK FOR TRUST BETWEEN THE PRIMARY AND SECONDARY HOSTS
function check_ssh_keys
{

if [ $SERVERTYPE = "PRIMARY" ]
then
if [ -r $INFORMIXHOME/.ssh/id_rsa.pub ]
then
tput smso
echo "SSH KEYS APPEAR TO BE SET UP -TRUST IS ESTABLISHED BETWEEN PRIMARY AND SECONDARY: Continuing with process" | tee -a $LOG
tput rmso
else
tput smso
echo "ERROR SSH KEYS NOT FOUND: process will wait for TRUST to be established" | tee -a $LOG
tput rmso
echo
fi
fi

if [ $SERVERTYPE = "SECONDARY" ]
then
if [ -r $INFORMIXHOME/.ssh/authorized_keys ]
then
tput smso
echo "SSH KEYS APPEAR TO BE SET UP -TRUST IS ESTABLISHED BETWEEN PRIMARY AND SECONDARY: Continuing with process" | tee -a $LOG
tput rmso
else
tput smso
echo "ERROR SSH KEYS NOT FOUND: process will wait for TRUST to be established" | tee -a $LOG
tput rmso
echo
fi
fi



#PROMPT TO CONTINUE OR WAIT UNTIL THE SSH KEYS ARE SET UP

}

function restore_backup_to_secondary
{
printit "INITIATING CREATION OF THE CLUSTER"
tput smso  
echo "THE RESTORE OF THE LEVEL 0 BACKUP to the SECONDARY IS STARTING" | tee -a $LOG
tput rmso
echo
########################################################################################################
#########Check to make sure this isn't a special case where we must use the IP address
######### for SSH instead of the hostname due to AWS DNS issues 
######### if parm #6 and parm #7 are set then we use those for ssh communications between 
######### the primary and secondary servers such as is the case when we are restoring the
########## database to the secondary over the network via ssh
########################################################################################################

if [ ! -z $NODE1_IP ]
then 
   if [ ! -z $NODE2_IP ]
then
    printit " IP Addresses are set in Parms #6 and #7 - Using Those for SSH Between Primary and Secondary Nodes"
    printit " Using  IP ADDRESS:  $NODE2_IP for SECONDARY NODE"
sleep 5
##  The IP Nodes are set.....try to connect to nodes using the IP's instead of the hostname
SERVERNAMEnode2=$NODE2_IP
 else
   printit "WARNING: Something Went Wrong:  IP address parm #6 for primary node is set and parm #7 is not Set" 
  fi
else
   printit "RESTORING THE SECONDARY SERVER USING HOSTNAME for SSH"
   sleep 5
fi


echo "restore_backup_to_secondary STARTING" > $INDIR/PROGRESS_DETAILED_checkpoint.txt
nohup ontape -s -L 0 -t STDIO -F | ssh $SERVERNAMEnode2 /home/informix/informix-restore.sh 

echo "restore_backup_to_secondary COMPLETED" > $INDIR/PROGRESS_DETAILED_checkpoint.txt
printit "THE RESTORE OF THE LEVEL 0 BACKUP to the SECONDARY HAS ENDED"

}

function deploy_package_to_secondary
{


printit "DEPLOYING package: informix-restore.sh to Secondary "

if [ $RUN_ONLY_ON_PRIMARY = 1 ]
then
##DEPLOY informix-restore.sh to the secondary informix home directory .  This script will execute the physical database restore on node 2
scp $DAY1_deployDir/informix-restore.sh informix@$SERVERNAMEnode2:/home/informix

printit "DEPLOYING package: Create_Secondary_cluster.sh script to Secondary "
## Deploy the  Create_Secondary_cluster.sh script to the informix home directory.
scp $DAY1_deployDir/Create_secondary_cluster.sh informix@$SERVERNAMEnode2:/home/informix

printit "DEPLOYING package: BringDB_offline.sh script to Secondary "
## Deploy the Bring_Secondary_DB_Offline.sh script to the informix home directory.
scp $DAY1_deployDir/Bring_Secondary_DB_Offline.sh informix@$SERVERNAMEnode2:/home/informix

printit "DEPLOYING package: diff_config.sh script to Secondary "
## Deploy the diff_config.sh script to the informix home directory.
scp $DAY1_deployDir/diff_config.sh informix@$SERVERNAMEnode2:/home/informix

printit "DEPLOYING package: Change_mode_of_deployedscripts.sh script to Secondary "
## Deploy the Bring_Secondary_DB_Offline.sh script to the informix home directory.
scp $DAY1_deployDir/change_mode_of_deployedscripts.sh informix@$SERVERNAMEnode2:/home/informix
else
##DEPLOY informix-restore.sh to the secondary informix home directory .  This script will execute the physical database restore on node 2
scp $DAY1_deployDir/informix-restore.sh informix@$SERVERNAMEnode2:/home/informix

printit "DEPLOYING package: diff_config.sh script to Secondary "
## Deploy the diff_config.sh script to the informix home directory.
scp $DAY1_deployDir/diff_config.sh informix@$SERVERNAMEnode2:/home/informix

printit "DEPLOYING package: Change_mode_of_deployedscripts.sh script to Secondary "
## Deploy the Bring_Secondary_DB_Offline.sh script to the informix home directory.
scp $DAY1_deployDir/change_mode_of_deployedscripts.sh informix@$SERVERNAMEnode2:/home/informix
fi

}


Create_HDR_Cluster ()

{
check_ssh_keys

###GRAB the Primary and Secondary Servername from sqlhosts file

restore_backup_to_secondary

###Join_HDR_Cluster_as_Primary
printit "Joining the PRIMARY Server to the Cluster"

onmode -d primary $SECONDARY_SERVERNAME

#CHECK TO MAKE SURE THIS HOST HAS NOW BECOME A PRIMARY SERVER

#######################################################
############### RUN THE CLUSTER JOIN REMOTELY 
############### If we have the following switch set
#######################################################
if  [ $RUN_ONLY_ON_PRIMARY = 1 ]
then
###Join_HDR_Secondary 

## Remote Script Runs this on the Secondary
###########################################
### onmode -d secondary $PRIMARY_SERVERNAME
##########################################
##Run the CLUSTER JOIN on Secondary
printit "Joining the Secondary Server to the Cluster - running remotely"
ssh informix@$SERVERNAMEnode2 /home/informix/Create_secondary_cluster.sh
else
printit "Important NOTE: THE CLUSTER JOIN OF THE SECONDARY MUST BE RUN MANUALLY on the SECONDARY"
sleep 5
fi

}

function download_backup_from_S3
{
printit "DOWNLOADING the LAST GOOD BACKUP from S3"
sleep 5
### Check that there is a valid State Parm $1 that is passed to the sub-program

if [ -r $INDIR/state_parm ]
then
echo "A Template State Parameter for the level 0 Download is Valid " | tee -a $LOG
ST=`cat $INDIR/state_parm`
echo "The Template State is: $ST" | tee -a $LOG
else
echo "A Template State Parameter for the level 0 Download is MISSING:  $INDIR/state_parm" | tee -a $LOG
echo "Specify a Valid State to Download- use menu- and then Re-run - program must abort" | tee -a $LOG
exit 100
fi

echo "download_backup_from_S3 STARTED" > $INDIR/PROGRESS_DETAILED_checkpoint.txt
nohup $DAY1_deployDir/download_lvl0_S3.sh $ST  >> $BASEDIR/awsLOG 2>&1 & 

##echo "download_backup_from_S3 ENDED" > $INDIR/PROGRESS_DETAILED_checkpoint.txt
}


function setup_tvocprice_purge 
{

echo "SETTING UP TEVOCPRICE PURGE STRUCTURE"



}


#########################################
########## Run_Phase_I ################## 
#########################################

function Create_Server_running_on_both {

###CREATE ALL NECESSARY DIRECTORIES FOR RUN

create_directories

if [ $SERVERTYPE = "PRIMARY" ]
then
CheckServers
sleep 5
check_cron_daemon
sleep 5
##We assume this is a new run -Remove potential stale indicators
rm -f $INDIR/level_0_downloaded >/dev/null
rm -f $BASEDIR/level_0_downloaded >/dev/null

##DOWNLOAD the LAST GOOD FUll BAckup from Colorado or cancidate state

if [ $download_level_0 = 1 ]
then
download_backup_from_S3
fi

check_ssh_keys
##########################################################################################################
#SPECIAL CASE Where We have to use the IP address of the VM instead of the hostname due to DNS differences
#Check if parameter #7 is set with a valid IP address of the secondary
##########################################################################################################

if [ ! -z $NODE2_IP ]
then
SERVERNAMEnode2=$NODE2_IP
printit "NOTE: The  SERVERNAME for node 2 secondary has been set to the IP Address: $NODE2_IP due to Parm Setting"
fi

deploy_package_to_secondary

##Check Onconfig Files on Primary
check_Onconfig_Files
sleep 5

##fix_Onconfig_Files ---ver 2.0

##Bring Cluster offline on Primary
Bring_cluster_Offline
sleep 5

###Allocate Storage on Primary
allocate_storage
sleep 5
allocate_datadbs_chunks
sleep 5

Check_otherConfig_Files
sleep 5

Restore_Level0
sleep 5
echo "Phase I COMPLETED"
sleep 5
elif [ $SERVERTYPE = "SECONDARY" ]
then
#On Secondary when run directly on the box everything runs from EXPORTS
DAY1_deployDir=/opt/informix/backups/EXPORTS

CheckServers
sleep 5
check_ssh_keys
sleep 5

##deploy_package_to_secondary
check_Onconfig_Files
sleep 5
##fix_Onconfig_Files

Bring_cluster_Offline
sleep 5
allocate_storage
sleep 5
allocate_datadbs_chunks
sleep 5
Check_otherConfig_Files
sleep 5
else
echo "ERROR : Invalide Server Type"
sleep 5
fi

echo "Create_Server_Running_Both" > $INDIR/PROGRESS_checkpoint.txt
}

#################################################################################
#####THIS FUNCTION APPLIES ONLY TO RUNNING EVERTYTHING FROM THE PRIMARY HOST##### 
#################################################################################

function Create_Server_only_from_primary {

##DOWNLOAD the LAST GOOD FUll BAckup from Colorado or cancidate state
#If [ ! -r $INDIR/level_0_downloaded ]

if [ $download_level_0 = 1 ]
then
download_backup_fromS3
fi

###CREATE ALL NECESSARY DIRECTORIES FOR RUN

create_directories

if [ $SERVERTYPE = "PRIMARY" ]
then
CheckServers
check_cron_daemon
##We assume this is a new run -Remove potential stale indicators
rm -f $INDIR/level_0_downloaded >/dev/null
rm -f $BASEDIR/level_0_downloaded >/dev/null
check_ssh_keys
##########################################################################################################
#SPECIAL CASE Where We have to use the IP address of the VM instead of the hostname due to DNS differences
#Check if parameter #7 is set with a valid IP address of the secondary
##########################################################################################################

if [ ! -z $NODE2_IP ]
then
SERVERNAMEnode2=$NODE2_IP
printit "NOTE: The  SERVERNAME for node 2 secondary has been set to the IP Address: $NODE2_IP due to Parm Setting"
sleep 5
fi
deploy_package_to_secondary
check_Onconfig_Files

#CHECK Onconfig files on Secondary
ssh informix@$SERVERNAMEnode2 /home/informix/diff_config.sh G

####fix_Onconfig_Files ---Ver 2.0

##Bring Cluster Offline on Secondary
ssh informix@$SERVERNAMEnode2 /home/informix/Bring_Secondary_DB_Offline.sh

###Bring Cluster Offline on Primary
Bring_cluster_Offline
sleep 5

##Allocate Storage on Secondary
ssh informix@$SERVERNAMEnode2 /home/informix/Allocate_Storage_on_Secondary

##Allocate Storage on Primary
allocate_storage
sleep 5
allocate_datadbs_chunks
sleep 5

Check_otherConfig_Files
sleep 5

Restore_Level0
printit  "Phase I COMPLETED"
sleep 5
else
printit "ERROR: Wrong Setting on RUN_ONLY_ON_PRIMARY Variable found : Invalid Server type for this run"
sleep 5
exit 2
fi
}

#########################################
##                                     ## 
##  DATA LOAD FUNCTIONS                ## 
##                                     ## 
#########################################

function Do_Data_Load {

load_OB_data
echo "load_OB_data" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
load_OB_Env_data
echo "load_OB_Env_data" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
recreate_triggers
echo "recreate_triggers" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
set_OB_DB_Buff_Logging
echo "set_OB_DB_Buff_Logging" > $INDIR/PROGRESS_checkpoint.txt
sleep 5

####No Need Yet for a Grant Permissions sub-routine
###grant_permissions
###echo "grant_permissions" > $INDIR/PROGRESS_checkpoint.txt

}

function Data_Refresh_Prep {

export_OB_schema
echo "export_OB_schema" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
strip_triggers 
echo "strip_triggers" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
create_sequences 
echo "create_sequences" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
Unload_OB_DB
echo "Unload_OB_DB" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
Unload_OB_ENV
echo "Unload_OB_ENV" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
check_unload_integrity 
echo "check_unload_integrity" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
Drop_OB_DB
echo "Drop_OB_DB" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
create_OB_DB 
echo "create_OB_DB" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
create_OB_SCHEMA
echo "create_OB_SCHEMA" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
create_sequences
echo "create_sequences" > $INDIR/PROGRESS_checkpoint.txt


}


#########################################
#      OPENBET DATABASE REFRESH         #
#         Run Phase II                  #
#########################################

function Refresh_Database {

Last_Routine_Executed=`cat $INDIR/PROGRESS_DETAILED_checkpoint.txt`

if [ ! -z $THIS_IS_RESTART ]
then
### A Restart and Special Case where we want to restart specifically loading the data
  if [[ $Last_Routine_Executed = "OB DB LOAD STARTING" ]]
    then
       printit "RESTARTING WITH LOAD OB DATA PROCESS - Skipping Unloads and Prep"
       sleep 5
       special_load_restart=1    
       Do_Data_Load
  else
####A restart and we want to start from the top of the process
printit " Restart Mode Detected - restarting from the top of the process - unload and load"
sleep 5
Data_Refresh_Prep
Do_Data_Load
fi
else 
printit "Normal Mode:  No Restart Detected"
###Not A Restart Normal Mode
Data_Refresh_Prep
Do_Data_Load
fi

###############
### Following Routines we always do - restartable
###############

Update_utilsdb_cluster_nodes 
echo "Update_utilsdb_cluster_nodes" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
purge_tadminjobruns 
echo "purge_tadminjobruns" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
create_dostats_exclude_file 
echo "create_dostats_exclude_file" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
setup_tvocprice_purge
echo "setup_tvocprice_purge" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
check_kernel_parmeters
echo "check_kernel_parmeters" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
grant_resource_tosensu
echo "grant_resource_tosensu" > $INDIR/PROGRESS_checkpoint.txt
sleep 5
#####Seed the Golden Distributions into the sysdistrib Table
seed_golden_distributions
echo "Seed Golden Dist" > $INDIR/PROGRESS_checkpoint.txt
#####Update the Storage Pool low storage monitor on the sysadmin db
sleep 5
update_low_storage_monitor
echo "update_low_storage_mon" > $INDIR/PROGRESS_checkpoint.txt

}

#########################################
#        Run_Phase_III                  #
#########################################

function Create_Cluster {
echo "Create_Cluster START" > $INDIR/PROGRESS_checkpoint.txt

Create_HDR_Cluster

printit "CREATING the MACH 11 CLUSTER - Running Function Create_HDR_Cluster" 
####$DAY1_deployDir/create_MACH11_cluster.sh


echo "Create_Cluster" > $INDIR/PROGRESS_checkpoint.txt

}

##Update statistics on the Newly created database
###Update Statistics Can Only Be Run Once the CLuster has been successfully created

function Update_Statistics {

/opt/informix/scripts/bin/dostats -t 4 -r 0 >> /var/log/informix/dostats/dostats.log 2>&1


echo "Update_Statistics" > $INDIR/PROGRESS_checkpoint.txt
}

function Set_Bypass_Switch {
##bypass_refresh = "NO" is the default ####
sleep 3
clear
tput smso
echo "NOTE: ANSWER NO (\"n\") to the following prompt if you want to run the Full end to end Database Build and REFRESH"
echo "      ANSWER YES (\"y\") to the following prompt if you already have the level 0 and only want to do the build and restore"
tput rmso
echo "   "
##PROMPT USER FOR BYPASS QUESTION
while [ 1 = 1 ]
do
echo "DO YOU WANT TO SKIP RUNNING THE OB REFRESH SCRIPTS- and ONLY restore the latest Full Backup  ?"
read -p "(enter lowercase \" y\" or \"n\" ) ===>" answer
if [ $answer = "y" ]
then
echo "   "
echo -e "${BLUE}You Entered \"y\" for YES - skip the OB REFRESH of the database${STD}"
bypass_refresh="yes"
sleep 2
break
elif [ $answer = "n" ]
then
echo "   "
echo -e "${BLUE}You Entered \"n\" for NO - DO NOT skip the OB REFRESH of the database${STD}"
bypass_refresh="NO"
sleep 2
break
else
echo -e "${RED}Error..INVALID VALUE ENTERED - ENTER CORRECT VALUE${STD}"
sleep 3
fi
done

}



###############...PROGRAM MAINLINE STARTS HERE ########################

#
#...user Validation
clear
checkuser
sleep 3
#ARE WE RUNNING ON THE PRIMARY OR SECONDARY?
if [ $SERVERNAMEnode1 = $THISSERVER ]
then
clear
echo "################################" >> $LOG
date >> $LOG
echo "RUNNING ON PRIMARY" | tee -a $LOG
SERVERTYPE="PRIMARY"
#######SET THE BYPASS REFRESH SWITCH - Do we want to bypass the OB script process ? #########
Set_Bypass_Switch
elif  [ $SERVERNAMEnode2 = $THISSERVER ]
then
echo "RUNNING ON SECONDARY" | tee -a $LOG
SERVERTYPE="SECONDARY"
else
echo "ERROR - INVALID SERVER - CHECK PARMS - ABORTING" | tee -a $LOG
exit 2
fi

sleep 7
###Is the RUN_ONLY_ON_PRIMARY Switch set turned on (set to 1) then run everything from Primary
if  [ $RUN_ONLY_ON_PRIMARY = 1 ]
then
printit " RUNNING THE BUILD ONLY FROM THE PRIMARY HOST "
sleep 7
Create_Server_only_from_primary

###Steps Performed:
##Create_Server - Runs scripts for secondary build via ssh
sleep 7
Refresh_Database
sleep 7
Create_Cluster
sleep 7
Update_Statistics
sleep 7

printit "THE AUTOMATIC DAY 1 Build/Refresh Program has Ended"

else
###Running the Build on both the Primary and Secondary Separately 
printit " RUNNING THE BUILD FROM BOTH THE PRIMARY and SECONDARY HOSTS"
sleep 7
###CHECK FOR RESTART MODE 

if [ -z $THIS_IS_RESTART ]
then
###NOT A RESTART -  parm is empty - go ahead and create the server

Create_Server_running_on_both
echo "Restore_Level0" > $INDIR/PROGRESS_checkpoint.txt
else
printit "RESTART MODE DETECTED - WILL PROCEED WITH REFRESHING DATABASE- WITHOUT BUILDING SERVER"
fi

#### We do not want these routines running on the Secondary Server
if [ $SERVERTYPE = "PRIMARY" ]
then
###################################################################################
#######CHECK TO SEE IF THE BYPASS OF THE DB REFRESH SWITCH HAS BEEN SET  ##########
#######If it has been set then we do NOT WANT TO REFRESH THE DATABASE    ##########
#######We only want to BUILD AND RESTORE THE LAST ARCHIVE                ##########
####### The bypass_refresh indicator is set by prompt early in the script##########
###################################################################################
if [ $bypass_refresh = "NO" ]
  then
   Refresh_Database 
 else
  printit "WARNING: Bypassing the normal OB Refresh of the Database due to Indicator set by Prompt"
fi

Create_Cluster 
Update_Statistics 
printit "THE AUTOMATIC DAY 1 Build/Refresh Program has Ended"
else
printit "THE Automatic Day 1 Build/Refresh Program Completed - Now Run InitDay1.sh  on PRIMARY"
fi
fi
#Print the results_report
###Print_report

