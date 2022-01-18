#!/bin/sh
#######Check That User is INFORMIX
#####
HOMEDIR=/home/informix
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

#...parameters passed
if [[ $# -lt 1 ]] ; then
    echo "Expecting 1 Parameter - USAGE: InitSetup.sh primary or InitSetup.sh secondary "
    echo "Rerun with proper usage"
exit 
fi
if [ $1 = "primary" ] 
then
continue
elif [ $1 = "secondary" ]
then
continue
else
echo "Expecting 1 Parameter - USAGE: InitSetup.sh primary or InitSetup.sh secondary "
echo "Rerun with proper usage"
fi
 


checkuser
clear 
echo "RUNNING INITIAL SETUP OF INIT DAY 1 "
echo "                                   "                                    
cd $HOMEDIR
#Check to make sure there is only 1 .cfg type file in the directory otherwise script cannot determine which is the correct golden source .cfg file
 configcount=`ls -l |grep -c .cfg`
 if [ $configcount -gt 1 ]
  then
    echo "WARNING :  Found more than one type .cfg config file. Cannot determine which is the correct golden source .cfg file" 
    echo "           There can be ONLY 1 .cfg golden source file resident in the /home/informix directory.  Correct and rerun this setup "
    exit 
 fi

#CHECK FOR NECESSARY FILES
if [ ! -r $HOMEDIR/*.cfg ]
then
echo "WARNING: Missing Golden Source \".cfg \" config file  (name must be in the form STATE-INITIALS.cfg) output from onstat -g cfg command - then move to $HOMEDIR and rerun this setup"
exit 100
elif [ ! -r $HOMEDIR/OBScripts.tar ]
then
echo "WARNING: Missing OBScripts.tar file - DOWNLOAD Latest OB Refresh Scripts- move to $HOMEDIR and rerun this setup"
echo "         The OB Refresh Scripts: 1) must be Downloaded 2) then create a TAR archive of the scripts with the name \"OBScipts.tar\" 3) move to $HOMEDIR Directory on this primary host" 
exit 100
elif [ ! -r $HOMEDIR/DBInitDay1.tar ]
then
echo "WARNING: Missing DBInitDay1.tar file - Retrieve tar file - move to $HOMEDIR and rerun this setup"
exit 100
elif [ ! -r $HOMEDIR/goldendistrib.tar ]
then
echo "WARNING: Missing goldendistrib.tar file - Retrieve tar file - move to $HOMEDIR and rerun this setup"
exit 100
fi

UOWNER=`stat -c '%U' $HOMEDIR/*.cfg` 
if [ $UOWNER != "informix" ]
then
echo "WARNING:  File `echo $HOMEDIR/*.cfg` must be owned by user informix"
echo "Change Ownership to informix and re-run this setup"
exit
fi

UOWNER=`stat -c '%U' $HOMEDIR/OBScripts.tar` 
if [ $UOWNER != "informix" ]
then
echo "WARNING:  File $HOMEDIR/OBScripts.tar must be owned by user informix"
echo "Change Ownership to informix and re-run this setup"
exit
fi

UOWNER=`stat -c '%U' $HOMEDIR/DBInitDay1.tar` 
if [ $UOWNER != "informix" ]
then
echo "WARNING:  File $HOMEDIR/DBInitDay1.tar must be owned by user informix"
echo "Change Ownership to informix and re-run this setup"
exit
fi


echo "Making Run Directories:"
sleep 1
if [ $1 = "primary" ]
then
mkdir -p /opt/informix/backups/EXPORTS/OBSCRIPTS
mkdir -p $HOMEDIR/dist 
else
mkdir -p /opt/informix/backups/EXPORTS 
fi

echo "Copying Files to Run Directory"
sleep 1
if [ $1 = "primary" ]
then
cp $HOMEDIR/OBScripts.tar /opt/informix/backups/EXPORTS/OBSCRIPTS
cp $HOMEDIR/goldendistrib.tar $HOMEDIR/dist
fi

cp $HOMEDIR/DBInitDay1.tar /opt/informix/backups/EXPORTS
cp  $HOMEDIR/*.cfg /opt/informix/backups/EXPORTS/Goldconfig.cfg
echo "Untar the script Archive(s) "
sleep 2
echo "DBInitDay1.tar:"
sleep 1
cd /opt/informix/backups/EXPORTS 
tar -xvf  /opt/informix/backups/EXPORTS/DBInitDay1.tar 

if [ $1 = "primary" ]
then
echo "OBScripts.tar:"
cd /opt/informix/backups/EXPORTS/OBSCRIPTS 
tar -xvf /opt/informix/backups/EXPORTS/OBSCRIPTS/OBScripts.tar 
echo "goldendistrib.tar:"
tar -xvf $HOMEDIR/dist/goldendistrib.tar 
fi

echo "                                          "
echo "********************************"                               
echo "****** SETUP COMPLETED  ********" 
echo "********************************"                               
echo "                                          "
echo "Ready to run: \"Run_as_Root.sh\" followed by \"InitDay1.sh\" - Located in /opt/informix/backups/EXPORTS "
echo "NOTE: RUN FIRST ON SECONDARY FOLLOWED BY PRIMARY SERVER"
echo "                                                        "
