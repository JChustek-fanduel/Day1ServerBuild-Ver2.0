#!/bin/sh
#######################################################################################################################################################################
#########
#######################################################################################################################################################################
######### Run_Serverbuild.sh 
#
#       This Script functions as the Front End to the  InitDay1.sh Server build script process - Linux version
#
#       Script facilitates the automation of the building of a new Informix Server Database Instance
#       Utilizes a yaml config file: BuildConfig.yaml
#       NOTE: When the  BuildConfig.yaml file is placed in /home/informix - it will be used and override the previous build config file
#
#
#######################################################################################################################################################################

SERVERNAMEnode1=$1
SERVERNAMEnode2=$2
MAXCHUNKS=$3
PRIMARY_SERVERNAME=$4
SECONDARY_SERVERNAME=$5
###restartmode=$6
NODE1_IP=$7
NODE2_IP=$8
BASEDIR=/opt/informix/scripts/Day1ServerBuild
HOME=/home/informix
####YAML CONFIG FILE
CONFIG=$BASEDIR/BuildConfig.yml
CONFIGNAME=BuildConfig.yml
CONFIGWRK=$BASEDIR/buildconfig-workfile
LOG=$BASEDIR/LOGS/DAY1Init.LOG
BACKUPS=/opt/informix/backups
OBBUILDIR=$BACKUPS/OBscripts
INDIR=$BASEDIR/RUN_INDICATORS

##donotPrint=1
donotPrint=0



function echo_it ()
{

if [ $donotPrint -eq 1 ]
  then
  echo -n "`date` : " >>  $LOG
  echo $1 >> $LOG
else
  echo -n "`date` : " | tee -a  $LOG
  echo $1 | tee -a $LOG
fi

}

#######Check That User is INFORMIX
#####
function checkuser
{
export _username=`echo $USER`
if [ $_username != "informix" ]
then
  if [ $donotPrint -eq 1 ]
then
echo "  E R R O R : SCRIPT ${_scriptName} MUST BE RUN AS USER INFORMIX" >> $LOG
echo "  YOUR ARE CURRENTLY: $_username " >> $LOG
echo  >> $LOG
echo "  ====== ABORTING RUN ======" >> $LOG
 else
echo-it
echo-it "  E R R O R : SCRIPT ${_scriptName} MUST BE RUN AS USER INFORMIX"
echo-it "  YOUR ARE CURRENTLY: $_username "
echo-it
echo-it "  ====== ABORTING RUN ======"
  fi
exit 100
fi

}

####Check for existence of the YAML CONFIG file *****

