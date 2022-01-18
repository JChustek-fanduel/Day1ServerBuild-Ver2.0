#!/bin/sh
#######################################################################################
###########     download_lvl0_S3.sh  Ver 2.0 
###########
###########   Downloads the most recent Full backup from S3 storage
###########
###########    download_lvl0_S3.sh < 2 letter state code >
###########
###########    This program is normally run from the Day 1 build  InitDay1.sh
###########    and the parm is passed automatically within the script
###########    The parm is populated from a text file created by the Day1Menu.sh
###########
###########     Author:  Jerry Chustek
###########
###################################################################################### 

BACKUPDIR=/opt/informix/backups
BASEDIR=$BACKUPDIR/EXPORTS
LOG=$BASEDIR/DAY1Init.LOG
DAY1_deployDir=$BASEDIR/Day1binScripts
INDIR=$BASEDIR/RUN_INDICATORS
DATE=$(date +%Y-%m-%d)
state=$1
##############################################
#INITIALIZE VARIABLES
##############################################
successful_find=0
UseNode1A=0
UseNode2A=0
UseNode1B=0
UseNode2B=0
use_2a_node_as_latest=0
use_1a_node_as_latest=0
use_2b_node_as_latest=0
use_1b_node_as_latest=0
A_nodes_disqualified=0
B_nodes_disqualified=0


function showUsage {
echo "download_level0.sh < valid 2 letter state code > "

}

