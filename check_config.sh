#!/bin/sh

####VALIDATING the ONCONFIG using the Golden Config Source
GOLENDSOURCE_CFG=/opt/informix/scripts/newdev/pa.cfg
ONCONFIG=/opt/informix/scripts/newdev/onconfig
LOG=/opt/informix/scripts/newdev/Day1Log
FIRST_TIME_THRU=0

function PROCESSFILE
{
##capture=`echo $line|awk '{print $1}'`
##if capture="#" comment then skip

##FIRSTCHAR=`echo ${capture:1:1}`

goldenparm_value=`echo $line|awk '{print $2}'`
echo "Validating Onconfig Parameter $capture" >> $LOG 

#GRAB PARM LINE FROM ONCONFIG
#########onconfigPARM=`grep "${capture}" $ONCONFIG|grep -v "#"` >/dev/null
onconfigPARM=`grep "${capture}" $ONCONFIG|grep -v "#"|grep ^$FIRSTCHAR` >/dev/null

COUNT=`grep -c "${capture}" $ONCONFIG|grep -v "#"`
echo "COUNT IS:" $COUNT >>onconfigparmsLine

echo "FIRST CHARACTER SHOULD BE" $FIRSTCHAR >>onconfigparmsLine
echo "ONCONFIG PARM"  $onconfigPARM  >>onconfigparmsLine
ONCONFIGparm_value=`echo $onconfigPARM|awk '{print $2}'`

###NOW COMPARE VALUES#####
echo "CONFIG FILE VALUE:" $ONCONFIGparm_value >>onconfigparmsLine
echo "   ">>onconfigparmsLine
#echo "GOLDEN SOURCE PARM VALUE:" $goldenparm_value

##sleep 2
if  [ -z "$goldenparm_value" ] 
then
echo "SKIPPING ZERO VALUE VARIABLE goldenparm_value"
elif  [ -z "$ONCONFIGparm_value" ] 
then
echo "SKIPPING ZERO VALUE VARIABLE ONCONFIGparm_value"
elif [ $goldenparm_value == $ONCONFIGparm_value ] 
then
echo "EUREKA GOOD AND EQUAL" >>onconfigparmsLine
else
echo "ONCONFIG NOT EQUAL to GOLDEN SOURCE" >>onconfigparmsLine
 
fi
}

function test_for_blankparms 
{

skip_this_parm=0
#LIST OF BLANK PARAMETERS THAT WE WANT TO BYPASS
parlist=(RA_PAGES DBSPACETEMP PRELOAD_DLL_FILE SBSPACENAME SYSSBSPACENAME SBSPACETEMP CDR_QDATA_SBSPACE CDR_DBSPACE CDR_APPLY CDR_SUPPRESS_ATSRISWARN SHARD_ID SDS_TEMPDBS SDS_PAGING HA_ALIAS FAILOVER_CALLBACK DB_LIBRARY_PATH MQSERVER MQCHLLIB MQCHLTAB SSL_KEYSTORE_LABEL BAR_BSALIB_PATH BAR_IXBAR_PATH REMOTE_SERVER_CFG REMOTE_USERS_CFG ENCRYPT_CIPHERS ENCRYPT_SWITCH DBSERVERALIASES) 

for skiparms in "${parlist[@]}"
do

##echo "FIRST TIME THRU"  $FIRST_TIME_THRU
if [ $FIRST_TIME_THRU -eq 0 ]
then
echo "SKIPPING the following onconfig parms normally blank:" $skiparms
fi

if [ $capture = $skiparms ]
then
###sleep 5
skip_this_parm=1
fi
done

 
FIRST_TIME_THRU=1

if [ $skip_this_parm -eq 1 ]
then
return 1
else
return 0
fi

}


IFS=''
while read -u 9 line
do
##READ FROM THE GOLDEN SOURCE CONFIG
##EACH VALUE SPECIFIED IN THIS fILE SHOULD BE VERIFIED IN THE INFORMIX ONCONFIG FILE
capture=`echo $line|awk '{print $1}'`
##if capture="#" comment then skip
FIRSTCHAR=`echo ${capture:0:1}`
echo "capture is:" $capture
###sleep 2 

if [ -z "$capture" ]
then
echo "SKIPPING BLANK LINE: $FIRSTCHAR"
elif  [ $FIRSTCHAR = "#" ]
then
echo "SKIPPING COMMENT: $FIRSTCHAR"
elif [ $capture = "IBM" ]
then
echo "SKIPPING LINE WITH IBM"
elif  [ $capture = "Configuration" ]
then
echo "SKIPPING LINE WITH Configuration"
elif  [ $capture = "name" ]
then
echo "SKIPPING LINE WITH name"
else
clear
##sleep 4
test_for_blankparms

if [ $? -eq 1 ]
then
echo "Skipping Line With Parm set to:" $capture 
##sleep 7
else
PROCESSFILE 
fi
fi

##FIRST_TIME_THRU=1
done 9< $GOLENDSOURCE_CFG