function parse_config {

if [ -r /home/informix/$CONFIGNAME ]
then
echo_it "Found the Config File Override in $HOME - Program will use this yml Config file: $CONFIGNAME"
sleep 2
cp /home/informix/$CONFIGNAME $CONFIG
fi

#Now parse fields and set the parameters
#Convert file   
#The following code will be replaced by the YQ command processor once available on the system
sed -e 's/:[^:\/\/]/="/g;s/$/"/g;s/ *=/=/g' $CONFIG > $CONFIGWRK
####$BASEDIR/buildconfig-workfile is the configuration work file which contains the massaged fields to be inserted into variables
###########################
#Process mode Section
###########################

##continuous 
mode_continuous=`grep "_continuous" $CONFIGWRK`
CONTINUOUS=`echo "$mode_continuous" | awk -F'"' '{print $2}'`
if [ "$CONTINUOUS" = "yes" ]
then
echo_it "continuous is set to yes - running in continuous mode"  
elif [ "$CONTINUOUS" = "no" ]
then
echo_it "continuous is set to no - running one time"  
else
echo_it "Invalid value set for continueous mode in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#interactive
mode_interactive=`grep "_interactive" $CONFIGWRK`
INTERACTIVE=`echo "$mode_interactive" | awk -F'"' '{print $2}'`
if [ "$INTERACTIVE" = "yes" ]
then
echo_it "interactive is set to yes - running in interactive mode"  
elif [ "$INTERACTIVE" = "no" ]
then
echo_it "interactive is set to no - running autonomously"  
else
echo_it "Invalid value set for interactive mode in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#frequency
mode_frequency=`grep "_frequency" $CONFIGWRK`
FREQUENCY=`echo "$mode_frequency" | awk -F'"' '{print $2}'`
if [ "$FREQUENCY" = "daily" ]
then
echo_it "frequency is set to run daily - running in daily run mode"  
elif [ "$FREQUENCY" = "weekly" ]
then
echo_it "frequency is set to run weekly - running in weekly run mode"  
elif [ "$FREQUENCY" = "adhoc" ]
then
echo_it "frequency is set to run adhoc - running in on demand run mode"  
else
echo_it "Invalid value set for frequency mode in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#displaymessages
mode_displaymessages=`grep "_displaymessages" $CONFIGWRK`
DISPLAYMESSAGES=`echo "$mode_displaymessages" | awk -F'"' '{print $2}'`
if [ "$DISPLAYMESSAGES" = "yes" ]
then
echo_it "displaymessages is set to yes - running in displaymessages mode"  
elif [ "$DISPLAYMESSAGES" = "no" ]
then
echo_it "displaymessages is set to no - Messages will be silenced "  
else
echo_it "Invalid value set for displaymessages mode in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#run_onlyonprimary
mode_run_onlyonprimary=`grep "_run_onlyonprimary" $CONFIGWRK`
RUN_ONLY_ON_PRIMARY=`echo "$mode_run_onlyonprimary" | awk -F'"' '{print $2}'`
if [ "$RUN_ONLY_ON_PRIMARY" = "yes" ]
then
echo_it "run_onlyonprimary is set to yes - Running the build  from the only the Primary Server"  
elif [ "$RUN_ONLY_ON_PRIMARY" = "no" ]
then
echo_it "run_onlyonprimary is set to no - Running the build manually from both the Primary and Secondary servers"  
else
echo_it "Invalid value set for displaymessages mode in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#########################
#Process Server Section
#########################

#servernamenode1
SERVERS_servernamenode1=`grep "_servernamenode1" $CONFIGWRK`
servernamenode1=`echo "$SERVERS_servernamenode1" | awk -F'"' '{print $2}'`
echo_it "servernamenode1 is set to $servernamenode1"  

#servernamenode2
SERVERS_servernamenode2=`grep "_servernamenode2" $CONFIGWRK`
servernamenode2=`echo "$SERVERS_servernamenode2" | awk -F'"' '{print $2}'`
echo_it "servernamenode2 is set to $servernamenode2"  

#primary_servername
SERVERS_primary_servername=`grep "_primary_servername" $CONFIGWRK`
primary_servername=`echo "$SERVERS_primary_servername" | awk -F'"' '{print $2}'`
echo_it "primary servername is set to $primary_servername"  

#secondary_servername
SERVERS_secondary_servername=`grep "_secondary_servername" $CONFIGWRK`
secondary_servername=`echo "$SERVERS_secondary_servername" | awk -F'"' '{print $2}'`
echo_it "secondary servername is set to $secondary_servername"  

#management_servername
SERVERS_management_servername=`grep "_management_servername" $CONFIGWRK`
management_servername=`echo "$SERVERS_management_servername" | awk -F'"' '{print $2}'`
echo_it "The management servername is set to $management_servername"  

###########################
#General Run Section
###########################

#Grab the Location of the OBSCRIPTS Staging Directory
general_obscript_stage_dir=`grep "_obscript_stage_dir" $CONFIGWRK`
obscript_stage_dir=`echo "$general_obscript_stage_dir" | awk -F'"' '{print $2}'`
echo_it "The OBSCRIPTS Staging Directory is set to $obscript_stage_dir"  

#restartmode
general_restartmode=`grep "_restartmode" $CONFIGWRK`
restartmode=`echo "$general_restartmode" | awk -F'"' '{print $2}'`
echo_it "RESTART MODE is set to $restartmode"  

#node1_ip
general_node1_ip=`grep "_node1_ip" $CONFIGWRK`
node1_ip=`echo "$general_node1_ip" | awk -F'"' '{print $2}'`
echo_it "node1_ip is set to $node1_ip"  

#node2_ip
general_node2_ip=`grep "_node2_ip" $CONFIGWRK`
node2_ip=`echo "$general_node2_ip" | awk -F'"' '{print $2}'`
echo_it "node2_ip is set to $node2_ip"  

#maxchunks
general_maxchunks=`grep "_maxchunks" $CONFIGWRK`
maxchunks=`echo "$general_maxchunks" | awk -F'"' '{print $2}'`
echo_it "maxchunks is set to $maxchunks"  

#template state
general_template_state=`grep "_template_state" $CONFIGWRK`
template_state=`echo "$general_template_state" | awk -F'"' '{print $2}'`
echo_it "The Template State is set to:  $template_state"  

#bypass_onconfig_check
general_bypass_onconfig_check=`grep "_bypass_onconfig_check" $CONFIGWRK`
bypassconfigchk=`echo "$general_bypass_onconfig_check" | awk -F'"' '{print $2}'`

if [ "$bypassconfigchk" = "yes" ]
then
echo_it "bypass_onconfig_check is set to yes - Will NOT check the onconfig file"  
elif [ "$bypassconfigchk" = "no" ]
then
echo_it "bypass_onconfig_check is set to no - The onconfig file will be checked"  
else
echo_it "Invalid value set for bypass_onconfig_check in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#bypass_download
general_bypass_download=`grep "_bypass_onconfig_check" $CONFIGWRK`
bypassdownload=`echo "$general_bypass_download" | awk -F'"' '{print $2}'`

if [ "$bypassdownload" = "yes" ]
then
echo_it "bypass_download is set to yes - BYPASS is Set on - Will NOT download the full backup level 0 from AWS"  
elif [ "$bypassdownload" = "no" ]
then
echo_it "bypass_download is set to no - The Full Backup level 0 will be downloaded from AWS"  
else
echo_it "Invalid value set for bypass_download in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#bypass_refresh
general_bypass_refresh=`grep "_bypass_onconfig_check" $CONFIGWRK`
bypassrefresh=`echo "$general_bypass_refresh" | awk -F'"' '{print $2}'`

if [ "$bypassrefresh" = "yes" ]
then
echo_it "bypass_refresh is set to yes - BYPASS is Set on - Will NOT RUN the Refresh Database Steps - Bypassing Refresh"  
elif [ "$bypassrefresh" = "no" ]
then
echo_it "bypass_refresh is set to no -  Will NOT Bypass the Refresh Steps - The Refresh Database Steps will RUN"  
else
echo_it "Invalid value set for bypass_refresh in the BuildConfig.yml Configuration File - fix value and then re-run" 
fi

#Service Account Name - connects to scp over any necessary files including the OBScripts tar file
general_svc_acct=`grep "_svc_acct" $CONFIGWRK`
SVC_ACCT=`echo "$general_svc_acct" | awk -F'"' '{print $2}'`
echo_it "The Service Account is set to: $SVC_ACCT"  

}