#...parameters passed
if [[ $# -lt 1 ]] ; then
    echo "Expecting at least 1 Parameter: Parameter should be the 2 letter code of the State"
    showUsage
    exit 100
fi

function pully {

#######################################################################
##Form the 4 combinations of Servers to query for the latest file #####
## 01,02,a,b vm's                                                 #####
#######################################################################
 num="1"
 suffix="a"
 pullname1a="$state-ixsfd0$num$suffix-prd$state.prd.fndlsb.net"
 suffix="b"
 pullname1b="$state-ixsfd0$num$suffix-prd$state.prd.fndlsb.net"
 echo $pullname1
## co-ixsfd01-prdco.prd.fndlsb.net
 num="2"
 suffix="a"
pullname2a="$state-ixsfd0$num$suffix-prd$state.prd.fndlsb.net"
 suffix="b"
pullname2b="$state-ixsfd0$num$suffix-prd$state.prd.fndlsb.net"

}

####Now capture the dates that each individua backup was created #########
function capture_dates {

last_good_bkp_txt1a=`aws s3 ls s3://ixsfd-backups-production/$pullname1a/full/last_good_backup.txt --recursive|grep last_good_backup`
date1a=`echo $last_good_bkp_txt1a|awk '{print $1}'`

last_good_bkp_txt2a=`aws s3 ls s3://ixsfd-backups-production/$pullname2a/full/last_good_backup.txt --recursive|grep last_good_backup`
date2a=`echo $last_good_bkp_txt2a|awk '{print $1}'`


last_good_bkp_txt1b=`aws s3 ls s3://ixsfd-backups-production/$pullname1b/full/last_good_backup.txt --recursive|grep last_good_backup`
date1b=`echo $last_good_bkp_txt1b|awk '{print $1}'`

last_good_bkp_txt2b=`aws s3 ls s3://ixsfd-backups-production/$pullname2b/full/last_good_backup.txt --recursive|grep last_good_backup`
date2b=`echo $last_good_bkp_txt2b|awk '{print $1}'`

}

function most_recent_A_node {

########debug displays##############################
## echo "Reached most_recent_A_node - date1a is: $date1a"
## echo "         date2a is: $date2a"
## echo "LATEST_A_node_date is : $LATEST_A_node_date"
####################################################

if [[ $((  $(echo $date1a | tr -d '-')   -  $(echo $date2a | tr -d '-')  )) -gt 0 ]] ; then
   echo "The most recent backup date on the A node is 1a:$date1a" | tee -a $LOG
   LATEST_A_node_date=$date1a
   UseNode1A=1
fi

if [[ $((  $(echo $date1a | tr -d '-')   -  $(echo $date2a | tr -d '-')  )) -lt 0 ]] ; then
   echo "The most recent backup date on the A node is 2a:$date2a" | tee -a $LOG
   LATEST_A_node_date=$date2a
   UseNode2A=1
fi

if [[ $((  $(echo $date1a | tr -d '-')   -  $(echo $date2a | tr -d '-')  )) -eq 0 ]] ; then
   echo "The most recent backup date on the A node is present on both 1a and 2a :$date2a" | tee -a $LOG
   echo "Using the date from 1a" | tee -a $LOG
   LATEST_A_node_date=$date1a
   UseNode1A=1
fi
echo "Leaving most_recent_A_node  :  "
echo "UseNode1A: is $UseNode1A"
echo "UseNode2A: is $UseNode2A"
echo "date1a: $date1a"
echo "date2a: $date2a"

}

function most_recent_B_node {

########debug displays##############################
## echo "Reached most_recent_B_node - date1b is: $date1b"
## echo "         date2b is: $date2b"
####################################################

if [[ $((  $(echo $date1b | tr -d '-')   -  $(echo $date2b | tr -d '-')  )) -gt 0 ]] ; then
   echo "The most recent backup date on the B node is 1b:$date1b" | tee -a $LOG
   LATEST_B_node_date=$date1b
   UseNode1B=1
fi

if [[ $((  $(echo $date1b | tr -d '-')   -  $(echo $date2b | tr -d '-')  )) -lt 0 ]] ; then
   echo "The most recent backup date on the B node is 2b:$date2b" | tee -a $LOG
   LATEST_B_node_date=$date2b
   UseNode2B=1
fi

if [[ $((  $(echo $date1b | tr -d '-')   -  $(echo $date2b | tr -d '-')  )) -eq 0 ]] ; then
   echo "The most recent backup date on the B node is present on both 1b and 2b :$date2b" | tee -a $LOG
   echo "Using the date from 1b" | tee -a $LOG
   LATEST_B_node_date=$date1b
   UseNode1B=1
fi


}

function check_most_current_A_node {

########debug displays##############################
## echo "HIT check_most_current_A_node"
## echo "last_good_bkp_txt1a: $last_good_bkp_txt1a"
## echo "last_good_bkp_txt2a: $last_good_bkp_txt2a"
## echo "date1a is: $date1a"
## echo "date2a is: $date2a"
## echo "LATEST_A_node_date is: $LATEST_A_node_date "
####################################################

if [ ! -z  "$last_good_bkp_txt1a" ] ;  then
 if [ ! -z  "$last_good_bkp_txt2a" ] ;  then  
   #both nodes have values - test which date is more recent
most_recent_A_node
 else
## disqualify the 2a node
   donot_use_2anode=1 
 fi
else 
discard_1aNode=1 
   if [ -z  "$last_good_bkp_txt2a" ] ;  then
      donot_use_2anode=1
  fi
fi
  
if [ $donot_use_2anode -eq 1 ]
then
  if [ $1a_node_disqualified -eq 1 ]
    then 
    echo "The \"A\" nodes are disqualified from downloading backups - not active" | tee -a $LOG
     A_nodes_disqualified=1
  else
   use_1a_node_as_latest=1  
   LATEST_A_node_date=$date1a
   UseNode1A=1
  fi
else 
  if [ $discard_1aNode -eq 1 ]
    then
   use_2a_node_as_latest=1  
   LATEST_A_node_date=$date2a
   UseNode2A=1
  fi  
fi


#########DEBUG ###########################################
## echo "Leaving check_most_current_A_node"
## echo "LATEST_A_node_date is $LATEST_A_node_date"
## echo "date1a is: $date1a"
## echo "date2a is: $date2a"
## echo "donot_use_2anode: $donot_use_2anode"
## echo "discard_1aNode: $discard_1aNode"
## echo "use_1a_node_as_latest: $use_1a_node_as_latest"
## echo "use_2a_node_as_latest: $use_2a_node_as_latest"
############################################################

}

function check_most_current_B_node {

########debug displays##############################
## echo "HIT check_most_current_B_node"
## echo "last_good_bkp_txt1b: $last_good_bkp_txt1b"
## echo "last_good_bkp_txt2b: $last_good_bkp_txt2b"
## echo "date1b is: $date1b"
## echo "date2b is: $date2b"
####################################################

if [ ! -z  "$last_good_bkp_txt1b" ] ;  then
 if [ ! -z  "$last_good_bkp_txt2b" ] ;  then  
## both nodes have values - test which date is more recent
most_recent_B_node
 else
   #disqualify the 2b node
   donotuse_2bnode=1 
 fi
else 
donotuse_1bnode=1 
  if [ -z  "$last_good_bkp_txt2b" ] ;  then
  donotuse_2bnode=1
  fi
fi
  
if [ $donotuse_2bnode -eq 1 ]
then
  if [ $donotuse_1bnode -eq 1 ]
     then
    echo "The \"B\" nodes are disqualified from downloading backups - not active" | tee -a $LOG
     B_nodes_disqualified=1
  else
   use_1b_node_as_latest=1  
   LATEST_B_node_date=$date1b
   UseNode1B=1
  fi
else 
  if [ $donotuse_1bnode -eq 1 ]
    then
   use_2b_node_as_latest=1  
   LATEST_B_node_date=$date2b
   UseNode2B=1
  fi  
fi

}

function download_A_node   {

########debug displays#######
## echo $pullname1a
## echo $pullname2a
## echo $pullname1b
## echo $pullname2b
#############################

if [ $UseNode1A -eq 1 ]
then
echo "Downloading the Latest Backup from  $state from NODE 1A: $pullname1a for DATE: $date1a" | tee -a $LOG
/usr/local/bin/aws s3 cp s3://ixsfd-backups-production/$pullname1a/full/last_good_backup.txt /opt/informix/backups/awsfiles/
GOODLEVEL0=`cat /opt/informix/backups/awsfiles/last_good_backup.txt`
echo "The Name of the Full Backup Archive File is : $GOODLEVEL0 " | tee -a $LOG
/usr/local/bin/aws s3 cp s3://ixsfd-backups-production/$pullname1a/full/$GOODLEVEL0 /opt/informix/backups/awsfiles/
elif [ $UseNode2A -eq 1 ]
then
echo "Downloading the Latest Backup from  $state from NODE 2A: $pullname2a for DATE: $date2a" | tee -a $LOG
/usr/local/bin/aws s3 cp s3://ixsfd-backups-production/$pullname2a/full/last_good_backup.txt /opt/informix/backups/awsfiles/
GOODLEVEL0=`cat /opt/informix/backups/awsfiles/last_good_backup.txt`
echo "The Name of the Full Backup Archive File is : $GOODLEVEL0 " | tee -a $LOG
/usr/local/bin/aws s3 cp s3://ixsfd-backups-production/$pullname2a/full/$GOODLEVEL0 /opt/informix/backups/awsfiles/
else
echo "Undefined Error in Download Selection - Program Aborting " | tee -a $LOG
exit 100
fi

if [ $? -eq 0 ]
then
touch $INDIR/level_0_downloaded
successful_find=1
else
successful_find=0
fi

########DEBUG#########################
## echo "UseNode1A: $UseNode1A"
## echo "UseNode2A: $UseNode2A"
######################################

}

function download_B_node   {

if [ $UseNode1B -eq 1 ]
then
echo "Downloading the Latest Backup from  $state from NODE 1B: $pullname1b for DATE: $date1b" | tee -a $LOG
/usr/local/bin/aws s3 cp s3://ixsfd-backups-production/$pullname1b/full/last_good_backup.txt /opt/informix/backups/awsfiles/
GOODLEVEL0=`cat /opt/informix/backups/awsfiles/last_good_backup.txt`
echo "The Name of the Full Backup Archive File is : $GOODLEVEL0 " | tee -a $LOG
/usr/local/bin/aws s3 cp s3://ixsfd-backups-production/$pullname1b/full/$GOODLEVEL0 /opt/informix/backups/awsfiles/
elif [ $UseNode2B -eq 1 ]
then
echo "Downloading the Latest Backup from  $state from NODE 2B: $pullname2b for DATE: $date2b" | tee -a $LOG
/usr/local/bin/aws s3 cp s3://ixsfd-backups-production/$pullname2b/full/last_good_backup.txt /opt/informix/backups/awsfiles/
GOODLEVEL0=`cat /opt/informix/backups/awsfiles/last_good_backup.txt`
echo "The Name of the Full Backup Archive File is : $GOODLEVEL0 " | tee -a $LOG
/usr/local/bin/aws s3 cp s3://ixsfd-backups-production/$pullname2b/full/$GOODLEVEL0 /opt/informix/backups/awsfiles/
else
echo "Undefined Error in Download Selection - Program Aborting " | tee -a $LOG
exit 100
fi

if [ $? -eq 0 ]
then
touch $INDIR/level_0_downloaded
successful_find=1
else
successful_find=0
fi


}


function check_most_recent_VM_backup {

###########DEBUG###############################
##echo "A NODE DATE IS $LATEST_A_node_date "
##echo "B NODE DATE IS $LATEST_B_node_date "
###############################################

if [[ $((  $(echo $LATEST_A_node_date | tr -d '-')   -  $(echo $LATEST_B_node_date | tr -d '-')  )) -gt 0 ]] ; then
   echo "The most recent backup date is on the A node :$LATEST_A_node_date" | tee -a $LOG
   download_A_node
fi

if [[ $((  $(echo $LATEST_A_node_date | tr -d '-')   -  $(echo $LATEST_B_node_date | tr -d '-')  )) -lt 0 ]] ; then
   echo "The most recent backup date on the B node: $LATEST_B_node_date" | tee -a $LOG
   download_B_node
fi

if [[ $((  $(echo $LATEST_A_node_date | tr -d '-')   -  $(echo $LATEST_B_node_date | tr -d '-')  )) -eq 0 ]] ; then
   echo "The most recent backup date on the A node is present on both the A and B nodes" | tee -a $LOG
   echo "Using the date from the A node" | tee -a $LOG
   download_A_node
   
fi

}

####Now determine the most recent of the backups that are available for this state #########
function determine_most_recent_backup {

###Check to determine which nodes on the "A" node VM's are most current

#####Checks########
check_most_current_A_node
check_most_current_B_node


if [ $A_nodes_disqualified -eq 1 ]
then
#Use most current B node
download_B_node
elif [ $B_nodes_disqualified -eq 1 ]
then
#Use most current A node
download_A_node
else
##Determine which is the most current nodes of the VM's - A or B
check_most_recent_VM_backup
fi

}

##########################################
############ MAINLINE ####################
##########################################

echo -n " download_lvl0_S3.sh has Started" | tee -a $LOG
date | tee -a $LOG
echo "Downloading is set for Template state:  $state" | tee -a $LOG 
##############################################
###     Construct the Servernames          ###
##############################################
pully

#################################################################
### Download the last good backup metadata from each bucket #####
### Use ls command to determine the latest backup stored in #####
### the S3 repository.                                      #####
### Once determined - then download that full backup from   #####
### the indicated bucket                                    #####
#################################################################
discard_1aNode=0
donot_use_2anode=0
donotuse_1bnode=0
donotuse_2bnode=0
capture_dates
determine_most_recent_backup

if [ $successful_find -eq 1 ]
then
echo -n "The Full Backup was Successfully Downloaded from S3 at: " | tee -a $LOG 
date | tee -a $LOG
else
echo "ERROR: The most recent Full Backup was either NOT FOUND or DID NOT DOWNLOAD SUCCESSFULLY" | tee -a $LOG
echo "       The process is aborting - The backup must be downloaded manually or rerun this program " | tee -a $LOG
exit 2
fi


echo " download_lvl0_S3.sh has ENDED" | tee -a $LOG
date >> $LOG
echo "download_backup_from_S3 ENDED" > $INDIR/PROGRESS_DETAILED_checkpoint.txt
