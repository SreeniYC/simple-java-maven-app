#/bin/bash

#$1 API-ID
#$2 API-Key
#$3 AppName
#$4 Bamboo build working directory
#$5 Bamboo build version (Scan name)

PRESCAN_SLEEP_TIME=60
SCAN_SLEEP_TIME=120
JAVA_WRAPPER_LOCATION=$6
OUTPUT_FILE_LOCATION=$6
OUTPUT_FILE_NAME=$3'-'$5'.txt'

echo '[INFO] ------------------------------------------------------------------------'
echo '[INFO] VERACODE UPLOAD AND SCAN'


echo '[INFO] grep AppID'
app_ID=$(java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action GetAppList | grep -w "$3" | sed -n 's/.* app_id=\"\([0-9]*\)\" .*/\1/p')

if [ -z "$app_ID" ];
then
	echo '[INFO] App does not exist'
	echo '[INFO] create app: ' $3
	creat_addp=$(java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action createApp -appname "$3" -criticality high)
	echo '[INFO]app created'
	app_ID=$(java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action GetAppList | grep -w "$3" | sed -n 's/.* app_id=\"\([0-9]*\)\" .*/\1/p')
	echo '[INFO] new App-IP: ' $app_ID
	echo ""
else
	echo '[INFO] App-IP: ' $app_ID
	echo ""
fi



echo ""
echo '====== DEBUG START ======'
echo 'API-ID: ' $1
echo 'API-Key: ' $2
echo 'App-Name: ' $3
echo 'APP-ID: ' $app_ID
echo 'File-Path: ' $4
echo 'Scan-Name: ' $5
echo 'WrapperLocation: ' $6
echo '====== DEBUG END ======'
echo ""


<<"COMMENT"
echo '[INFO] VERACODE scan pre-checks'
echo '[INFO] directory checks'
# Directory argument
if [[ "$4" != "" ]]; then
	UPLOAD_DIR="$4"
else
	echo "[ERROR] Directory not specified."
	exit 1
fi

# Check if directory exists
if ! [[ -f "$UPLOAD_DIR" ]];
then
	echo "[ERROR] File does not exist"
	exit 1
else
	echo '[INFO] File set to '$UPLOAD_DIR
fi
COMMENT

echo ""
#Check if Most recent scan is completed
 java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action getbuildinfo -appid $app_ID > $OUTPUT_FILE_LOCATION$OUTPUT_FILE_NAME 2>&1
 cat $OUTPUT_FILE_LOCATION$OUTPUT_FILE_NAME
 scan_status=$(cat $OUTPUT_FILE_LOCATION$OUTPUT_FILE_NAME | grep "analysis_type" | awk -F 'status=\"' '{print $2}' | awk -F '\"' '{print $1}')
 echo '[INFO] Most recent scan status: '$scan_status
 
if [ "$scan_status" == "Results Ready" ];
then
	echo '[INFO] Good to GO'
else
	echo '[INFO] Most recent scan is not completed'
	echo '[INFO] Deleting Most recent scan'	
	java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action deletebuild -appid $app_ID > $OUTPUT_FILE_LOCATION$OUTPUT_FILE_NAME 2>&1
	echo '[INFO] Deleting the most recent scan completed'
fi
echo ""

# Version argument
if [[ "$5" != "" ]];
then
	VERSION=$5
else
	VERSION=`date "+%Y-%m-%d %T"`	# Use date as default
fi
echo '[INFO] Scan-Name set to '$VERSION
echo ""

#Upload files, start prescan and scan
echo '[INFO] upload and scan'
java -jar $JAVA_WRAPPER_LOCATION/VeracodeJavaAPI.jar -vid $1 -vkey $2 -action uploadandscan -appname $3 -createprofile true -filepath $4 -version $5 > $OUTPUT_FILE_LOCATION$OUTPUT_FILE_NAME 2>&1
echo ""
cat $OUTPUT_FILE_LOCATION$OUTPUT_FILE_NAME
upload_scan_resulst=$(cat $OUTPUT_FILE_LOCATION$OUTPUT_FILE_NAME)

if [[ $upload_scan_resulst == *"already exists"* ]];
then
	echo ""
	echo '[ERROR] This scan name already exists'
	exit 1 
elif [[ $upload_scan_resulst == *"in progress or has failed"* ]];
then
	echo ""
	echo '[ ERROR ] Something went wrong! A previous scan is in progress or has failed to complete successfully'
    exit 1
else
	echo ""
	echo '[INFO] File(s) uploaded and PreScan started'
fi

#Get Build ID
build_id=$(cat $OUTPUT_FILE_LOCATION$OUTPUT_FILE_NAME | grep build_id | awk -F "\"" '{print $2}')
echo ""
echo '====== DEBUG START ======'
echo 'Build-ID: ' $build_id
echo '====== DEBUG END ======'
echo ""
#Delete file
rm -rf $OUTPUT_FILE_LOCATIO$OUTPUT_FILE_NAME