function get_OB_Scripts {

#User informix keys set up between management server and new server are pre-requisite
#scp the OB Scripts archive to the home directory  

if [ ! -r $INDIR/OBscripts_grabbed ]
then
echo_it "Potential new build -The OB SCRIPTS have NOT yet been transferred over from the management server - Refreshing Scripts Now"
else
echo_it "The OB SCRIPTS have previously been transferred over from the management server - Refreshing Scripts Again"
fi

scp $SVC_ACCT@$management_servername:/tmp/OBscripts.tar $HOME  > /dev/null 2>&1
if  [ $? -eq 0 ]
then
echo_it "The OB SCRIPTS have been successfylly transferred over from the management server - Refreshing Scripts Again"
touch $INDIR/OBscripts_grabbed
#Now Rename the tar file to the expected name used by the downstream setup scripts
mv $HOME/OBscripts.tar $HOME/OBScripts.tar
else
echo_it "ERROR: a Problem was encountered while OB Scripts were transferred over from the management server "
echo_it "ERROR: The program may be able to use a previous copy of the OB Scripts TAR Archive "

fi

}

#####################MAINLINE######################################

####################################################################
####If this is the First time through then set indicator and
####execute the initsetup.sh program on the primary ################
####################################################################
########### Execute the initsetup.sh program  ######################
####################################################################
clear
####FIRST CHECK TO MAKE SURE THIS IS BEING RUN BY USER INFORMIX ####
checkuser

