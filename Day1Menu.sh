#!/bin/bash
# A menu driven shell script sample template 
## ----------------------------------
# Step #1: Define variables
# ----------------------------------
EDITOR=vim
PASSWD=/etc/passwd
HOMEDIR=/home/informix
BACKUPDIR=/opt/informix/backups
BASEDIR=$BACKUPDIR/EXPORTS
INDIR=$BASEDIR/RUN_INDICATORS
LOG=$BASEDIR/DAY1Init.LOG
README=$BASEDIR/README.txt
AWSLOG=$BASEDIR/awsLOG
DAY1_deployDir=/opt/informix/backups/EXPORTS
RED='\033[0;41;30m'
GREEN='\033[0;42;30m'
YELLOW='\033[0;43;30m'
BLUE='\033[0;44;30m'
PURPLE='\033[0;45;30m'
LIGHTBLUE='\033[0;46;30m'
WHITE='\033[0;47;30m'
STD='\033[0;0;39m'
HIGHLIGHT=`tput blink` 
BOLD=`tput bold`
THISHOST=`hostname`
# ----------------------------------
# Step #2: User defined function
# ----------------------------------
pause(){
  read -p "Press [Enter] key to continue..." fackEnterKey
}

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

INITIALSETUP(){

#######Check That User is INFORMIX
#####

checkuser

while [ 1 = 1 ]
do
clear
echo "ARE WE RUNNING ON THE PRIMARY SERVER OR THE SECONDARY SERVER ?"  
read -p "(enter \" p\" or \"s\" ) ===>" answer
if [ $answer = "p" ] 
then
break
elif [ $answer = "s" ]
then
break
else
echo -e "${RED}Error..INVALID VALUE ENTERED - ENTER CORRECT VALUE${STD}"
sleep 3
fi

done

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
if [ $answer = "p" ]
then
mkdir -p /opt/informix/backups/EXPORTS/OBSCRIPTS
mkdir -p $HOMEDIR/dist
else
mkdir -p /opt/informix/backups/EXPORTS 
fi

echo "Copying Files to Run Directory"
sleep 1
if [ $answer = "p" ]
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

if [ $answer = "p" ]
then
echo "OBScripts.tar:"
cd /opt/informix/backups/EXPORTS/OBSCRIPTS 
tar -xvf /opt/informix/backups/EXPORTS/OBSCRIPTS/OBScripts.tar 
cd $HOMEDIR/dist
echo "goldendistrib.tar:"
tar -xvf $HOMEDIR/dist/goldendistrib.tar
fi

tput smso
echo "                                          "
echo "********************************"                               
echo "****** SETUP COMPLETED  ********" 
echo "********************************"                               
echo "                                          "
tput rmso
echo "Ready to run: \"Run_as_Root.sh\" followed by \"InitDay1.sh\" - Located in /opt/informix/backups/EXPORTS "
echo "NOTE: RUN FIRST ON SECONDARY FOLLOWED BY PRIMARY SERVER"
echo "                                                        "
pause
	

}
 
verifyParm() {

	echo -e "YOU HAVE ENTERED:${LIGHTBLUE} $parmcheck  "${STD}
        read -p "Is that CORRECT (y or n) ?  ======> " ans
        if [ $ans = "y" ]
           then
            echo "OK-COMMITING PARM"          
            VERIFY=0
        elif [ $ans = "n" ]
           then
             echo "OK-Discarding this parm - please re-enter value"
             VERIFY=1
         fi  
       
} 

