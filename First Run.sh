#!/bin/bash

######################################
# Variables                          #
######################################

JAMF='/usr/sbin/jamf'
JSSCONTACTTIMEOUT=120
JSSURL='https://jss.mycompany.com:8443'
ENROLLLAUNCHDAEMON='/Library/LaunchDaemons/com.jamfsoftware.firstrun.enroll.plist'
TIMESERVER=
TIMEZONE=Australia/Sydney
PORTABLE=0
TIMESTAMP="$(date +"%Y-%m-%d-%H-%M")"

######################################
#Logging                             #
######################################

LOGFILE=/var/log/JSS_Imaging_Build.log


LOGOUTPUT(){

    DATE=`date +%H:%M:%S`
    LOG="$LOGFILE"
    
    echo "$DATE" " $1" >> $LOG
}

LOGACTION(){

    DATE=`date +%H:%M:%S`
    LOG="$LOGFILE"
    
    echo -n "$DATE" " $1" >> $LOG
}

######################################
# Tasks not requiring JSS connection #
######################################

# Set time zone, NTP use, and NTP server.
LOGOUTPUT "--- Setting Date and Time"
LOGACTION & systemsetup -setnetworktimeserver $TIMESERVER | tee -a ${LOGFILE}
LOGACTION & systemsetup -settimezone "$TIMEZONE" | tee -a ${LOGFILE}
LOGACTION & systemsetup -setusingnetworktime on | tee -a ${LOGFILE} 
LOGOUTPUT "Done"
echo -e "" >> $LOGFILE

echo "--- Start Machine Build @" "$TIMESTAMP" >> $LOGFILE
echo -e "\n" >> $LOGFILE

#Set Machine Name
LOGOUTPUT "--- Setting Machine Name" >> $LOGFILE
/usr/sbin/jamf setComputerName -prefix M -useSerialNumber | tee -a ${LOGFILE}
echo -e "" >> $LOGFILE

# Enable SSH, as StartupScript.sh which normally does this isn't created early enough
LOGOUTPUT "--- Starting SSH daemon"
${JAMF} startSSH
echo "Command exit code: $?" >> $LOGFILE
LOGOUTPUT "Done"
echo -e "" >> $LOGFILE

# Create /Users/Shared if non-existent
LOGOUTPUT "--- Creating /Users/Shared"
if [ ! -d /Users/Shared ]; then
    mkdir -p /Users/Shared | tee -a ${LOGFILE}
    chown root /Users/Shared | tee -a ${LOGFILE}
    chgrp wheel /Users/Shared | tee -a ${LOGFILE}
    chmod 1777 /Users/Shared | tee -a ${LOGFILE}
fi
LOGOUTPUT "Done"
echo -e "" >> $LOGFILE

# Clean up JAMF Imaging's Spotlight disabling files:
LOGOUTPUT "--- Cleaning up Spotlight disabling files and restarting indexing"

TARGETFILES=("/.fseventsd/no_log" "/.metadata_never_index")
FIXNEEDED=0
RESULT=0

for FILE in "${TARGETFILES[@]}"; do
    if [ -e $FILE ]; then
        (( FIXNEEDED += 1 ))
        rm -f "$FILE" 
        (( RESULT += $? ))
    fi
done

if [ $FIXNEEDED -gt 0 ]; then
    LOGOUTPUT 'Leftover files found. Cleanup required.'

    if [ $RESULT -eq 0 ]; then
        LOGOUTPUT 'Cleanup was successful.'
    else
        LOGOUTPUT 'There were problems cleaning up the files.'
    fi

    # clear index and start Spotlight
    mdutil -E -i on /
else
    LOGOUTPUT 'No cleanup required!'
fi
echo -e "" >> $LOGFILE

# Wait a certain number of minutes for JAMF enroll.sh script to complete.

WAITLIMIT=$(( 8 * 60 ))
WAITINCREMENT=30
LOGOUTPUT "--- Checking to see if JAMF enroll.sh is still running"
while [ -e "$ENROLLLAUNCHDAEMON" ]; do
    if [ $WAITLIMIT -le 0 ]; then
        LOGOUTPUT "Reached wait timeout of ${WAITLIMIT} seconds!"
        break
    fi