#Check to see if the Init Day 1 Software has been set up yet through running the InitSetup.sh program
if [[ ! -d $BASEDIR ]] ; then
echo_it "The Initial Installation package has not been run - Setting Up the Installation Package Now"
###Must grab the ob scripts tar package which is used by the InitSetup.sh program for initial setup
mkdir -p $INDIR
mkdir -p $OBBUILDIR
get_OB_Scripts
$HOME/InitSetup.sh
touch $INDIR/first_time_thru
echo_it "First time through for this Server build - executed the InitSetup.sh program"
touch $BASEDIR/Setup_completed.flg
else
echo_it "The Initial Installation package setup has previously run - this phase is being skipped"
[ ! -d $INDIR ] && mkdir -p $INDIR
[ ! -d $OBBUILDIR ] && mkdir -p $OBBUILDIR
fi


if [ -r /home/informix/$CONFIGNAME ]
then
echo_it "Found the Configuration File Override in $HOME - Program will use this yml Config file: $CONFIGNAME"
sleep 2
cp /home/informix/$CONFIGNAME $CONFIG
fi

if [ -r $CONFIG ]
then
tput clear
echo_it "The Automated Server Build PROCESS is RUNNING"   
sleep 1
echo_it "PARSING VALID CONFIGURATION FILE" 
parse_config
else
echo_it "ERROR: YAML format BuildConfig.yml Configuration File NOT FOUND - Should be a valid file either in /home/informix or $BASEDIR" 
exit 100
fi

#Check to see if the OBSCRIPTS Have been grabbed yet from the management server

if [ -r $INDIR/OBscripts_grabbed ]
then
echo_it "The OB SCRIPTS have previously been transferred over from the management server - Refreshing Scripts Again"
else
echo_it "Potential new build -The OB SCRIPTS have NOT yet been transferred over from the management server - Refreshing Scripts Now"
fi

if [ -r $INDIR/first_time_thru ]
then
echo-it "The OB Scripts tar has previously been moved and unpacked since this is the first build for this server - skipping" 
rm -f $INDIR/first_time_thru
###Test for the init setup having been run - if not then unpack the OBscripts tar anyway
[ ! -r $INDIR/InitSetupRun ] && cd $OBBUILDIR; tar -xvf $OBBUILDIR/OBScripts.tar --strip-components 3 > /dev/null
echo "HIT the first time thru and untar"
else
get_OB_Scripts
#Now move and unpack the OB SCripts TAR
cp $HOME/OBScripts.tar $OBBUILDIR
######echo "untarring obscripts"
cd $OBBUILDIR
tar -xvf $OBBUILDIR/OBScripts.tar --strip-components 3 > /dev/null

fi

#

exit

clear
echo_it "Executing the InitDay1.sh process " 
####Now executing the InitDay1.sh script
nohup $BASEDIR/InitDay1.sh $SERVERNAMEnode1 $SERVERNAMEnode2 $MAXCHUNKS $PRIMARY_SERVERNAME $SECONDARY_SERVERNAME $RESTARTMODE $NODE1_IP $NODE2_IP

########## Run as Background Job and check to Make sure the job is Running ##############################
CHECKJOB=`ps -eaf|grep -c "InitDay1.sh $SERVERNAMEnode1"`
if [ $CHECKJOB -eq 2 ]
    then
      echo -n   "Successfully Started: The InitDay1 Build Process is Running:   "  >> $LOG
      date  >> $LOG
      sleep 5
  else
    echo_it "WARNING: The Data Load Process is no longer running - it may have completed or there may be further progress in the Stream - Check logs"
  fi

while [ $CHECKJOB -eq 2 ]
do

CHECKJOB=`ps -eaf|grep -c "InitDay1.sh $SERVERNAMEnode1"`
echo_it "The OPENBET Database Load is still in Progress...... "
sleep 60
done


if [ $? -eq 0 ]
then 
echo_it "Server Build Completed" 
echo_it "Successful Server Build" 
exit 0
else
echo_it "Server Build Completed with Issues" 
echo_it "Check LOGS and Messages for more Information" 
exit 3 
fi