# Set Up Command Line Parameters
setupParms(){
##        VERIFY=1
for parmnum in {1..8}
do
clear
	case $parmnum in
                1)  VERIFY=1
                    while [ $VERIFY -eq 1 ]     
                    do
		     read -p "  Enter Parm #1: SERVERNAME-hostname node1 (PRIMARY)  ===>" parm1
                     parmcheck=$parm1
                     verifyParm
                   done
                    echo $parm1 > /tmp/InitDay1Parms
                          ;;

                2)  VERIFY=1
                    while [ $VERIFY -eq 1 ]     
                    do
		     read -p "  Enter Parm #2: SERVERNAME-hostname node2 (SECONDARY)  ===>" parm2
                     parmcheck=$parm2
                     verifyParm
                   done
                    echo $parm2 >> /tmp/InitDay1Parms
                          ;;

                3)  VERIFY=1
                    while [ $VERIFY -eq 1 ]     
                    do
		     read -p "  Enter Parm #3: NUMBER OF CHUNKS to CREATE  ===>" parm3
                     parmcheck=$parm3
                     verifyParm
                   done
                    echo $parm3 >> /tmp/InitDay1Parms
                          ;;

                4)  VERIFY=1
                    while [ $VERIFY -eq 1 ]     
                    do
		     read -p "  Enter Parm #4: Pimary Servername (value in sqlhosts)  ===>" parm4
                     parmcheck=$parm4
                     verifyParm
                   done
                    echo $parm4 >> /tmp/InitDay1Parms
                          ;;

                5)  VERIFY=1
                    while [ $VERIFY -eq 1 ]     
                    do
		     read -p "  Enter Parm #5: Secondary Servername (value in sqlhosts) ===>" parm5
                     parmcheck=$parm5
                     verifyParm
                   done
                    echo $parm5 >> /tmp/InitDay1Parms
                          ;;

                6)  VERIFY=1
                    while [ $VERIFY -eq 1 ]     
                    do
		     read -p "  Enter Parm #6: restart keyword (if this run is a restart)  ===>" parm6
                     parmcheck=$parm6
                     verifyParm
                   done
                    echo $parm6 >> /tmp/InitDay1Parms
                          ;;

                7)  VERIFY=1
                    while [ $VERIFY -eq 1 ]     
                    do
		     read -p "  Enter Parm #7: Primary node1 IP (optional)  ===>" parm7
                     parmcheck=$parm7
                     verifyParm
                   done
                    echo $parm7 >> /tmp/InitDay1Parms
                          ;;

                8)  VERIFY=1
                    while [ $VERIFY -eq 1 ]     
                    do
		     read -p "  Enter Parm #8: Secondary node2 IP (optional)  ===>" parm8
                     parmcheck=$parm8
                     verifyParm
                   done
                    echo $parm8 >> /tmp/InitDay1Parms
                          ;;
                *)   echo -e "${RED}Error: UNDEFINED VALUE for PARM Number...${STD}" && sleep 2
      esac
done
#NOW DISPLAY THE PARAMETER LINE
tput smso
echo "The Following are the Parameters that will be passed to the InitDay1.sh command line: "
tput rmso
echo "    "
echo -n "InitDay1.sh "
xargs -a /tmp/InitDay1Parms
pause

}
RunInitDay1Build() {

 echo -e ${GREEN}"THE FOLLOWING IS THE COMMAND LINE WHICH WILL BE EXECUTED. .${STD}" 
tput smso
xargs -a /tmp/InitDay1Parms
tput rmso
pause 
sleep 2
cd $BASEDIR
####EXECUTE INIT DAY1 BUILD
$BASEDIR/InitDay1.sh `xargs -a /tmp/InitDay1Parms`
sleep 15

}
 setup_template_st() {

if [ ! -r $BASEDIR/master_state_code_list ] 
then
echo "The Master State Code List: $BASEDIR/master_state_code_list is MISSING" 
echo "Load the Master State Code list and then re-try this option"
else
##### A valid state code list exists - input the state code
while [ 1 = 1 ]
do
clear
echo "Input the Balid 2 letter state code (MUST BE LOWER CASE):"  
read -p "(enter 2 letter state code  ) ===>" st_code
grep $st_code $BASEDIR/master_state_code_list

if  [ $? -eq 0 ]
 then
echo $st_code > $INDIR/state_parm
break
else
echo -e "${RED}Error..INVALID State code ENTERED - ENTER CORRECT VALUE${STD}"
sleep 3
fi

done

fi

}
 
