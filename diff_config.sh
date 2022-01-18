#!/bin/sh

##########################################################
##Each Configuration Values File Must be in the format
##of the output from the onstat -g cfg command 
##One file is from the Golden source live system compared
##With the Day 1 system configuration file
##########################################################
###############################################################
####VALIDATING the ONCONFIG using the Golden Config Source
NEWSTATE=$1
##Test value - remove
THISSERVER=`echo $HOSTNAME`
##Test value - remove
##DAY1ONCONFIG=/opt/informix/scripts/newdev/cfg.va
##LOG=/opt/informix/scripts/newdev/Day1Log
BACKUPDIR=/opt/informix/backups
BASEDIR=$BACKUPDIR/EXPORTS
DAY1ONCONFIG=$BASEDIR/onconfig.$THISSERVER
LOG=$BASEDIR/DAY1Init.LOG
##BASEDIR=/opt/informix/scripts/newdev
GOLDENSOURCE_CFG=$BASEDIR/Goldconfig.cfg
##DAY1ONCONFIG=$BASEDIR/onconfig.$THISSERVER
THISHOST=`hostname`
#...script name
_scriptName=$(basename $0)

#SET INFORMIX ENVIRONMENT
_envFile=/etc/profile.d/informix.environment.sh
. ${_envFile}

#...temporary alert file
_tmpMessage=/tmp/.${_scriptName}_$$.message
>  ${_tmpMessage} 
###################################################################
####NOTE:  The Parm is set to "G" when the script is executed   ###
###        remotely via ssh and we need to generae the cfg file ###     
###################################################################
#...parameters passed
if [[ $# -ne 1 ]] ; then
    echo "Expecting at least 1 Parameter "
    echo "USAGE: diff_config.sh G or N" 
    exit 2
fi


function Verify_Parms {
###NOW COMPARE VALUES#####

#LIST OF  PARAMETERS THAT WE WANT TO VERIFY
parlist=(DBSERVERNAME DBSERVERALIASES RAS_PLOG_SPEED) 

for parms in "${parlist[@]}"
do

grep $parms $BASEDIR/configdiff.out >/dev/null
if  [ $? -eq 0 ]
then
echo "found" >>  ${_tmpMessage} 
else
echo "NOT" >>  ${_tmpMessage} 
fi


done

}

function PROCESSFILE
{

sdiff -s $GOLDENSOURCE_CFG $DAY1ONCONFIG > $BASEDIR/configdiff.out
COUNT=`cat $BASEDIR/configdiff.out|wc -l`

#######################
##FOR DEBUG 
##echo "COUNT IS" $COUNT
#######################

####There should only be 4 expected output lines in diff output file

if [[ "$COUNT" -gt 4 ]]
then
tput smso
echo "ERROR: GOLDEN CONFIG and THE NEW DAY1 CONFIG on $THISHOST are DIFFERENT " | tee -a $LOG
echo "Please Examine Diff Values and Correct The New Onconfig Before Proceeding  " | tee -a $LOG
tput rmso
echo "ONLY PARMS DBSERVERALIASES,DBSERVERNAME, and RAS_PLOG_SPEED should appear"  | tee -a $LOG
echo
more $BASEDIR/configdiff.out
exit 2
else
Verify_Parms
#######################
##DEBUG VALUES
##Messages=`cat ${_tmpMessage}`
##echo "MESSAGES ARE"  $Messages
#######################
grep NOT ${_tmpMessage} >/dev/null
if [ $? -eq 1 ]
then
echo 
tput smso
echo "PASSED: GOOD NEW DAY1 CONFIG File on $THISHOST                                     " | tee -a $LOG
tput rmso
echo
exit 0
else
tput smso
echo "ERROR:  SOMETHING WENT WRONG - Expected Parm Value Matching Did NOT Occur           " | tee -a $LOG
echo
echo "GOLDEN CONFIG and THE NEW DAY1 CONFIG on $THISHOST May be DIFFERENT                 " | tee -a $LOG
echo "Please Examine Diff Values and Correct The New Onconfig File(s)  Before Proceeding  " | tee -a $LOG
echo "ONLY PARMS DBSERVERALIASES,DBSERVERNAME, and RAS_PLOG_SPEED should appear           " | tee -a $LOG
tput rmso
page $BASEDIR/configdiff.out                                                                | tee -a $LOG 
exit 2
fi
fi


##goldenparm_value=`echo $line|awk '{print $2}'`
##ONCONFIGparm_value=`echo $onconfigPARM|awk '{print $2}'`

}

###MAINLINE BEGINS HERE
###capture=`echo $line|awk '{print $1}'`

clear
echo "VALIDATING ONCONFIG VALUES:"| tee -a $LOG
sleep 1
if  [ $GENERATE="G" ]
then 
onstat -g cfg > $BASEDIR/onconfig.$THISSERVER 
fi

PROCESSFILE