LOGOUTPUT "Still not complete. Waiting another ${WAITINCREMENT} seconds..."
    sleep $WAITINCREMENT 
    (( WAITLIMIT -= $WAITINCREMENT ))

done
LOGOUTPUT "Continuing now..."
echo -e "" >> $LOGFILE

##################################
# Tasks requiring JSS connection #
##################################

# Test for JSS connection
LOGOUTPUT "--- Testing JSS connection..."
loop_ctr=1
while ! curl --silent -o /dev/null --insecure ${JSSURL} ; do
    sleep 1;
    loop_ctr=$((loop_ctr+1))
    if [ $((loop_ctr % 10 )) -eq 0 ]; then
        LOGOUTPUT "${loop_ctr} attempts"
    fi

    if [ ${loop_ctr} -eq ${JSSCONTACTTIMEOUT} ]; then
        LOGOUTPUT "I'm bored ... giving up after ${loop_ctr} attempts"
        exit 1
    fi
done	
LOGOUTPUT "Success"
echo -e "" >> $LOGFILE

LOGOUTPUT "--- Launching Enrolment"
LOGACTION & /usr/local/postImagingConfig/enrolment/Enrolment.app/Contents/MacOS/Enrolment | tee -a ${LOGFILE}
LOGOUTPUT "Done"
echo -e "" >> $LOGFILE

wait

#We're about to kick off all policies, time to lock the screen and open the build log

#/System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app/Contents/MacOS/LockScreen -session 256 &
open -a /usr/local/postImagingConfig/resources/LoginLog.app

LOGOUTPUT "--- STARTING BUILD CONFIGURATION"
echo -e "\n" >> $LOGFILE

# Flush policy history
LOGOUTPUT '--- Flush Policy History'
${JAMF} flushPolicyHistory | tee -a ${LOGFILE}
LOGOUTPUT "Done"
echo -e "\n" >> $LOGFILE

# Call build triggers

# BuildPre. Any policies that need to run first
LOGOUTPUT "--- Running BuildPre Policies"
${JAMF} policy -trigger BuildPre | tee -a ${LOGFILE}
LOGOUTPUT "Done"
echo -e "" >> $LOGFILE

# FirstRun. Policies that set configurations for the machine or policies that cache larger software installs
LOGOUTPUT "--- Running FirstRun Policies"
echo -e "" >> $LOGFILE
${JAMF} policy -trigger FirstRun | tee -a ${LOGFILE}
LOGOUTPUT "Done"
echo -e "" >> $LOGFILE


#This will run one last inventory on the machine before rebooting
LOGOUTPUT "--- Run Final Inventory"
echo -e "" >> $LOGFILE
LOGACTION & ${JAMF} recon | tee -a ${LOGFILE}
LOGOUTPUT "--- Done!"
echo -e "" >> $LOGFILE

LOGOUTPUT "--- Cleaning Up"
#Delete Imaging Account
${JAMF} deleteAccount -username tempaccount -deleteHomeDirectory | tee -a ${LOGFILE}
#Delete JAMF Imaging Files
/bin/rm -rf /Library/Application\ Support/JAMF/FirstRun/PostInstall | tee -a ${LOGFILE}
/bin/rm /Library/LaunchDaemons/com.jamfsoftware.firstrun.postinstall.plist | tee -a ${LOGFILE}
#Delete Post Imaging Files
/bin/rm -rf /usr/local/postImagingConfig | tee -a ${LOGFILE}
LOGOUTPUT "--- Done!"
echo -e "" >> $LOGFILE

# Disable Automatic Logins

LOGOUTPUT "--- Disabling Automatic logins"
defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser | tee -a ${LOGFILE}
LOGOUTPUT "--- Done"
echo -e "" >> $LOGFILE

# Remove Software Update settings

LOGOUTPUT "--- Removing Software Update Server settings"
${JAMF} removeSWUSettings | tee -a ${LOGFILE}
LOGOUTPUT "--- Done"
echo -e "" >> $LOGFILE

LOGOUTPUT "--- Rebooting!"

LOGACTION & ${JAMF} reboot -immediately | tee -a ${LOGFILE}