# function to display menus
show_menus() {
	clear
        tput cup 5 20
	echo -e ${YELLOW}"                                                            ${STD}"
        tput cup 6 20
        echo "          HOST:  $THISHOST                                "
        tput cup 7 20
	echo -e ${GREEN}"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~${STD}"	
        tput cup 8 20
	echo "             IXSFD  INIT  DAY  1  MAIN  MENU               "
        tput cup 9 20
	echo -e ${GREEN}"~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        tput cup 10 20
	echo "                 1. SETUP THE SCRIPTS                      "
        tput cup 11 20
	echo "                 2. SETUP THE PARAMETERS                   "
        tput cup 12 20
	echo "                 3. **BUILD THE SERVER - Run Init Day 1**  "
        tput cup 13 20
	echo "                 4. DISPLAY THE RUN LOG                    "
        tput cup 14 20
	echo "                 5. DOWNLOAD THE AWS BACKUP SEPARATELY     "
        tput cup 15 20
	echo "                 6. REPLAY THE AWS DOWNLOAD LOG            "
        tput cup 16 20
	echo "                 7. SETUP the TEMPLATE STATE for Download  "
        tput cup 17 20
	echo "                 8. RELOAD GOLDEN STATISTICAL DISTRIBUTIONS"
        tput cup 18 20
	echo "                 9. EXIT MENU SYSTEM                       "
        tput cup 19 20
	echo -e ${YELLOW}"                                                           "
}
# read input from the keyboard and take a action
# invoke the one() when the user select 1 from the menu option.
# invoke the two() when the user select 2 from the menu option.
# Exit when user the user select 3 form the menu option.
read_options(){
	local choice
        tput cup 21 40
	echo -e ${GREEN}
        tput cup 22 20
	read -p "                    Enter choice [ 1 - 9] ===>" choice
	case $choice in
		1)  echo -e ${STD} "YOU CHOSE SETUP THE SCRIPTS"  
                   sleep 2
                   pause
                   INITIALSETUP  
                          ;;
		2)  echo -e ${STD} "YOU CHOSE SETUP THE PARAMETERS"
                    sleep 2
                    pause
                    setupParms
                          ;;
		3) echo -e ${STD} "YOU CHOSE BUILD THE SERVER" 
                   sleep 2
                   clear 
                   #Check to make sure you are running as user informix
                   checkuser
                   #Check to make sure that Run_as root has been run successfully
                   if [ -r  $INDIR/runasroot.FLG ]
                      then
                      echo
                      tput smso
                      echo "The Run_as_root script has been successfully run " | tee -a $LOG
                      tput rmso 
                      echo  
                      echo "You are about to Initiate the Server Build" 
                   pause
                   RunInitDay1Build
                   else
                    echo -e "${RED}Error: The Run_as_root script has NOT BEEN RUN...ABORTING.. ${STD}" && sleep 4
                    fi
                          ;;
		4) echo -e ${STD} "YOU CHOSE DISPLAY THE RUN LOG" 
                   sleep 2 
                   pause
                  clear
                  if [ -r $LOG ]
                     then more $LOG
                     sleep 15
                  else
                     echo -e "${RED}Error: The RUN LOG does not exist...${STD}" && sleep 2
                  fi
                          ;;
		5) echo -e ${STD} "YOU CHOSE DOWNLOAD THE LATEST GOOD BACKUP FROM AWS"  
                   sleep 2
                   checkuser
                   pause
                   ST=`cat $INDIR/state_parm`
                   nohup $DAY1_deployDir/download_lvl0_S3.sh $ST >> $BASEDIR/awsLOG 2>&1 &
                   tput smso
                   echo "======================================================"
                   echo "The AWS Download has been initiated int the background"
                   echo "Use Option #6 to Display the Progress                 "
                   echo "======================================================"
                   tput rmso
                          ;;
		6) echo -e ${STD} "YOU CHOSE TO REPLAY THE AWS DOWNLOAD LOG" 
                  sleep 2 
                  pause
                  clear
                  if [ -r $AWSLOG ]
                     then cat $AWSLOG
                  else
                     echo -e "${RED}Error: The AWSLOG does not exist...${STD}" && sleep 2
                  fi
                          ;;
		7) echo -e ${STD} "SETUP the TEMPLATE STATE for Download" 
                   sleep 2 
                   pause
                  clear
                  setup_template_st
                   if [  -r $INDIR/state_parm ]
                    then
                     display_parm=`cat $INDIR/state_parm`
                     echo "SUCCESSULLY ENTERED STATE PARM: $display_parm"
                     sleep 2
                   else 
                     echo -e "${RED}Error: The $INDIR/state_parm File does not exist...${STD}" && sleep 2
                   fi
                          ;;
		8) echo -e ${STD} "YOU CHOSE RELOAD THE STATISTICAL DISTRIBUTIONS     " 
                   sleep 2 
                   pause
                  clear
                  echo -e "${RED}Error: RELOAD OF DISTRIBUTIONS COMING IN VERSION 2..${STD}" && sleep 3
                          ;;
		9) echo -e ${STD} "EXITING THE MENU SYSTEM" 
                  sleep 3 
                  clear
                  exit 0
                          ;;
		*) echo -e "${RED}Error...${STD}" && sleep 2
	esac
}
 
# ----------------------------------------------
# Step #3: Trap CTRL+C, CTRL+Z and quit singles
# ----------------------------------------------
##trap '' SIGINT SIGQUIT SIGTSTP
trap ''  SIGQUIT SIGTSTP
 
# -----------------------------------
# Step #4: Main logic - infinite loop
# ------------------------------------
while true
do
 
	show_menus
	read_options
done



###InitDay1.sh
